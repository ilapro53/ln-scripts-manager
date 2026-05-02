#!/bin/bash
set -euo pipefail

WORKDIR="."

usage() {
    echo "Использование: bcp [опции] <команда> [имя]"
    echo "Опции:"
    echo "  -d, --dir <папка>     Папка проекта (по умолчанию: текущая)"
    echo "Команды:"
    echo "  create -s|-r <имя>   Создать пустой бэкап (-s: shallow, -r: recursive)"
    echo "  edit [-s|-r] <имя>   Редактировать список директорий (с переключением режима)"
    echo "  set-mode -s|-r <имя> Сменить режим без открытия редактора"
    echo "  backup <имя>         Создать бэкап"
    echo "  restore <имя>        Восстановить из бэкапа"
    echo "  delete <имя>         Удалить бэкап"
    echo "  list                 Список бэкапов"
    exit 1
}

ARGS=()
MODE=""

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--dir)
            WORKDIR="$2"
            shift 2
            ;;
        -s|--shallow)
            MODE="shallow"
            shift
            ;;
        -r|--recursive)
            MODE="recursive"
            shift
            ;;
        -*)
            ARGS+=("$1")
            shift
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Resolve WORKDIR to absolute path so cd inside functions doesn't break relative paths
WORKDIR="$(cd "$WORKDIR" 2>/dev/null && pwd)" || { echo "Ошибка: директория не найдена: $WORKDIR"; exit 1; }
BACKUPS_DIR="$WORKDIR/backups"

get_backup_dir() { echo "$BACKUPS_DIR/$1"; }
get_dirs_file() { echo "$BACKUPS_DIR/$1.bcpdirs.txt"; }
get_dirs_file_rec() { echo "$BACKUPS_DIR/$1.bcpdirs.rec.txt"; }
get_mode_file() { echo "$BACKUPS_DIR/$1.backup.mode.txt"; }
get_meta_file() { echo "$BACKUPS_DIR/$1.bcp.json"; }

has_both_dirs() {
    [ -f "$(get_dirs_file "$1")" ] && [ -f "$(get_dirs_file_rec "$1")" ]
}

get_template_mode() {
    if [ -f "$(get_dirs_file_rec "$1")" ]; then
        echo "recursive"
    else
        echo "shallow"
    fi
}

set_mode() {
    echo "$2" > "$(get_mode_file "$1")"
}

get_mode() {
    local MODE_FILE
    MODE_FILE="$(get_mode_file "$1")"
    if [ -f "$MODE_FILE" ]; then
        cat "$MODE_FILE"
    else
        echo "shallow"
    fi
}

bcp_list() {
    [ ! -d "$BACKUPS_DIR" ] && echo "Нет бэкапов" && return
    for dir in "$BACKUPS_DIR"/*/; do
        [ -d "$dir" ] || continue
        name=$(basename "$dir")
        mode=$(get_mode "$name")
        echo "$name ($mode)"
    done | sort
}

bcp_create() {
    local NAME="$1"
    local DIR
    local DIRS_FILE
    local DIRS_FILE_REC
    local MODE_FILE
    DIR="$(get_backup_dir "$NAME")"
    DIRS_FILE="$(get_dirs_file "$NAME")"
    DIRS_FILE_REC="$(get_dirs_file_rec "$NAME")"
    MODE_FILE="$(get_mode_file "$NAME")"

    if [ -z "$NAME" ]; then echo "Укажите имя"; exit 1; fi
    if [ -z "$MODE" ]; then echo "Укажите режим: -s (shallow) или -r (recursive)"; exit 1; fi
    if [ -d "$DIR" ] || [ -f "$DIRS_FILE" ] || [ -f "$DIRS_FILE_REC" ] || [ -f "$MODE_FILE" ]; then
        echo "Уже существует: $NAME"; exit 1
    fi

    mkdir -p "$DIR"
    if [ "$MODE" = "recursive" ]; then
        touch "$DIRS_FILE_REC"
    else
        touch "$DIRS_FILE"
    fi
    set_mode "$NAME" "$MODE"
    echo "Создано: $NAME ($MODE)"
}

bcp_edit() {
    local NAME="$1"
    local DIRS_FILE
    local DIRS_FILE_REC
    DIRS_FILE="$(get_dirs_file "$NAME")"
    DIRS_FILE_REC="$(get_dirs_file_rec "$NAME")"

    if [ -z "$NAME" ]; then echo "Укажите имя"; exit 1; fi

    if has_both_dirs "$NAME"; then
        echo "Ошибка: найдены оба файла директорий. Удалите один."
        exit 1
    fi

    # If mode flag given, rename the dirs file (change template mode), then open editor
    if [ -n "$MODE" ]; then
        if [ "$MODE" = "recursive" ]; then
            [ -f "$DIRS_FILE" ] && mv "$DIRS_FILE" "$DIRS_FILE_REC"
        else
            [ -f "$DIRS_FILE_REC" ] && mv "$DIRS_FILE_REC" "$DIRS_FILE"
        fi
    fi

    local ACTIVE_FILE=""
    if [ -f "$DIRS_FILE_REC" ]; then
        ACTIVE_FILE="$DIRS_FILE_REC"
    elif [ -f "$DIRS_FILE" ]; then
        ACTIVE_FILE="$DIRS_FILE"
    else
        echo "Не существует: $NAME"
        exit 1
    fi

    if [ -t 0 ] && command -v nano >/dev/null 2>&1; then
        nano "$ACTIVE_FILE"
    else
        CONTENT=$(cat | sed 's|^\./||')
        echo "$CONTENT" > "$ACTIVE_FILE"
    fi

    echo "Сохранено: $NAME (бэкап: $(get_mode "$NAME"), образ: $(get_template_mode "$NAME"))"
}

# Change template mode (rename dirs file) without opening editor
bcp_set_mode() {
    local NAME="$1"
    local DIRS_FILE
    local DIRS_FILE_REC
    DIRS_FILE="$(get_dirs_file "$NAME")"
    DIRS_FILE_REC="$(get_dirs_file_rec "$NAME")"

    if [ -z "$NAME" ]; then echo "Укажите имя"; exit 1; fi
    if [ -z "$MODE" ]; then echo "Укажите режим: -s (shallow) или -r (recursive)"; exit 1; fi

    if has_both_dirs "$NAME"; then
        echo "Ошибка: найдены оба файла директорий. Удалите один."
        exit 1
    fi

    if [ "$MODE" = "recursive" ]; then
        if [ -f "$DIRS_FILE" ]; then
            mv "$DIRS_FILE" "$DIRS_FILE_REC"
        elif [ ! -f "$DIRS_FILE_REC" ]; then
            echo "Не существует: $NAME"; exit 1
        fi
    else
        if [ -f "$DIRS_FILE_REC" ]; then
            mv "$DIRS_FILE_REC" "$DIRS_FILE"
        elif [ ! -f "$DIRS_FILE" ]; then
            echo "Не существует: $NAME"; exit 1
        fi
    fi

    echo "Режим изменён: $NAME ($MODE)"
}

bcp_backup() {
    local NAME="$1"
    local DIR
    local DIRS_FILE
    local DIRS_FILE_REC
    local META_FILE
    local TMP_JSON
    DIR="$(get_backup_dir "$NAME")"
    DIRS_FILE="$(get_dirs_file "$NAME")"
    DIRS_FILE_REC="$(get_dirs_file_rec "$NAME")"
    META_FILE="$(get_meta_file "$NAME")"
    TMP_JSON=$(mktemp)

    if [ -z "$NAME" ]; then echo "Укажите имя"; exit 1; fi

    if has_both_dirs "$NAME"; then
        echo "Ошибка: найдены оба файла директорий. Удалите один."
        exit 1
    fi

    if [ ! -f "$DIRS_FILE" ] && [ ! -f "$DIRS_FILE_REC" ]; then echo "Не существует: $NAME"; exit 1; fi

    local TEMPLATE_MODE
    TEMPLATE_MODE=$(get_template_mode "$NAME")
    set_mode "$NAME" "$TEMPLATE_MODE"
    MODE="$TEMPLATE_MODE"

    local DIRS_TO_PROCESS
    if [ -f "$DIRS_FILE_REC" ]; then
        DIRS_TO_PROCESS="$DIRS_FILE_REC"
    else
        DIRS_TO_PROCESS="$DIRS_FILE"
    fi

    # Prompt only when a previous backup exists (meta file present or backup dir non-empty)
    if [ -t 0 ]; then
        if [ -f "$META_FILE" ] || { [ -d "$DIR" ] && [ -n "$(ls -A "$DIR" 2>/dev/null)" ]; }; then
            printf "Бэкап '%s' уже существует. Перезаписать? [y/N] " "$NAME"
            read -r REPLY
            [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ] || { echo "Отменено."; exit 0; }
        fi
    fi

    rm -rf "$DIR" "$META_FILE"
    mkdir -p "$DIR"
    > "$TMP_JSON"

    # All file paths in bcpdirs are relative to WORKDIR
    cd "$WORKDIR"

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line#./}"
        [ -z "$line" ] && continue

        if [ -d "$line" ]; then
            if [ "$MODE" = "recursive" ]; then
                find "$line" -type f | while read -r file; do
                    [ -f "$file" ] || continue
                    HASH=$(sha256sum "$file" | cut -d' ' -f1)
                    REL_PATH="${file#./}"
                    UNIQ="$HASH.$(echo "$REL_PATH" | tr '/' '_').bcpf"
                    cp "$file" "$DIR/$UNIQ"
                    echo "    \"$REL_PATH\": \"$UNIQ\"," >> "$TMP_JSON"
                done
            else
                for file in "$line"/*; do
                    [ -f "$file" ] || continue
                    HASH=$(sha256sum "$file" | cut -d' ' -f1)
                    REL_PATH="${file#./}"
                    UNIQ="$HASH.$(echo "$REL_PATH" | tr '/' '_').bcpf"
                    cp "$file" "$DIR/$UNIQ"
                    echo "    \"$REL_PATH\": \"$UNIQ\"," >> "$TMP_JSON"
                done
            fi
        elif [ -f "$line" ]; then
            HASH=$(sha256sum "$line" | cut -d' ' -f1)
            REL_PATH="${line#./}"
            UNIQ="$HASH.$REL_PATH.bcpf"
            cp "$line" "$DIR/$UNIQ"
            echo "    \"$REL_PATH\": \"$UNIQ\"," >> "$TMP_JSON"
        fi
    done < "$DIRS_TO_PROCESS"

    local NOW
    NOW=$(date -Iseconds)
    {
        echo "{"
        echo "  \"name\": \"$NAME\","
        echo "  \"time\": \"$NOW\","
        echo "  \"files\": {"
        [ -s "$TMP_JSON" ] && sed '$ s/,$//' "$TMP_JSON"
        echo "  }"
        echo "}"
    } > "$META_FILE"
    rm -f "$TMP_JSON"

    echo "Готово: $NAME ($MODE)"
}

bcp_restore() {
    local NAME="$1"
    local DIR
    local META_FILE
    DIR="$(get_backup_dir "$NAME")"
    META_FILE="$(get_meta_file "$NAME")"

    if [ -z "$NAME" ]; then echo "Укажите имя"; exit 1; fi
    if [ ! -f "$META_FILE" ]; then echo "Не найден: $NAME"; exit 1; fi

    local RESTORE_MODE
    RESTORE_MODE=$(get_mode "$NAME")

    # Restore paths are relative to WORKDIR
    cd "$WORKDIR"

    while IFS= read -r line; do
        echo "$line" | grep -q '":.*\.bcpf"' || continue

        local ORIG_PATH
        ORIG_PATH=$(echo "$line" | sed 's/.*"\([^"]*\)":.*/\1/' | tr -d ' ')
        ORIG_PATH="${ORIG_PATH#./}"
        local HASH
        HASH=$(echo "$line" | sed 's/.*": *"\([^"]*\)".*/\1/')

        [ -z "$ORIG_PATH" ] && continue

        local FULL_DIR
        FULL_DIR=$(dirname "$ORIG_PATH")
        [ -n "$FULL_DIR" ] && [ "$FULL_DIR" != "." ] && mkdir -p "$FULL_DIR"

        if [ ! -f "$DIR/$HASH" ]; then continue; fi

        # Confirm before overwriting existing files (interactive only)
        if [ -f "$ORIG_PATH" ] && [ -t 0 ]; then
            printf "Файл '%s' уже существует. Перезаписать? [y/N] " "$ORIG_PATH"
            read -r REPLY
            [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ] || continue
        fi

        cp "$DIR/$HASH" "$ORIG_PATH"
        echo "Restored: $ORIG_PATH"
    done < "$META_FILE"

    echo "Готово: $NAME ($RESTORE_MODE)"
}

bcp_delete() {
    local NAME="$1"
    local DIR
    local DIRS_FILE
    local DIRS_FILE_REC
    local MODE_FILE
    local META_FILE
    DIR="$(get_backup_dir "$NAME")"
    DIRS_FILE="$(get_dirs_file "$NAME")"
    DIRS_FILE_REC="$(get_dirs_file_rec "$NAME")"
    MODE_FILE="$(get_mode_file "$NAME")"
    META_FILE="$(get_meta_file "$NAME")"

    if [ -z "$NAME" ]; then echo "Укажите имя"; exit 1; fi
    if [ ! -d "$DIR" ] && [ ! -f "$DIRS_FILE" ] && [ ! -f "$DIRS_FILE_REC" ]; then
        echo "Не существует: $NAME"; exit 1
    fi

    rm -rf "$DIR" "$DIRS_FILE" "$DIRS_FILE_REC" "$MODE_FILE" "$META_FILE"
    echo "Удалено: $NAME"
}

CMD="${ARGS[0]:-}"
NAME="${ARGS[1]:-}"

case "$CMD" in
    create)   bcp_create   "$NAME" ;;
    edit)     bcp_edit     "$NAME" ;;
    set-mode) bcp_set_mode "$NAME" ;;
    backup)   bcp_backup   "$NAME" ;;
    restore)  bcp_restore  "$NAME" ;;
    delete)   bcp_delete   "$NAME" ;;
    list)     bcp_list ;;
    *)        usage ;;
esac
