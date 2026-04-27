#!/bin/bash

SCRIPTS_DIR="./scripts"
mkdir -p "$SCRIPTS_DIR"

case "$1" in
    -h|--help|"")
        echo "Использование: $0 [команда]"
        echo "Команды:"
        echo "  -h, --help              Показать справку"
        echo "  --create <название>    Создать/редактировать скрипт (через nano)"
        echo "  --record <название>    Записать команды в файл"
        exit 0
        ;;
    --create)
        if [ -z "$2" ]; then echo "Укажите имя"; exit 1; fi
        FILE="$SCRIPTS_DIR/$2.sh"
        [ ! -f "$FILE" ] && echo "#!/bin/bash" > "$FILE"
        nano "$FILE"
        chmod +x "$FILE"
        ;;
    --record)
        if [ -z "$2" ]; then
            echo "Ошибка: Укажите название для записи"
            exit 1
        fi
        FILE="$SCRIPTS_DIR/$2.sh"
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
            chmod +x "$FILE"
            echo "Сохранено: $FILE"
        else
            rm -f "$TMP_HIST"
            echo "Нет записанных команд."
        fi
        ;;
    *)
        echo "Использование: $0 --create|--record <имя>"
        ;;
esac