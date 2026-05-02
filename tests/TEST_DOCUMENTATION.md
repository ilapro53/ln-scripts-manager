# Тесты SM (Script Manager)

## Обзор

Тесты написаны на Python с использованием pytest. Каждый тест проверяет определённую функцию или группу функций.

## Структура

```
tests/
├── test_sm.py       # Основной файл тестов
└── TEST_DOCUMENTATION.md  # Этот файл
```

## Запуск тестов

```bash
# Все тесты
pytest tests/test_sm.py -v

# Только определённый класс
pytest tests/test_sm.py::TestBcpBackup -v

# С выводом print
pytest tests/test_sm.py -v -s
```

## Описание тестов

---

### TestSmCreateEdit — Создание и редактирование скриптов

| Тест | Вводные | Ожидаемый результат |
|------|---------|---------------------|
| `test_create_script_in_root` | `sm -c test1` | Создаётся `scripts/test1.sh` |
| `test_create_script_in_subfolder` | `sm -c folder1/test2` | Создаётся `scripts/folder1/test2.sh` |
| `test_edit_existing_script` | `sm -e test3` | Скрипт открывается в редакторе |
| `test_create_without_name_shows_error` | `sm -c` | Выводится ошибка "Укажите..." |

---

### TestSmLs — Список скриптов

| Тест | Вводные | Ожидаемый результат |
|------|---------|---------------------|
| `test_ls_empty` | `sm ls` (без скриптов) | Выводится пустой список или сообщение |
| `test_ls_with_scripts` | Создать ls1, ls2, затем `sm ls` | В выводе есть ls1 и ls2 |
| `test_ls_with_subfolder_filter` | Создать sub/ls3, затем `sm ls sub` | Показываются только скрипты из sub |

---

### TestSmExecution — Выполнение скриптов

| Тест | Вводные | Ожидаемый результат |
|------|---------|---------------------|
| `test_x_executes_in_project_dir` | Создать скрипт с `echo EXEC_OUTPUT`, запустить `sm x` | Вывод содержит EXEC_OUTPUT |
| `test_call_requires_name` | `sm call` | Ошибка "Укажите имя" |
| `test_call_nonexistent_shows_error` | `sm call nonexistent` | Сообщение об ошибке |

---

### TestSmCmd — Команды в директории проекта

| Тест | Вводные | Ожидаемый результат |
|------|---------|---------------------|
| `test_cmd_runs_in_project_dir` | Создать скрипт с `mkdir testdir`, выполнить | Папка testdir создаётся |
| `test_cmd_requires_command` | `sm --cmd` | Ошибка "Укажите команду" |

---

### TestSmSetgitignore — Управление .gitignore

| Тест | Вводные | Ожидаемый результат |
|------|---------|---------------------|
| `test_setgitignore_requires_name` | `sm setgitignore` | Ошибка "Укажите имя" |
| `test_setgitignore_nonexistent_shows_error` | `sm setgitignore nonexistent` | Ошибка "Файл не найден" |
| `test_setgitignore_creates_gitignore` | Создать dev.gitignore, выполнить | Файл .gitignore создан с содержимым |
| `test_setgitignore_replaces_existing` | Старый .gitignore + `sm setgitignore dev` | Старый контент заменён |

---

### TestBcpCreate — Создание бэкапов

| Тест | Вводные | Ожидаемый результат |
|------|---------|---------------------|
| `test_create_shallow_creates_files` | `bcp create -s b1` | Создаётся `.bcpdirs.txt`, `.backup.mode.txt` с "shallow" |
| `test_create_recursive_creates_files` | `bcp create -r b2` | Создаётся `.bcpdirs.rec.txt`, mode с "recursive" |
| `test_create_requires_mode` | `bcp create b3` | Ошибка "Укажите режим" |
| `test_create_duplicate_fails` | Два раза `bcp create -s b4` | Вторая попытка: "Уже существует" |

---

### TestBcpEdit — Редактирование списка директорий

| Тест | Вводные | Ожидаемый результат |
|------|---------|---------------------|
| `test_edit_changes_template_mode` | Создать shallow, `edit -r` | Шаблон меняется на `.bcpdirs.rec.txt` |
| `test_edit_preserves_backup_mode` | Создать shallow, `edit -r` | Файл `.backup.mode.txt` НЕ меняется |
| `test_edit_adds_directories` | `edit`, ввести "test_data" | В файл шаблона добавлена директория |

---

### TestBcpBackup — Создание бэкапов

| Тест | Вводные | Ожидаемый результат |
|------|---------|---------------------|
| `test_backup_shallow_only_toplevel` | Shallow, папка с подпапками | Резервные копии только файлов верхнего уровня |
| `test_backup_recursive_includes_subdirs` | Recursive, папка с подпапками | Резервные копии всех файлов включая вложенные |
| `test_backup_updates_mode_from_template` | Shallow, изменить шаблон на recursive, backup | Mode.txt обновляется из шаблона |
| `test_backup_removes_previous_files` | Два backup с разным содержимым | Старые файлы удаляются |

---

### TestBcpRestore — Восстановление из бэкапа

| Тест | Вводные | Ожидаемый результат |
|------|---------|---------------------|
| `test_restore_creates_directories` | Recursive backup, удалить папку, restore | Структура директорий восстановлена |
| `test_restore_uses_backup_mode` | Shallow backup, изменить шаблон на recursive, restore | Восстановление по shallow (mode.txt) |

---

### TestBcpDelete — Удаление бэкапов

| Тест | Вводные | Ожидаемый результат |
|------|---------|---------------------|
| `test_delete_removes_all_files` | Создать, backup, delete | Все файлы удалены: `.bcpdirs.txt`, `.backup.mode.txt`, `.bcp.json`, папка backup |

---

### TestBcpList — Список бэкапов

| Тест | Вводные | Ожидаемый результат |
|------|---------|---------------------|
| `test_list_shows_all_backups_with_mode` | Создать shallow и recursive | В списке оба с режимами: "b15 (shallow)", "b16 (recursive)" |

---

### TestPkgUsage — Использование pkg

| Тест | Вводные | Ожидаемый результат |
|------|---------|---------------------|
| `test_pkg_without_args_shows_usage` | `pkg` | Выводится usage |
| `test_pkg_invalid_manager_shows_error` | `pkg invalid list` | Ошибка |
| `test_pkg_invalid_command_shows_error` | `pkg pacman invalid` | Ошибка |

---

### TestShellCompatibility — Совместимость с shell

| Тест | Вводные | Ожидаемый результат |
|------|---------|---------------------|
| `test_all_scripts_are_executable` | Создать скрипт | Файл имеет права на выполнение |
| `test_scripts_have_shebang` | Создать скрипт | Начинается с `#!/bin/bash` |
| `test_sm_runs_with_sh` | `sh sm.sh -h` | Выводится help |

---

### TestSmHelp — Справка

| Тест | Вводные | Ожидаемый результат |
|------|---------|---------------------|
| `test_help_shows_all_commands` | `sm -h` | Перечислены все команды |
| `test_empty_call_shows_help` | `sm` (без аргументов) | Показывается help |

---

### TestEdgeCases — Пограничные случаи

| Тест | Вводные | Ожидаемый результат |
|------|---------|---------------------|
| `test_bcp_edit_nonexistent_fails` | `bcp edit nonexistent` | Ошибка "Не существует" |
| `test_bcp_backup_nonexistent_fails` | `bcp backup nonexistent` | Ошибка "Не существует" |
| `test_bcp_restore_nonexistent_fails` | `bcp restore nonexistent` | Ошибка "Не найден" |

---

## CI/CD

Тесты автоматически запускаются через GitHub Actions при:
- Push в ветку `dev`
- Pull Request в `dev`

```yaml
# .github/workflows/test.yml
name: Tests
on:
  push:
    branches: [dev]
  pull_request:
    branches: [dev]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: pytest tests/test_sm.py -v
```

## Требования

```bash
pip install pytest
```