# sm — (Linux) Script Manager

Утилита для управления bash-скриптами.

## Зависимости

### Обязательные

- bash - оболочка
- coreutils - sha256sum, mkdir, rm, cp, mv, date, basename, dirname, cat, touch, tr, cut, head, tail
- sed - потоковый редактор
- grep - поиск по тексту
- findutils - find, locate, xargs
- sudo - для команд с правами суперпользователя

### Опциональные

- nano - для редактирования списка директорий в bcp (без него работает через stdin)
- pacman - если нужен
- yay - если нужен
- snap - если нужен

## Установка

1. Клонировать репозиторий и перейти в папку проекта:
```bash
git clone <repo-url>
cd ln-scripts-manager
```

2. Сделать исполняемым:
```bash
chmod +x sm.sh
```

3. Глобальная установка (или без установки: вместо `sm` обращаться к `sm.sh`):
```bash
sudo ./sm.sh --init
```

4. Замена .gitignore на пользовательский (для хранения скриптов и бэкапов в git):
```bash
./sm.sh setgitignore user
```

⚠️ Контрибьюторы должны использовать:
```bash
./sm.sh setgitignore dev
```

## Команды

### Основные

```bash
sm                     # показать справку
sm -h, --help          # показать справку

sm --init              # установить как глобальную команду
```

### Управление скриптами

```bash
sm -c, -e, --create, --edit <name>   # создать/редактировать скрипт
sm -r, --record <name>              # записать команды в скрипт
sm ls [folder]                      # список скриптов
sm x <name>                        # выполнить скрипт в папке утилиты
sm call <name>                     # выполнить скрипт в текущей папке
sm --cmd <command>                 # выполнить команду в папке утилиты
```

### Бэкапы

```bash
sm bcp create <name>     # создать пустой бэкап
sm bcp edit <name>        # редактировать список директорий
sm bcp backup <name>     # создать бэкап
sm bcp restore <name>    # восстановить из бэкапа
sm bcp delete <name>     # удалить бэкап
sm bcp list             # список бэкапов
```

Бэкапы хранятся в папке `backups/`:
- `<name>.bcpdirs.txt` — список директорий для бэкапа
- `<name>.bcp.json` — метаданные (время, хэши файлов)
- `<name>/` — файлы с хэшированными именами

### Пакеты

```bash
sm pkg <manager> install <packages>   # установить пакеты
sm pkg <manager> remove <packages>   # удалить пакеты
sm pkg <manager> list              # список пакетов
sm pkg <manager> search <query>    # поиск пакетов
```

Менеджеры: `pacman`, `yay`, `snap`

Флаги:
- `-y`, `--yes-all`, `--noconfirm` — без подтверждений

### Gitignore

```bash
sm setgitignore <name>   # установить <name>.gitignore как .gitignore
```

### Примеры

```bash
# Создать новый скрипт
sm -c myscript

# Записать скрипт
sm -r myscript

# Создать бэкап папки smtools
sm bcp create smtools-backup
echo "smtools" | sm bcp edit smtools-backup
sm bcp backup smtools-backup

# Восстановить из бэкапа
sm bcp restore smtools-backup

# Установить gitignore
sm setgitignore dev
```

## Структура проекта

```
sm.sh           # основной скрипт
smtools/        # утилиты
  bcp.sh       # менеджер бэкапов
  pkg.sh      # менеджер пакетов
scripts/       # ваши скрипты
backups/        # бэкапы
dev.gitignore  # шаблон gitignore для разработки
user.gitignore # шаблон gitignore для пользователя
```
