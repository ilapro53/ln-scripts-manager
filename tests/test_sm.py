#!/usr/bin/env python3

import os
import subprocess
import shutil
import tempfile
import pytest
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.parent.resolve()
SM = SCRIPT_DIR / "sm.sh"
BCP = SCRIPT_DIR / "smtools" / "bcp.sh"
PKG = SCRIPT_DIR / "smtools" / "pkg.sh"


@pytest.fixture
def workdir():
    d = tempfile.mkdtemp()
    orig = os.getcwd()
    os.chdir(d)
    fake_nano = Path(d) / "nano"
    fake_nano.write_text("""#!/bin/bash
FILE=$1
if [ ! -t 0 ]; then
    cat > "$FILE"
else
    exec /usr/bin/nano "$FILE"
fi
""")
    fake_nano.chmod(0o755)
    old_path = os.environ.get("PATH", "")
    os.environ["PATH"] = f"{d}:{old_path}"
    yield Path(d)
    os.chdir(orig)
    os.environ["PATH"] = old_path
    shutil.rmtree(d, ignore_errors=True)
    for f in SCRIPT_DIR.glob("test*.sh"):
        f.unlink()
    for p in [SCRIPT_DIR / "scripts" / "folder1", SCRIPT_DIR / "scripts" / "sub"]:
        if p.exists() and not any(p.iterdir()):
            p.rmdir()


def run(cmd, check=True, input_data=None, cwd=None):
    if cwd is None:
        cwd = os.getcwd()
    result = subprocess.run(
        cmd if isinstance(cmd, list) else cmd.split(),
        capture_output=True,
        text=True,
        input=input_data,
        cwd=cwd,
        env={**os.environ, "HOME": os.environ.get("HOME", "/home/test")}
    )
    if check and result.returncode != 0:
        pytest.fail(f"Command failed: {cmd}\nStdout: {result.stdout}\nStderr: {result.stderr}")
    return result


def run_sm(args, workdir=None, **kw):
    if workdir and args and args[0] == "bcp":
        cwd = str(SCRIPT_DIR)
    else:
        cwd = str(workdir) if workdir else None
    return run([str(SM)] + args, cwd=cwd, **kw)


def run_bcp(args, workdir=None, **kw):
    cwd = str(workdir) if workdir else None
    return run([str(BCP)] + args, cwd=cwd, **kw)


class TestSmCreateEdit:
    def test_create_script_in_root(self, workdir):
        run_sm(["-c", "test_create_script_in_root"], workdir=workdir, input_data="#!/bin/bash\necho test\n")
        assert (SCRIPT_DIR / "scripts" / "test_create_script_in_root.sh").exists()

    def test_create_script_in_subfolder(self, workdir):
        run_sm(["-c", "test_create_script_in_subfolder_folder1/test_create_script_in_subfolder"], workdir=workdir, input_data="#!/bin/bash\necho test\n")
        assert (SCRIPT_DIR / "scripts" / "test_create_script_in_subfolder_folder1" / "test_create_script_in_subfolder.sh").exists()

    def test_create_script_in_root_from_another_folder(self, workdir):
        run_sm(["-c", "test_create_script_in_root_from_another_folder"], workdir=workdir.parent, input_data="#!/bin/bash\necho test_create_script_in_root_from_another_folder\n")
        assert (SCRIPT_DIR / "scripts" / "test_create_script_in_root_from_another_folder.sh").exists()
        assert Path(SCRIPT_DIR / "scripts" / "test_create_script_in_root_from_another_folder.sh").read_text() == "#!/bin/bash\necho test_create_script_in_root_from_another_folder\n"

    def test_create_script_in_subfolder_from_another_folder(self, workdir):
        run_sm(
            ["-c", "test_create_script_in_subfolder_from_another_folder_folder1/test_create_script_in_subfolder_from_another_folder"], 
            workdir=workdir.parent, input_data="#!/bin/bash\necho test_create_script_in_subfolder_from_another_folder\n"
        )
        assert (SCRIPT_DIR / "scripts" / "test_create_script_in_subfolder_from_another_folder_folder1" / "test_create_script_in_subfolder_from_another_folder.sh").exists()
        assert Path(SCRIPT_DIR / "scripts" / "test_create_script_in_subfolder_from_another_folder_folder1" / "test_create_script_in_subfolder_from_another_folder.sh").read_text() == "#!/bin/bash\necho test_create_script_in_subfolder_from_another_folder\n"

    def test_empty_script_removes_on_exit(self, workdir):
        run_sm(
            ["-c", "test_empty_script_removes_on_exit_folder1/test_empty_script_removes_on_exit"], 
            workdir=workdir.parent, input_data="#!/bin/bash\n"
        )
        assert not (SCRIPT_DIR / "scripts" / "test_empty_script_removes_on_exit_folder1" / "test_empty_script_removes_on_exit.sh").exists()
        run_sm(
            ["-c", "test_empty_script_removes_on_exit_folder1/test_empty_script_removes_on_exit"], 
            workdir=workdir.parent, input_data=""
        )
        assert not (SCRIPT_DIR / "scripts" / "test_empty_script_removes_on_exit_folder1" / "test_empty_script_removes_on_exit.sh").exists()

    def test_edit_existing_script(self, workdir):
        run_sm(["-c", "test3"], workdir=workdir, input_data="#!/bin/bash\necho test\n")
        assert Path(SCRIPT_DIR / "scripts" / "test3.sh").read_text() == "#!/bin/bash\necho test\n"
        run_sm(["-e", "test3"], input_data="#!/bin/bash\necho edited\n", workdir=workdir)
        assert Path(SCRIPT_DIR / "scripts" / "test3.sh").read_text() == "#!/bin/bash\necho edited\n"
        run_sm(["-e", "test3"], input_data="#!/bin/bash\necho edited_from_parent\n", workdir=workdir.parent)
        assert Path(SCRIPT_DIR / "scripts" / "test3.sh").read_text() == "#!/bin/bash\necho edited_from_parent\n"

    def test_create_without_name_shows_error(self, workdir):
        result = run_sm(["-c"], check=False, workdir=workdir)
        assert result.returncode != 0
        assert "Укажите" in result.stdout


class TestSmLs:
    def test_ls_empty(self, workdir):
        result = run_sm(["ls"], check=False, workdir=workdir)

    def test_ls_with_scripts(self, workdir):
        run_sm(["-c", "ls1"], workdir=workdir, input_data="#!/bin/bash\necho 1\n")
        run_sm(["-c", "ls2"], workdir=workdir, input_data="#!/bin/bash\necho 2\n")
        run_sm(["-c", "ls3"], workdir=workdir.parent, input_data="#!/bin/bash\necho 3\n")
        result = run_sm(["ls"], workdir=workdir)
        assert "ls1" in result.stdout
        assert "ls2" in result.stdout
        assert "ls3" in result.stdout
        assert not ("/ls1" in result.stdout)
        assert not ("/ls2" in result.stdout)
        assert not ("/ls3" in result.stdout)

    def test_ls_with_subfolder_filter(self, workdir):
        run_sm(["-c", "sub/ls4"], workdir=workdir, input_data="#!/bin/bash\necho 4\n")
        run_sm(["-c", "sub/sub2/ls5"], workdir=workdir, input_data="#!/bin/bash\necho 5\n")
        run_sm(["-c", "sub/sub2/ls6"], workdir=workdir.parent, input_data="#!/bin/bash\necho 6\n")
        result = run_sm(["ls", "sub"], workdir=workdir)
        result2 = run_sm(["ls", "sub/sub2"], workdir=workdir)
        assert "ls4" in result.stdout
        assert "ls5" in result.stdout
        assert not ("ls4" in result2.stdout)
        assert "ls5" in result2.stdout
        assert "ls6" in result2.stdout


class TestSmRecord:
    def test_record_creates_script(self, workdir):
        pass

    def test_record_requires_name(self, workdir):
        result = run_sm(["-r"], check=False, workdir=workdir)
        assert result.returncode != 0


class TestSmExecution:
    def test_x_executes_in_project_dir(self, workdir):
        run_sm(["-c", "exec_test"], workdir=workdir, input_data="#!/bin/bash\necho EXEC_OUTPUT\n")
        (SCRIPT_DIR / "scripts" / "exec_test.sh").chmod(0o755)
        result = run_sm(["x", "exec_test"], workdir=workdir)
        assert "EXEC_OUTPUT" in result.stdout
        run_sm(["-c", "exec_test2"], workdir=workdir, input_data="#!/bin/bash\necho EXEC_OUTPUT2\n")
        (SCRIPT_DIR / "scripts" / "exec_test2.sh").chmod(0o755)
        result = run_sm(["x", "exec_test2"], workdir=workdir.parent)
        assert "EXEC_OUTPUT2" in result.stdout

    def test_call_executes_in_current_dir(self, workdir):
        run_sm(["-c", "call_test"], workdir=workdir, input_data="#!/bin/bash\npwd\n")
        (SCRIPT_DIR / "scripts" / "call_test.sh").chmod(0o755)
        result = run_sm(["call", "call_test"], workdir=workdir)
        result2 = run_sm(["call", "call_test"], workdir=workdir.parent)
        assert result.stdout != result2.stdout

    def test_call_requires_name(self, workdir):
        result = run_sm(["call"], check=False, workdir=workdir)
        assert result.returncode != 0

    def test_call_nonexistent_shows_error(self, workdir):
        result = run_sm(["call", "nonexistent"], check=False, workdir=workdir)
        assert "не найден" in result.stdout.lower() or result.returncode != 0


class TestSmCmd:
    def test_cmd_runs_in_project_dir(self, workdir):
        result1 = run_sm(["--cmd", "pwd"], check=False, workdir=workdir)
        result2 = run_sm(["--cmd", "pwd"], check=False, workdir=workdir.parent)
        assert result1.stdout == result2.stdout
        result3 = run_sm(["--cmd", "ls"], check=False, workdir=workdir.parent)
        assert "sm.sh" in result3.stdout

    def test_cmd_requires_command(self, workdir):
        result = run_sm(["--cmd"], check=False, workdir=workdir)
        assert result.returncode != 0


class TestShellCompatibility:
    def test_all_scripts_are_executable(self, workdir):
        run_sm(["-c", "compat_test"], workdir=workdir, input_data="#!/bin/bash\necho ok\n")
        script_path = SCRIPT_DIR / "scripts" / "compat_test.sh"
        if script_path.exists():
            mode = script_path.stat().st_mode
            assert mode & 0o111

    def test_scripts_have_shebang(self, workdir):
        run_sm(["-c", "shebang_test"], workdir=workdir, input_data="#!/bin/bash\necho test\n")
        content = (SCRIPT_DIR / "scripts" / "shebang_test.sh").read_text()
        assert content.startswith("#!/bin/bash")

    def test_sm_runs_with_sh(self, workdir):
        result = subprocess.run(["sh", str(SM), "-h"], capture_output=True, text=True, cwd=SCRIPT_DIR)
        assert "Использование" in result.stdout or "Usage" in result.stdout


class TestSmHelp:
    def test_help_shows_all_commands(self, workdir):
        result = run_sm(["-h"], workdir=workdir)
        assert "--create" in result.stdout or "-c" in result.stdout
        assert "bcp" in result.stdout
        assert "pkg" in result.stdout

    def test_empty_call_shows_help(self, workdir):
        result = run_sm([], workdir=workdir)
        assert "Использование" in result.stdout or "Usage" in result.stdout


class TestEdgeCases:
    def test_create_with_special_chars_in_name(self, workdir):
        result = run_sm(["-c", "test-with-dash"], check=False, workdir=workdir)

    def test_bcp_edit_nonexistent_fails(self, workdir):
        result = run_bcp(["-d", str(workdir), "edit", "nonexistent"], check=False)
        assert "не существует" in result.stdout.lower()

    def test_bcp_backup_nonexistent_fails(self, workdir):
        result = run_bcp(["-d", str(workdir), "backup", "nonexistent"], check=False)
        assert "не существует" in result.stdout.lower()

    def test_bcp_restore_nonexistent_fails(self, workdir):
        result = run_bcp(["-d", str(workdir), "restore", "nonexistent"], check=False)
        assert "не найден" in result.stdout.lower()


class TestSmSetgitignore:
    def test_setgitignore_requires_name(self, workdir):
        result = run_sm(["setgitignore"], check=False, workdir=workdir)
        assert result.returncode != 0

    def test_setgitignore_nonexistent_shows_error(self, workdir):
        result = run_sm(["setgitignore", "nonexistent"], check=False, workdir=workdir)
        assert "не найден" in result.stdout.lower() or result.returncode != 0

    def test_setgitignore_creates_gitignore(self, workdir):
        (SCRIPT_DIR / "dev.gitignore").write_text("*.log\ntmp/")
        run_sm(["setgitignore", "dev"], workdir=workdir)
        assert (workdir / ".gitignore").exists()
        assert "*.log" in (workdir / ".gitignore").read_text()

    def test_setgitignore_replaces_existing(self, workdir):
        (SCRIPT_DIR / "dev.gitignore").write_text("*.log")
        (workdir / ".gitignore").write_text("old content")
        run_sm(["setgitignore", "dev"], workdir=workdir)
        content = (workdir / ".gitignore").read_text()
        assert "*.log" in content


class TestBcpCreate:
    def test_create_shallow_creates_files(self, workdir):
        run_bcp(["-d", str(workdir), "create", "-s", "b1"])
        assert (workdir / "backups/b1.bcpdirs.txt").exists()
        assert not (workdir / "backups/b1.bcpdirs.rec.txt").exists()
        assert (workdir / "backups/b1.backup.mode.txt").read_text().strip() == "shallow"

    def test_create_recursive_creates_files(self, workdir):
        run_bcp(["-d", str(workdir), "create", "-r", "b2"])
        assert (workdir / "backups/b2.bcpdirs.rec.txt").exists()
        assert not (workdir / "backups/b2.bcpdirs.txt").exists()
        assert (workdir / "backups/b2.backup.mode.txt").read_text().strip() == "recursive"

    def test_create_requires_mode(self, workdir):
        result = run_bcp(["-d", str(workdir), "create", "b3"], check=False)
        assert "Укажите режим" in result.stdout

    def test_create_duplicate_fails(self, workdir):
        run_bcp(["-d", str(workdir), "create", "-s", "b4"])
        result = run_bcp(["-d", str(workdir), "create", "-s", "b4"], check=False)
        assert "Уже существует" in result.stdout


class TestSmBcpCreate:
    def test_create_shallow_creates_files(self, workdir):
        run_sm(["bcp", "create", "-s", "b1"], workdir=str(workdir))
        assert (SCRIPT_DIR / "backups/b1.bcpdirs.txt").exists()
        assert not (SCRIPT_DIR / "backups/b1.bcpdirs.rec.txt").exists()
        assert (SCRIPT_DIR / "backups/b1.backup.mode.txt").read_text().strip() == "shallow"

    def test_create_recursive_creates_files(self, workdir):
        run_sm(["bcp", "create", "-r", "b2"], workdir=str(workdir))
        assert (SCRIPT_DIR / "backups/b2.bcpdirs.rec.txt").exists()
        assert not (SCRIPT_DIR / "backups/b2.bcpdirs.txt").exists()
        assert (SCRIPT_DIR / "backups/b2.backup.mode.txt").read_text().strip() == "recursive"

    def test_create_shallow_creates_files_from_other_dir(self, workdir):
        run_sm(["bcp", "create", "-s", "b1o"], workdir=str(workdir.parent))
        assert (SCRIPT_DIR / "backups/b1o.bcpdirs.txt").exists()
        assert not (SCRIPT_DIR / "backups/b1o.bcpdirs.rec.txt").exists()
        assert (SCRIPT_DIR / "backups/b1o.backup.mode.txt").read_text().strip() == "shallow"

    def test_create_recursive_creates_files_from_other_dir(self, workdir):
        run_sm(["bcp", "create", "-r", "b2o"], workdir=str(workdir.parent))
        assert (SCRIPT_DIR / "backups/b2o.bcpdirs.rec.txt").exists()
        assert not (SCRIPT_DIR / "backups/b2o.bcpdirs.txt").exists()
        assert (SCRIPT_DIR / "backups/b2o.backup.mode.txt").read_text().strip() == "recursive"

    def test_create_requires_mode(self, workdir):
        result = run_sm(["bcp", "create", "b3"], check=False, workdir=str(workdir))
        assert "Укажите режим" in result.stdout

    def test_create_duplicate_fails(self, workdir):
        run_sm(["bcp", "create", "-s", "b4"], workdir=str(workdir))
        result = run_sm(["bcp", "create", "-s", "b4"], check=False)
        assert "Уже существует" in result.stdout


class TestBcpEdit:
    def test_edit_changes_template_mode(self, workdir):
        run_bcp(["-d", str(workdir), "create", "-s", "b5"])
        run_bcp(["-d", str(workdir), "edit", "-r", "b5"], input_data="test_data\n")
        assert (workdir / "backups/b5.bcpdirs.rec.txt").exists()
        assert not (workdir / "backups/b5.bcpdirs.txt").exists()

    def test_edit_preserves_backup_mode(self, workdir):
        run_bcp(["-d", str(workdir), "create", "-s", "b6"])
        run_bcp(["-d", str(workdir), "edit", "-r", "b6"], input_data="test_data\n")
        assert (workdir / "backups/b6.backup.mode.txt").read_text().strip() == "shallow"

    def test_edit_adds_directories(self, workdir):
        run_bcp(["-d", str(workdir), "create", "-s", "b7"])
        run_bcp(["-d", str(workdir), "edit", "b7"], input_data="test_data\n")
        content = (workdir / "backups/b7.bcpdirs.txt").read_text()
        assert "test_data" in content


class TestSmBcpEdit:
    def test_edit_changes_template_mode(self, workdir):
        run_sm(["bcp", "create", "-s", "be1"], workdir=str(workdir))
        run_sm(["bcp", "edit", "-r", "be1"], workdir=str(workdir), input_data="test_data\n")
        assert (SCRIPT_DIR / "backups/be1.bcpdirs.rec.txt").exists()
        assert not (SCRIPT_DIR / "backups/be1.bcpdirs.txt").exists()

    def test_edit_preserves_backup_mode(self, workdir):
        run_sm(["bcp", "create", "-s", "be2"], workdir=str(workdir))
        run_sm(["bcp", "edit", "-r", "be2"], workdir=str(workdir), input_data="test_data\n")
        assert (SCRIPT_DIR / "backups/be2.backup.mode.txt").read_text().strip() == "shallow"

    def test_edit_adds_directories(self, workdir):
        run_sm(["bcp", "create", "-s", "be3"], workdir=str(workdir))
        run_sm(["bcp", "edit", "be3"], workdir=str(workdir), input_data="test_data\n")
        content = (SCRIPT_DIR / "backups/be3.bcpdirs.txt").read_text()
        assert "test_data" in content

    def test_edit_from_other_dir(self, workdir):
        run_sm(["bcp", "create", "-s", "be4o"], workdir=str(workdir))
        run_sm(["bcp", "edit", "be4o"], workdir=str(workdir.parent), input_data="test_data be4o\n")
        assert (SCRIPT_DIR / "backups/be4o.bcpdirs.txt").read_text() == "test_data be4o\n"


class TestBcpBackup:
    @pytest.fixture(autouse=True)
    def setup(self, workdir):
        (workdir / "test_data").mkdir()
        (workdir / "test_data/file1.sh").write_text("content1")
        (workdir / "test_data/subdir").mkdir()
        (workdir / "test_data/subdir/file2.sh").write_text("content2")
        self.workdir = workdir

    def test_backup_shallow_only_toplevel(self):
        run_bcp(["-d", str(self.workdir), "create", "-s", "b8"])
        run_bcp(["-d", str(self.workdir), "edit", "b8"], input_data="test_data\n")
        run_bcp(["-d", str(self.workdir), "backup", "b8"])
        files = list((self.workdir / "backups/b8").iterdir())
        paths = [f.name for f in files]
        assert any("test_data_file1.sh" in p for p in paths)
        assert not any("subdir" in p for p in paths)

    def test_backup_recursive_includes_subdirs(self):
        run_bcp(["-d", str(self.workdir), "create", "-r", "b9"])
        run_bcp(["-d", str(self.workdir), "edit", "b9"], input_data="test_data\n")
        run_bcp(["-d", str(self.workdir), "backup", "b9"])
        files = list((self.workdir / "backups/b9").iterdir())
        paths = [f.name for f in files]
        assert any("test_data_file1.sh" in p for p in paths)
        assert any("test_data_subdir_file2.sh" in p for p in paths)

    def test_backup_updates_mode_from_template(self):
        run_bcp(["-d", str(self.workdir), "create", "-s", "b10"])
        run_bcp(["-d", str(self.workdir), "edit", "b10"], input_data="test_data\n")
        run_bcp(["-d", str(self.workdir), "edit", "-r", "b10"])
        run_bcp(["-d", str(self.workdir), "backup", "b10"])
        mode = (self.workdir / "backups/b10.backup.mode.txt").read_text().strip()
        assert mode == "recursive"

    def test_backup_removes_previous_files(self):
        run_bcp(["-d", str(self.workdir), "create", "-s", "b11"])
        run_bcp(["-d", str(self.workdir), "edit", "b11"], input_data="test_data\n")
        run_bcp(["-d", str(self.workdir), "backup", "b11"])
        first_files = set(f.name for f in (self.workdir / "backups/b11").iterdir())
        (self.workdir / "test_data/newfile.sh").write_text("new")
        run_bcp(["-d", str(self.workdir), "backup", "b11"])
        second_files = set(f.name for f in (self.workdir / "backups/b11").iterdir())
        assert first_files != second_files


class TestSmBcpBackup:
    @pytest.fixture(autouse=True)
    def setup(self):
        (SCRIPT_DIR / "test_data").mkdir(exist_ok=True)
        (SCRIPT_DIR / "test_data/file1.sh").write_text("content1")
        (SCRIPT_DIR / "test_data/subdir").mkdir(exist_ok=True)
        (SCRIPT_DIR / "test_data/subdir/file2.sh").write_text("content2")
        yield
        shutil.rmtree(SCRIPT_DIR / "test_data", ignore_errors=True)

    def test_backup_shallow_only_toplevel(self, workdir):
        run_sm(["bcp", "create", "-s", "bb1"], workdir=str(workdir))
        run_sm(["bcp", "edit", "bb1"], workdir=str(workdir), input_data="test_data\n")
        run_sm(["bcp", "backup", "bb1"], workdir=str(workdir))
        files = list((SCRIPT_DIR / "backups/bb1").iterdir())
        paths = [f.name for f in files]
        assert any("test_data_file1.sh" in p for p in paths)
        assert not any(p.startswith("test_data_subdir") for p in paths)
        assert not any("subdir" in p for p in paths)

    def test_backup_recursive_includes_subdirs(self, workdir):
        run_sm(["bcp", "create", "-r", "bb2"], workdir=str(workdir))
        run_sm(["bcp", "edit", "bb2"], workdir=str(workdir), input_data="test_data\n")
        run_sm(["bcp", "backup", "bb2"], workdir=str(workdir))
        files = list((SCRIPT_DIR / "backups/bb2").iterdir())
        paths = [f.name for f in files]
        assert any("test_data_file1.sh" in p for p in paths)
        assert any("test_data_subdir_file2.sh" in p for p in paths)

    def test_backup_from_other_dir(self, workdir):
        run_sm(["bcp", "create", "-s", "bb3o"], workdir=str(workdir.parent))
        run_sm(["bcp", "edit", "bb3o"], workdir=str(workdir.parent), input_data="test_data\n")
        run_sm(["bcp", "backup", "bb3o"], workdir=str(workdir.parent))
        assert (SCRIPT_DIR / "backups/bb3o").exists()


class TestBcpRestore:
    @pytest.fixture(autouse=True)
    def setup(self, workdir):
        (workdir / "test_data").mkdir()
        (workdir / "test_data/file1.sh").write_text("content1")
        (workdir / "test_data/subdir").mkdir()
        (workdir / "test_data/subdir/file2.sh").write_text("content2")
        (workdir / "test_data/subdir/nested").mkdir()
        (workdir / "test_data/subdir/nested/file3.sh").write_text("content3")
        self.workdir = workdir

    def test_restore_creates_directories(self):
        run_bcp(["-d", str(self.workdir), "create", "-r", "b12"])
        run_bcp(["-d", str(self.workdir), "edit", "b12"], input_data="test_data\n")
        run_bcp(["-d", str(self.workdir), "backup", "b12"])
        shutil.rmtree(self.workdir / "test_data")
        run_bcp(["-d", str(self.workdir), "restore", "b12"])
        assert (self.workdir / "test_data/subdir/nested/file3.sh").exists()
        assert (self.workdir / "test_data/subdir/nested/file3.sh").read_text() == "content3"

    def test_restore_uses_backup_mode(self):
        run_bcp(["-d", str(self.workdir), "create", "-s", "b13"])
        run_bcp(["-d", str(self.workdir), "edit", "b13"], input_data="test_data\n")
        run_bcp(["-d", str(self.workdir), "backup", "b13"])
        run_bcp(["-d", str(self.workdir), "edit", "-r", "b13"])
        shutil.rmtree(self.workdir / "test_data")
        run_bcp(["-d", str(self.workdir), "restore", "b13"])
        assert (self.workdir / "test_data/file1.sh").exists()
        assert not (self.workdir / "test_data/subdir/nested/file3.sh").exists()


class TestSmBcpRestore:
    @pytest.fixture(autouse=True)
    def setup(self):
        (SCRIPT_DIR / "test_data").mkdir(exist_ok=True)
        (SCRIPT_DIR / "test_data/file1.sh").write_text("content1")
        (SCRIPT_DIR / "test_data/subdir").mkdir(exist_ok=True)
        (SCRIPT_DIR / "test_data/subdir/file2.sh").write_text("content2")
        (SCRIPT_DIR / "test_data/subdir/nested").mkdir(exist_ok=True)
        (SCRIPT_DIR / "test_data/subdir/nested/file3.sh").write_text("content3")
        yield
        shutil.rmtree(SCRIPT_DIR / "test_data", ignore_errors=True)

    def test_restore_creates_directories(self, workdir):
        run_sm(["bcp", "create", "-r", "br1"], workdir=str(workdir))
        run_sm(["bcp", "edit", "br1"], workdir=str(workdir), input_data="test_data\n")
        run_sm(["bcp", "backup", "br1"], workdir=str(workdir))
        shutil.rmtree(SCRIPT_DIR / "test_data")
        run_sm(["bcp", "restore", "br1"], workdir=str(workdir))
        assert (SCRIPT_DIR / "test_data/subdir/nested/file3.sh").exists()

    def test_restore_from_other_dir(self, workdir):
        run_sm(["bcp", "create", "-s", "br2o"], workdir=str(workdir.parent))
        run_sm(["bcp", "edit", "br2o"], workdir=str(workdir.parent), input_data="test_data\n")
        run_sm(["bcp", "backup", "br2o"], workdir=str(workdir.parent))
        shutil.rmtree(SCRIPT_DIR / "test_data")
        run_sm(["bcp", "restore", "br2o"], workdir=str(workdir.parent))
        assert (SCRIPT_DIR / "test_data/file1.sh").exists()


class TestBcpDelete:
    def test_delete_removes_all_files(self, workdir):
        run_bcp(["-d", str(workdir), "create", "-s", "b14"])
        run_bcp(["-d", str(workdir), "edit", "b14"], input_data="test_data\n")
        run_bcp(["-d", str(workdir), "backup", "b14"])
        run_bcp(["-d", str(workdir), "delete", "b14"])
        assert not (workdir / "backups/b14.bcpdirs.txt").exists()
        assert not (workdir / "backups/b14.backup.mode.txt").exists()
        assert not (workdir / "backups/b14.bcp.json").exists()
        assert not (workdir / "backups/b14").exists()


class TestSmBcpDelete:
    def test_delete_removes_all_files(self, workdir):
        run_sm(["bcp", "create", "-s", "bd1"], workdir=str(workdir))
        run_sm(["bcp", "edit", "bd1"], workdir=str(workdir), input_data="test_data\n")
        run_sm(["bcp", "backup", "bd1"], workdir=str(workdir))
        run_sm(["bcp", "delete", "bd1"], workdir=str(workdir))
        assert not (SCRIPT_DIR / "backups/bd1.bcpdirs.txt").exists()

    def test_delete_from_other_dir(self, workdir):
        run_sm(["bcp", "create", "-s", "bd2o"], workdir=str(workdir.parent))
        run_sm(["bcp", "delete", "bd2o"], workdir=str(workdir.parent))
        assert not (SCRIPT_DIR / "backups/bd2o.bcpdirs.txt").exists()


class TestBcpList:
    def test_list_shows_all_backups_with_mode(self, workdir):
        run_bcp(["-d", str(workdir), "create", "-s", "b15"])
        run_bcp(["-d", str(workdir), "create", "-r", "b16"])
        result = run_bcp(["-d", str(workdir), "list"])
        assert "b15" in result.stdout
        assert "b16" in result.stdout


class TestSmBcpList:
    def test_list_shows_all_backups_with_mode(self, workdir):
        run_sm(["bcp", "create", "-s", "bl1"], workdir=str(workdir))
        run_sm(["bcp", "create", "-r", "bl2"], workdir=str(workdir))
        result = run_sm(["bcp", "list"], workdir=str(workdir))
        assert "bl1" in result.stdout
        assert "bl2" in result.stdout

    def test_list_from_other_dir(self, workdir):
        run_sm(["bcp", "create", "-s", "bl3o"], workdir=str(workdir.parent))
        result = run_sm(["bcp", "list"], workdir=str(workdir.parent))
        assert "bl3o" in result.stdout


class TestPkgUsage:
    def test_pkg_without_args_shows_usage(self, workdir):
        result = run([str(PKG)], check=False, cwd=SCRIPT_DIR)
        assert "Использование" in result.stdout or result.returncode != 0

    def test_pkg_invalid_manager_shows_error(self, workdir):
        result = run([str(PKG), "invalid", "list"], check=False, cwd=SCRIPT_DIR)
        assert result.returncode != 0

    def test_pkg_invalid_command_shows_error(self, workdir):
        result = run([str(PKG), "pacman", "invalid"], check=False, cwd=SCRIPT_DIR)
        assert result.returncode != 0

    def test_pkg_with_flags(self, workdir):
        result = run([str(PKG), "-y", "pacman", "install", "nonexistent_pkg_12345"], check=False, cwd=SCRIPT_DIR)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
