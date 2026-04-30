#!/bin/bash

WORKDIR="."

usage() {
    echo "Использование: bcp [опции] <команда> [имя]"
    echo "Опции:"
    echo "  -d, --dir <папка>     Папка для бэкапов"
    echo "Команды:"
    echo "  create -s|-r <имя>   Создать пустой бэкап (-s: shallow, -r: recursive)"
    echo "  edit [-s|-r] <имя>  Редактировать список директорий"
    echo "  backup <имя>       Создать бэкап"
    echo "  restore <имя>      Восстановить из бэкапа"
    echo "  delete <имя>       Удалить бэкап"
    echo "  list               Список бэкапов"
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

BACKUPS_DIR="$WORKDIR/backups"

get_backup_dir() { echo "$BACKUPS_DIR/$1"; }
get_dirs_file() { echo "$BACKUPS_DIR/$1.bcpdirs.txt"; }
get_dirs_file_rec() { echo "$BACKUPS_DIR/$1.bcpdirs.rec.txt"; }
get_meta_file() { echo "$BACKUPS_DIR/$1.bcp.json"; }

has_both_dirs() {
    local DIRS_FILE="$(get_dirs_file "$1")"
    local DIRS_FILE_REC="$(get_dirs_file_rec "$1")"
    [ -f "$DIRS_FILE" ] && [ -f "$DIRS_FILE_REC" ]
}

get_mode() {
    local DIRS_FILE="$(get_dirs_file "$1")"
    local DIRS_FILE_REC="$(get_dirs_file_rec "$1")"
    if [ -f "$DIRS_FILE_REC" ]; then
        echo "recursive"
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
    done
    for f in "$BACKUPS_DIR"/*.bcpdirs.txt; do
        [ -f "$f" ] || continue
        name=$(basename "$f" .bcpdirs.txt)
        if [ -d "$BACKUPS_DIR/$name" ]; then continue; fi
        mode=$(get_mode "$name")
        echo "$name ($mode)"
    done | sort
}

bcp_create() {
    local NAME="$1"
    local DIR="$(get_backup_dir "$NAME")"
    local DIRS_FILE="$(get_dirs_file "$NAME")"
    local DIRS_FILE_REC="$(get_dirs_file_rec "$NAME")"
    
    [ -z "$NAME" ] && echo "Укажите имя" && exit 1
    [ -z "$MODE" ] && echo "Укажите режим: -s (shallow) или -r (recursive)" && exit 1
    [ -d "$DIR" ] || [ -f "$DIRS_FILE" ] || [ -f "$DIRS_FILE_REC" ] && echo "Уже существует: $NAME" && exit 1
    
    mkdir -p "$DIR"
    if [ "$MODE" = "recursive" ]; then
        touch "$DIRS_FILE_REC"
        echo "Создано: $NAME (recursive)"
    else
        touch "$DIRS_FILE"
        echo "Создано: $NAME (shallow)"
    fi
}

bcp_edit() {
    local NAME="$1"
    local DIRS_FILE="$(get_dirs_file "$NAME")"
    local DIRS_FILE_REC="$(get_dirs_file_rec "$NAME")"
    
    [ -z "$NAME" ] && echo "Укажите имя" && exit 1
    
    if has_both_dirs "$NAME"; then
        echo "Ошибка: найдены оба файла директорий. Удалите один из них."
        exit 1
    fi
    
    if [ -n "$MODE" ]; then
        if [ "$MODE" = "recursive" ]; then
            [ -f "$DIRS_FILE" ] && mv "$DIRS_FILE" "$DIRS_FILE_REC"
        else
            [ -f "$DIRS_FILE_REC" ] && mv "$DIRS_FILE_REC" "$DIRS_FILE"
        fi
        mode=$(get_mode "$NAME")
        echo "Сохранено: $NAME ($mode)"
        return 0
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
        echo "Введите директории:"
        CONTENT=$(cat | sed 's|^\./||')
        echo "$CONTENT" > "$ACTIVE_FILE"
    fi
    
    mode=$(get_mode "$NAME")
    echo "Сохранено: $NAME ($mode)"
}

bcp_backup() {
    local NAME="$1"
    local DIR="$(get_backup_dir "$NAME")"
    local DIRS_FILE="$(get_dirs_file "$NAME")"
    local DIRS_FILE_REC="$(get_dirs_file_rec "$NAME")"
    local META_FILE="$(get_meta_file "$NAME")"
    local TMP_JSON=$(mktemp)
    
    [ -z "$NAME" ] && echo "Укажите имя" && exit 1
    
    if has_both_dirs "$NAME"; then
        echo "Ошибка: найдены оба файла директорий. Удалите один из них."
        exit 1
    fi
    
    [ ! -f "$DIRS_FILE" ] && [ ! -f "$DIRS_FILE_REC" ] && echo "Не существует: $NAME" && exit 1
    
    rm -rf "$DIR" "$META_FILE"
    mkdir -p "$DIR"
    
    > "$TMP_JSON"
    
    if [ -f "$DIRS_FILE_REC" ]; then
        DIRS_TO_PROCESS="$DIRS_FILE_REC"
    else
        DIRS_TO_PROCESS="$DIRS_FILE"
    fi
    
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line#./}"
        [ -z "$line" ] && continue
        
        if [ -d "$line" ]; then
            find "$line" -type f | while read -r file; do
                [ -f "$file" ] || continue
                HASH=$(sha256sum "$file" | cut -d' ' -f1)
                REL_PATH="${file#./}"
                UNIQ="$HASH.$(echo "$REL_PATH" | tr '/' '_').bcpf"
                cp "$file" "$DIR/$UNIQ"
                echo "    \"$REL_PATH\": \"$UNIQ\"," >> "$TMP_JSON"
            done
        elif [ -f "$line" ]; then
            HASH=$(sha256sum "$line" | cut -d' ' -f1)
            REL_PATH="${line#./}"
            UNIQ="$HASH.$REL_PATH.bcpf"
            cp "$line" "$DIR/$UNIQ"
            echo "    \"$REL_PATH\": \"$UNIQ\"," >> "$TMP_JSON"
        fi
    done < "$DIRS_TO_PROCESS"
    
    NOW=$(date -Iseconds)
    MODE=$(get_mode "$NAME")
    {
        echo "{"
        echo "  \"name\": \"$NAME\","
        echo "  \"time\": \"$NOW\","
        echo "  \"mode\": \"$MODE\","
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
    local DIR="$(get_backup_dir "$NAME")"
    local META_FILE="$(get_meta_file "$NAME")"
    
    [ -z "$NAME" ] && echo "Укажите имя" && exit 1
    [ ! -f "$META_FILE" ] && echo "Не найден: $NAME" && exit 1
    
    MODE=$(get_mode "$NAME")
    
    while IFS= read -r line; do
        echo "$line" | grep -q '":.*\.bcpf"' || continue
        
        ORIG_PATH=$(echo "$line" | sed 's/.*"\([^"]*\)":.*/\1/' | tr -d ' ')
        ORIG_PATH="${ORIG_PATH#./}"
        HASH=$(echo "$line" | sed 's/.*": *"\([^"]*\)".*/\1/')
        
        [ -z "$ORIG_PATH" ] && continue
        
        FULL_DIR=$(dirname "$ORIG_PATH")
        [ -n "$FULL_DIR" ] && [ "$FULL_DIR" != "." ] && mkdir -p "$FULL_DIR"
        
        [ -f "$DIR/$HASH" ] && cp "$DIR/$HASH" "$ORIG_PATH" && echo "Restored: $ORIG_PATH"
    done < "$META_FILE"
    
    echo "Готово: $NAME ($MODE)"
}

bcp_delete() {
    local NAME="$1"
    local DIR="$(get_backup_dir "$NAME")"
    local DIRS_FILE="$(get_dirs_file "$NAME")"
    local DIRS_FILE_REC="$(get_dirs_file_rec "$NAME")"
    local META_FILE="$(get_meta_file "$NAME")"
    
    [ -z "$NAME" ] && echo "Укажите имя" && exit 1
    [ ! -d "$DIR" ] && [ ! -f "$DIRS_FILE" ] && [ ! -f "$DIRS_FILE_REC" ] && echo "Не существует: $NAME" && exit 1
    
    rm -rf "$DIR" "$DIRS_FILE" "$DIRS_FILE_REC" "$META_FILE"
    echo "Удалено: $NAME"
}

CMD="${ARGS[0]:-}"
NAME="${ARGS[1]:-}"

case "$CMD" in
    create) bcp_create "$NAME" ;;
    edit) bcp_edit "$NAME" ;;
    backup) bcp_backup "$NAME" ;;
    restore) bcp_restore "$NAME" ;;
    delete) bcp_delete "$NAME" ;;
    list) bcp_list ;;
    *) usage ;;
esac