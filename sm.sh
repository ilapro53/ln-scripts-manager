#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

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
        echo "  --cmd <команда>         Выполнить команду в директории проекта"
        echo "  pkg                    Работа с пакетами (install/remove/list)"
        echo "  bcp                    Работа с бэкапами (create/backup/restore)"
        echo "  ls                     Список скриптов"
        echo "  x <название>           Выполнить скрипт в папке утилиты"
        echo "  call <название>       Выполнить скрипт в текущей папке"
        exit 0
        ;;
    --init)
        DEST="/usr/local/bin/sm"
        if [ -w "$(dirname "$DEST")" ]; then
            rm -f "$DEST"
            ln -s "$(realpath "$0")" "$DEST"
            echo "Установлено: $DEST -> $(realpath "$0")"
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
    --cmd)
        if [ -z "$2" ]; then
            echo "Ошибка: укажите команду"
            exit 1
        fi
        cd "$SCRIPT_DIR"
        shift
        eval "$@"
        ;;
    pkg)
        "$SCRIPT_DIR/smtools/pkg" "${@:2}"
        ;;
    bcp)
        "$SCRIPT_DIR/smtools/bcp.sh" "${@:2}" --dir "$SCRIPT_DIR"
        ;;
    ls)
        if [ -n "$2" ]; then
            find "$SCRIPTS_DIR/$2" -name "*.sh" -type f 2>/dev/null | sed "s|$SCRIPTS_DIR/$2/||" | sed 's|\.sh$||' | sort
        else
            find "$SCRIPTS_DIR" -name "*.sh" -type f | sed "s|$SCRIPTS_DIR/||" | sed 's|\.sh$||' | sort
        fi
        ;;
    x)
        if [ -z "$2" ]; then echo "Укажите имя"; exit 1; fi
        FILE="$SCRIPTS_DIR/$2.sh"
        if [ ! -f "$FILE" ]; then echo "Скрипт не найден: $FILE"; exit 1; fi
        cd "$SCRIPT_DIR"
bash "$FILE"
        ;;
    x)
        if [ -z "$2" ]; then echo "Укажите имя"; exit 1; fi
        FILE="$SCRIPTS_DIR/$2.sh"
        if [ ! -f "$FILE" ]; then echo "Скрипт не найден: $FILE"; exit 1; fi
        cd "$SCRIPT_DIR"
        bash "$FILE"
        ;;
    call)
        if [ -z "$2" ]; then echo "Укажите имя"; exit 1; fi
        FILE="$SCRIPTS_DIR/$2.sh"
        if [ ! -f "$FILE" ]; then echo "Скрипт не найден: $FILE"; exit 1; fi
        bash "$FILE"
        ;;
    *)
        echo "Использование: $0 --create|--record <имя>"
        ;;
esac