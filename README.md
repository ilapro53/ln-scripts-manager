# sm — (Linux) Script Manager

Утилита для управления bash-скриптами.

## Зависимости

### Обязательные

- `bash` - оболочка
- `sudo` - для команд с правами суперпользователя
- `coreutils` - `sha256sum`, `mkdir`, `rm`, `cp`, `mv`, `date`, `basename`, `dirname`, `cat`, `touch`, `tr`, `cut`, `head`, `tail`
- `findutils` - `find`, `locate`, `xargs`
- `sed` - потоковый редактор
- `grep` - поиск по тексту

### Опциональные

- `nano` - для редактирования списка директорий в bcp (без него работает через stdin)
- `pacman` - если нужен
- `yay` - если нужен
- `snap` - если нужен

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

## Поведение путей

Все пути (скрипты в `scripts/`, бэкапы в `backups/`) отсчитываются от папки, где находится `sm.sh`, **независимо от текущей рабочей директории**.

При глобальной установке через `--init` создаётся симлинк `/usr/local/bin/sm → sm.sh`. При вызове через него все пути также ведут к оригинальному `sm.sh`, а не к симлинку.

Пути, указанные в файле `bcpdirs.txt`, также считаются **относительными к папке проекта** (там, где `sm.sh`).

## Команды

### Основные

```bash
sm                     # показать справку
sm -h, --help          # показать справку

sm --init              # установить как глобальную команду (симлинк)
```

### Управление скриптами

```bash
sm -c, -e, --create, --edit <name>   # создать/редактировать скрипт
sm -r, --record <name>               # записать команды в скрипт
sm ls [folder]                       # список скриптов
sm x <name>                          # выполнить скрипт в папке проекта
sm call <name>                       # выполнить скрипт в текущей папке
sm --cmd <command>                   # выполнить команду в папке проекта
```

#### Разница между `x` и `call`

- `sm x <name>` — запускает скрипт, **предварительно переходя в папку проекта** (`sm.sh`). Удобно, когда скрипт ожидает относительные пути относительно проекта.
- `sm call <name>` — запускает скрипт **в текущей директории**. Удобно, когда скрипт должен работать с файлами там, где находится пользователь.

### Бэкапы

```bash
sm bcp create -s|-r <name>    # создать пустой бэкап (-s: shallow, -r: recursive)
sm bcp edit [-s|-r] <name>    # редактировать список директорий (и опционально сменить режим)
sm bcp set-mode -s|-r <name>  # сменить режим бэкапа без открытия редактора
sm bcp backup <name>          # создать бэкап
sm bcp restore <name>         # восстановить из бэкапа
sm bcp delete <name>          # удалить бэкап
sm bcp list                   # список бэкапов
```

#### Режимы бэкапа

- `-s` / `shallow` — копируются только файлы верхнего уровня указанной директории (не рекурсивно).
- `-r` / `recursive` — копируются все файлы рекурсивно, включая поддиректории.

Режим задаётся при `create` и влияет на то, какой файл-образ используется:
- `<name>.bcpdirs.txt` — для shallow
- `<name>.bcpdirs.rec.txt` — для recursive

`edit -r` / `edit -s` переименовывает файл-образ (меняет шаблонный режим) и открывает редактор.
`set-mode -r` / `set-mode -s` только переименовывает файл, без открытия редактора.

`<name>.backup.mode.txt` хранит режим **последнего выполненного бэкапа** и обновляется при `backup`.

Бэкапы хранятся в папке `backups/`:
- `<name>/` — файлы с уникальными именами (`hash.path.bcpf`)
- `<name>.bcp.json` — метаданные (время, пути файлов)
- `<name>.backup.mode.txt` — режим последнего бэкапа
- `<name>.bcpdirs.txt` — shallow: список директорий
- `<name>.bcpdirs.rec.txt` — recursive: список директорий

### Пакеты

```bash
sm pkg <manager> install <packages>   # установить пакеты
sm pkg <manager> remove <packages>    # удалить пакеты
sm pkg <manager> list                 # список пакетов
sm pkg <manager> search <query>       # поиск пакетов
```

Менеджеры: `pacman`, `yay`, `snap`

Флаги:
- `-y`, `--yes-all`, `--noconfirm` — без подтверждений

Пакеты можно перечислять через пробел или запятую: `pkg pacman install vim,git nano`.

Поиск использует нативную функцию менеджера (`pacman -Ss`, `yay -Ss`, `snap find`).

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

# Выполнить скрипт в папке проекта (независимо от текущей директории)
sm x myscript

# Выполнить скрипт в текущей папке
sm call myscript

# Создать рекурсивный бэкап папки smtools
sm bcp create -r smtools-backup
echo "smtools" | sm bcp edit smtools-backup
sm bcp backup smtools-backup

# Сменить режим бэкапа на shallow без редактирования списка
sm bcp set-mode -s smtools-backup

# Восстановить из бэкапа
sm bcp restore smtools-backup

# Установить gitignore
sm setgitignore dev
```

## Структура проекта

```
sm.sh              # основной скрипт
smtools/           # утилиты
  bcp.sh          # менеджер бэкапов
  pkg.sh          # менеджер пакетов
scripts/           # ваши скрипты
backups/           # бэкапы
dev.gitignore      # шаблон gitignore для разработки
user.gitignore     # шаблон gitignore для пользователя
```
