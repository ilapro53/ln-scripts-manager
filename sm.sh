#!/bin/bash

SCRIPTS_DIR="$(dirname "$0")/scripts"
mkdir -p "$SCRIPTS_DIR"

cleanup_empty_dirs() {
    local FILE="$1"
    local DIR="$(dirname "$FILE")"
    
    while [ "$DIR" != "." ] && [ "$DIR" != "/" ] && [ -n "$DIR" ]; do
        if [ -d "$DIR" ] && [ -z "$(ls -A "$DIR")" ]; then
            rmdir "$DIR"
        else
            break
        fi
        DIR="$(dirname "$DIR")"
    done
}

case "$1" in
    -h|--help|"")
        echo "Использование: $0 [команда]"
        echo "Команды:"
        echo "  -h, --help              Показать справку"
        echo "  --init                 Установить как глобальную команду"
        echo "  -c, -e, --create, --edit <название>  Создать/редактировать скрипт"
        echo "  -r, --record <название>  Записать команды в файл"
        exit 0
        ;;
    --init)
        DEST="/usr/local/bin/sm"
        if [ -w "$(dirname "$DEST")" ]; then
            cp "$0" "$DEST"
            chmod +x "$DEST"
            echo "Установлено: $DEST"
        else
            echo "Ошибка: нет прав на запись в /usr/local/bin"
            echo "Попробуйте: sudo $0 --init"
        fi
        exit 0
        ;;
    -c|-e|--create|--edit)
        if [ -z "$2" ]; then echo "Укажите имя"; exit 1; fi
        FILE="$SCRIPTS_DIR/$2.sh"
        mkdir -p "$(dirname "$FILE")"
        [ ! -f "$FILE" ] && echo "#!/bin/bash" > "$FILE"
        nano "$FILE"
        
        CONTENT=$(cat "$FILE")
        if [ -z "$CONTENT" ] || [ "$CONTENT" = "#!/bin/bash" ]; then
            rm -f "$FILE"
            cleanup_empty_dirs "$FILE"
            echo "Файл удалён (пустой)"
        else
            chmod +x "$FILE"
            echo "Сохранено: $FILE"
        fi
        ;;
    -r|--record)
        if [ -z "$2" ]; then
            echo "Ошибка: Укажите название для записи"
            exit 1
        fi
        FILE="$SCRIPTS_DIR/$2.sh"
        mkdir -p "$(dirname "$FILE")"
        TMP_HIST=$(mktemp)
        WRAPPER=$(mktemp)
        
        echo "Запись команд в $FILE..."
        echo "Введите 'exit' для завершения."
        
        cat > "$WRAPPER" << EOFWRAPPER
export HISTFILE=$TMP_HIST
export PROMPT_COMMAND='history -a'
set -o history
PS1='record> '
EOFWRAPPER
        
        bash --rcfile "$WRAPPER" -i
        rm -f "$WRAPPER"
        
        if [ -s "$TMP_HIST" ]; then
            echo "#!/bin/bash" > "$FILE"
            grep -v "^exit$" "$TMP_HIST" | grep -v "^$" | grep -v "^PS1=" >> "$FILE"
            rm "$TMP_HIST"
            
            CONTENT=$(cat "$FILE")
            if [ -z "$CONTENT" ] || [ "$CONTENT" = "#!/bin/bash" ]; then
                rm -f "$FILE"
                cleanup_empty_dirs "$FILE"
                echo "Файл удалён (пустой)"
            else
                chmod +x "$FILE"
                echo "Сохранено: $FILE"
            fi
        else
            rm -f "$TMP_HIST"
            echo "Нет записанных команд."
        fi
        ;;
    *)
        echo "Использование: $0 --create|--record <имя>"
        ;;
esac