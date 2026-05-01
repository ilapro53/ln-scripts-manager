#!/bin/bash

usage() {
    echo "Использование: pkg [флаги] <менеджер> <команда> <пакеты>"
    echo "Команды: install, remove, list, search"
    echo "Менеджеры: pacman, yay, snap"
    echo "Флаги:"
    echo "  -y, --yes-all, --noconfirm   Без подтверждений"
    exit 1
}

YES_FLAG=""

while [[ "$1" == -* ]]; do
    case "$1" in
        -y|--yes-all|--noconfirm)
            YES_FLAG="1"
            shift
            ;;
        *)
            usage
            ;;
    esac
done

MANAGER="${1:-}"
CMD="${2:-}"

[ -z "$MANAGER" ] || [ -z "$CMD" ] && usage

shift 2

# Поддержка и пробела, и запятой как разделителя пакетов
PACKAGES=()
for arg in "$@"; do
    IFS=',' read -ra parts <<< "$arg"
    PACKAGES+=("${parts[@]}")
done

check_manager() {
    command -v "$1" >/dev/null 2>&1 || { echo "Ошибка: менеджер пакетов '$1' не найден"; exit 1; }
}

case "$MANAGER" in
    pacman)
        check_manager pacman
        case "$CMD" in
            install)
                [ -n "$YES_FLAG" ] && sudo pacman -S --noconfirm "${PACKAGES[@]}" || sudo pacman -S "${PACKAGES[@]}"
                ;;
            remove)
                [ -n "$YES_FLAG" ] && sudo pacman -Rns --noconfirm "${PACKAGES[@]}" || sudo pacman -Rns "${PACKAGES[@]}"
                ;;
            list)
                pacman -Qq
                ;;
            search)
                pacman -Ss "$PKGS"
                ;;
            *) usage ;;
        esac
        ;;
    yay)
        check_manager yay
        case "$CMD" in
            install)
                [ -n "$YES_FLAG" ] && yay -S --noconfirm "${PACKAGES[@]}" || yay -S "${PACKAGES[@]}"
                ;;
            remove)
                [ -n "$YES_FLAG" ] && yay -Rns --noconfirm "${PACKAGES[@]}" || yay -Rns "${PACKAGES[@]}"
                ;;
            list)
                yay -Qq
                ;;
            search)
                yay -Ss "$PKGS"
                ;;
            *) usage ;;
        esac
        ;;
    snap)
        check_manager snap
        case "$CMD" in
            install)
                for pkg in "${PACKAGES[@]}"; do
      