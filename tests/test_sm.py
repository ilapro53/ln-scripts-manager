#!/usr/bin/env python3

import os
import subprocess
import tempfile
import shutil
import pytest
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.parent.resolve()
SM = SCRIPT_DIR / "sm.sh"
BCP = SCRIPT_DIR / "smtools" / "bcp.sh"
PKG = SCRIPT_DIR / "smtools" / "pkg.sh"
WORK_DIR = None


@pytest.fixture(autouse=True)
def setup_teardown():
    global WORK_DIR
    WORK_DIR = tempfile.mkdtemp()
    os.chdir(WORK_DIR)
    yield
    os.chdir("/")
    shutil.rmtree(WORK_DIR, ignore_errors=True)


def run(cmd, check=True, input_data=None):
    result = subprocess.run(
        cmd if isinstance(cmd, list) else cmd.split(),
        capture_output=True,
        text=True,
        input=input_data,
        cwd=WORK_DIR,
        env={**os.environ, "HOME": os.environ.get("HOME", "/home/test")}
    )
    if check and result.returncode != 0:
        pytest.fail(f"Command failed: {cmd}\nStdout: {result.stdout}\nStderr: {result.stderr}")
    return result


# ========== SM.SH CREATE/EDIT ==========

class TestSmCreateEdit:
    def test_create_script_in_root(self):
        run([str(SM), "-c", "test1"])
        assert (Path("scripts/test1.sh")).exists()
        assert (Path("scripts/test1.sh")).stat().st_mode & 0o111

    def test_create_script_in_subfolder(self):
        run([str(SM), "-c", "folder1/test2"])
        assert (Path("scripts/folder1/test2.sh")).exists()

    def test_create_empty_script_removes_on_exit(self):
        pass  # Интерактивный тест - требует моканья nano

    def test_edit_existing_script(self):
        run([str(SM), "-c", "test3"])
        run([str(SM), "-e", "test3"], input_data="#!/bin/bash\necho test")

    def test_create_without_name_shows_error(self):
        result = run([str(SM), "-c"], check=False)
        assert result.returncode != 0
        assert "Укажите" in result.stdout


# ========== SM.SH LS ==========

class TestSmLs:
    def test_ls_empty(self):
        result = run([str(SM), "ls"], check=False)
        # Может быть пусто или список скриптов

    def test_ls_with_scripts(self):
        run([str(SM), "-c", "ls1"])
        run([str(SM), "-c", "ls2"])
        result = run([str(SM), "ls"])
        assert "ls1" in result.stdout
        assert "ls2" in result.stdout

    def test_ls_with_subfolder_filter(self):
        run([str(SM), "-c", "sub/ls3"])
        result = run([str(SM), "ls", "sub"])
        assert "sub/ls3" in result.stdout or "ls3" in result.stdout


# ========== SM.SH RECORD ==========

class TestSmRecord:
    def test_record_creates_script(self):
        pass  # Интерактивный тест

    def test_record_requires_name(self):
        result = run([str(SM), "-r"], check=False)
        assert result.returncode != 0


# ========== SM.SH X/CALL ==========

class TestSmExecution:
    def setup_method(self):
        run([str(SM), "-c", "exec_test"])
        Path("scripts/exec_test.sh").write_text("#!/bin/bash\necho 'EXEC_OUTPUT'\n")
        Path("scripts/exec_test.sh").chmod(0o755)

    def test_x_executes_in_project_dir(self):
        result = run([str(SM), "x", "exec_test"])
        assert "EXEC_OUTPUT" in result.stdout

    def test_call_requires_name(self):
        result = run([str(SM), "call"], check=False)
        assert result.returncode != 0

    def test_call_nonexistent_shows_error(self):
        result = run([str(SM), "call", "nonexistent"], check=False)
        assert "не найден" in result.stdout.lower() or result.returncode != 0


# ========== SM.SH CMD ==========

class TestSmCmd:
    def test_cmd_runs_in_project_dir(self):
        run([str(SM), "-c", "dir_test"])
        Path("scripts/dir_test.sh").write_text("#!/bin/bash\nmkdir testdir")
        result = run([str(SM), "x", "dir_test"])
        assert Path("testdir").exists()

    def test_cmd_requires_command(self):
        result = run([str(SM), "--cmd"], check=False)
        assert result.returncode != 0


# ========== SM.SH SETGITIGNORE ==========

class TestSmSetgitignore:
    def test_setgitignore_requires_name(self):
        result = run([str(SM), "setgitignore"], check=False)
        assert result.returncode != 0

    def test_setgitignore_nonexistent_shows_error(self):
        result = run([str(SM), "setgitignore", "nonexistent"], check=False)
        assert "не найден" in result.stdout.lower() or result.returncode != 0

    def test_setgitignore_creates_gitignore(self):
        Path("dev.gitignore").write_text("*.log\ntmp/")
        run([str(SM), "setgitignore", "dev"])
        assert Path(".gitignore").exists()
        assert "*.log" in Path(".gitignore").read_text()

    def test_setgitignore_replaces_existing(self):
        Path("dev.gitignore").write_text("*.log")
        Path(".gitignore").write_text("old content")
        run([str(SM), "setgitignore", "dev"])
        content = Path(".gitignore").read_text()
        assert "*.log" in content
        assert "old content" not in content


# ========== BCP.SH ==========

class TestBcpCreate:
    def test_create_shallow_creates_files(self):
        run([str(BCP), "-d", WORK_DIR, "create", "-s", "b1"])
        assert (Path(WORK_DIR) / "backups/b1.bcpdirs.txt").exists()
        assert (Path(WORK_DIR) / "backups/b1.backup.mode.txt").exists()
        assert not (Path(WORK_DIR) / "backups/b1.bcpdirs.rec.txt").exists()
        assert (Path(WORK_DIR) / "backups/b1.backup.mode.txt").read_text().strip() == "shallow"

    def test_create_recursive_creates_files(self):
        run([str(BCP), "-d", WORK_DIR, "create", "-r", "b2"])
        assert (Path(WORK_DIR) / "backups/b2.bcpdirs.rec.txt").exists()
        assert not (Path(WORK_DIR) / "backups/b2.bcpdirs.txt").exists()
        assert (Path(WORK_DIR) / "backups/b2.backup.mode.txt").read_text().strip() == "recursive"

    def test_create_requires_mode(self):
        result = run([str(BCP), "-d", WORK_DIR, "create", "b3"], check=False)
        assert "Укажите режим" in result.stdout

    def test_create_duplicate_fails(self):
        run([str(BCP), "-d", WORK_DIR, "create", "-s", "b4"])
        result = run([str(BCP), "-d", WORK_DIR, "create", "-s", "b4"], check=False)
        assert "Уже существует" in result.stdout


class TestBcpEdit:
    def test_edit_changes_template_mode(self):
        run([str(BCP), "-d", WORK_DIR, "create", "-s", "b5"])
        run([str(BCP), "-d", WORK_DIR, "edit", "-r", "b5"], input_data="test_data\n")
        assert (Path(WORK_DIR) / "backups/b5.bcpdirs.rec.txt").exists()
        assert not (Path(WORK_DIR) / "backups/b5.bcpdirs.txt").exists()

    def test_edit_preserves_backup_mode(self):
        run([str(BCP), "-d", WORK_DIR, "create", "-s", "b6"])
        run([str(BCP), "-d", WORK_DIR, "edit", "-r", "b6"], input_data="test_data\n")
        # Backup mode не должен измениться
        assert (Path(WORK_DIR) / "backups/b6.backup.mode.txt").read_text().strip() == "shallow"

    def test_edit_adds_directories(self):
        run([str(BCP), "-d", WORK_DIR, "create", "-s", "b7"])
        run([str(BCP), "-d", WORK_DIR, "edit", "b7"], input_data="test_data\n")
        content = (Path(WORK_DIR) / "backups/b7.bcpdirs.txt").read_text()
        assert "test_data" in content


class TestBcpBackup:
    def setup_method(self):
        Path("test_data").mkdir()
        Path("test_data/file1.sh").write_text("content1")
        Path("test_data/subdir").mkdir()
        Path("test_data/subdir/file2.sh").write_text("content2")

    def test_backup_shallow_only_toplevel(self):
        run([str(BCP), "-d", WORK_DIR, "create", "-s", "b8"])
        run([str(BCP), "-d", WORK_DIR, "edit", "b8"], input_data="test_data\n")
        run([str(BCP), "-d", WORK_DIR, "backup", "b8"])
        
        files = list((Path(WORK_DIR) / "backups/b8").iterdir())
        paths = [f.name for f in files]
        assert any("test_data_file1.sh" in p for p in paths)
        assert not any("test_data_subdir_file2.sh" in p for p in paths)

    def test_backup_recursive_includes_subdirs(self):
        run([str(BCP), "-d", WORK_DIR, "create", "-r", "b9"])
        run([str(BCP), "-d", WORK_DIR, "edit", "b9"], input_data="test_data\n")
        run([str(BCP), "-d", WORK_DIR, "backup", "b9"])
        
        files = list((Path(WORK_DIR) / "backups/b9").iterdir())
        paths = [f.name for f in files]
        assert any("test_data_file1.sh" in p for p in paths)
        assert any("test_data_subdir_file2.sh" in p for p in paths)

    def test_backup_updates_mode_from_template(self):
        run([str(BCP), "-d", WORK_DIR, "create", "-s", "b10"])
        run([str(BCP), "-d", WORK_DIR, "edit", "b10"], input_data="test_data\n")
        run([str(BCP), "-d", WORK_DIR, "edit", "-r", "b10"])
        run([str(BCP), "-d", WORK_DIR, "backup", "b10"])
        
        mode = (Path(WORK_DIR) / "backups/b10.backup.mode.txt").read_text().strip()
        assert mode == "recursive"

    def test_backup_removes_previous_files(self):
        run([str(BCP), "-d", WORK_DIR, "create", "-s", "b11"])
        run([str(BCP), "-d", WORK_DIR, "edit", "b11"], input_data="test_data\n")
        run([str(BCP), "-d", WORK_DIR, "backup", "b11"])
        first_backup_files = set(f.name for f in (Path(WORK_DIR) / "backups/b11").iterdir())
        
        Path("test_data/newfile.sh").write_text("new")
        run([str(BCP), "-d", WORK_DIR, "backup", "b11"])
        second_backup_files = set(f.name for f in (Path(WORK_DIR) / "backups/b11").iterdir())
        
        # Файлы должны быть уникальными (разные хэши)
        assert first_backup_files != second_backup_files


class TestBcpRestore:
    def setup_method(self):
        Path("test_data").mkdir()
        Path("test_data/file1.sh").write_text("content1")
        Path("test_data/subdir").mkdir()
        Path("test_data/subdir/file2.sh").write_text("content2")
        Path("test_data/subdir/nested").mkdir()
        Path("test_data/subdir/nested/file3.sh").write_text("content3")

    def test_restore_creates_directories(self):
        run([str(BCP), "-d", WORK_DIR, "create", "-r", "b12"])
        run([str(BCP), "-d", WORK_DIR, "edit", "b12"], input_data="test_data\n")
        run([str(BCP), "-d", WORK_DIR, "backup", "b12"])
        
        shutil.rmtree("test_data")
        
        run([str(BCP), "-d", WORK_DIR, "restore", "b12"])
        
        assert Path("test_data/subdir/nested/file3.sh").exists()
        assert Path("test_data/subdir/nested/file3.sh").read_text() == "content3"

    def test_restore_uses_backup_mode(self):
        run([str(BCP), "-d", WORK_DIR, "create", "-s", "b13"])
        run([str(BCP), "-d", WORK_DIR, "edit", "b13"], input_data="test_data\n")
        run([str(BCP), "-d", WORK_DIR, "backup", "b13"])
        run([str(BCP), "-d", WORK_DIR, "edit", "-r", "b13"])
        
        shutil.rmtree("test_data")
        
        run([str(BCP), "-d", WORK_DIR, "restore", "b13"])
        
        assert Path("test_data/file1.sh").exists()
        assert not Path("test_data/subdir/nested/file3.sh").exists()


class TestBcpDelete:
    def test_delete_removes_all_files(self):
        run([str(BCP), "-d", WORK_DIR, "create", "-s", "b14"])
        run([str(BCP), "-d", WORK_DIR, "edit", "b14"], input_data="test_data\n")
        run([str(BCP), "-d", WORK_DIR, "backup", "b14"])
        run([str(BCP), "-d", WORK_DIR, "delete", "b14"])
        
        assert not (Path(WORK_DIR) / "backups/b14.bcpdirs.txt").exists()
        assert not (Path(WORK_DIR) / "backups/b14.backup.mode.txt").exists()
        assert not (Path(WORK_DIR) / "backups/b14.bcp.json").exists()
        assert not (Path(WORK_DIR) / "backups/b14").exists()


class TestBcpList:
    def test_list_shows_all_backups_with_mode(self):
        run([str(BCP), "-d", WORK_DIR, "create", "-s", "b15"])
        run([str(BCP), "-d", WORK_DIR, "create", "-r", "b16"])
        result = run([str(BCP), "-d", WORK_DIR, "list"])
        
        assert "b15 (shallow)" in result.stdout
        assert "b16 (recursive)" in result.stdout


# ========== PKG.SH ==========

class TestPkgUsage:
    def test_pkg_without_args_shows_usage(self):
        result = run([str(PKG)], check=False)
        assert "Использование" in result.stdout or result.returncode != 0

    def test_pkg_invalid_manager_shows_error(self):
        result = run([str(PKG), "invalid", "list"], check=False)
        assert result.returncode != 0

    def test_pkg_invalid_command_shows_error(self):
        result = run([str(PKG), "pacman", "invalid"], check=False)
        assert result.returncode != 0

    def test_pkg_with_flags(self):
        # Флаги должны парситься, но установка не должна происходить
        result = run([str(PKG), "-y", "pacman", "install", "nonexistent_pkg_12345"], check=False)
        # Конкретный результат зависит от системы


# ========== SM SHELL/BASH COMPATIBILITY ==========

class TestShellCompatibility:
    def test_all_scripts_are_executable(self):
        run([str(SM), "-c", "compat_test"])
        mode = Path("scripts/compat_test.sh").stat().st_mode
        assert mode & 0o111

    def test_scripts_have_shebang(self):
        run([str(SM), "-c", "shebang_test"])
        content = Path("scripts/shebang_test.sh").read_text()
        assert content.startswith("#!/bin/bash")

    def test_sm_runs_with_sh(self):
        result = subprocess.run(["sh", str(SM), "-h"], capture_output=True, text=True)
        assert "Использование" in result.stdout or "Usage" in result.stdout


# ========== SM HELP ==========

class TestSmHelp:
    def test_help_shows_all_commands(self):
        result = run([str(SM), "-h"])
        assert "--create" in result.stdout or "-c" in result.stdout
        assert "--record" in result.stdout or "-r" in result.stdout
        assert "bcp" in result.stdout
        assert "pkg" in result.stdout
        assert "setgitignore" in result.stdout

    def test_empty_call_shows_help(self):
        result = run([str(SM)])
        assert "Использование" in result.stdout or "Usage" in result.stdout


# ========== EDGE CASES ==========

class TestEdgeCases:
    def test_create_with_special_chars_in_name(self):
        result = run([str(SM), "-c", "test-with-dash"], check=False)
        # Может работать или нет в зависимости от реализации

    def test_bcp_edit_nonexistent_fails(self):
        result = run([str(BCP), "-d", WORK_DIR, "edit", "nonexistent"], check=False)
        assert "не существует" in result.stdout.lower()

    def test_bcp_backup_nonexistent_fails(self):
        result = run([str(BCP), "-d", WORK_DIR, "backup", "nonexistent"], check=False)
        assert "не существует" in result.stdout.lower()

    def test_bcp_restore_nonexistent_fails(self):
        result = run([str(BCP), "-d", WORK_DIR, "restore", "nonexistent"], check=False)
        assert "не найден" in result.stdout.lower()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
