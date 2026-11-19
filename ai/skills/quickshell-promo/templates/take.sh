#!/usr/bin/env bash
# Дубль NN-slug. Запуск только через record-take.sh.
# Сцена из storyboard.md: <название> — <что показываем>
set -euo pipefail
# shellcheck source=ai/skills/quickshell-promo/scripts/lib.sh
source "$PROMO_LIB"

# --- подготовка (до mark in, в кадре — покой) ---
cursor_to 1900 1060          # курсор в угол, если не нужен
beat 1

mark in

# --- действие ---
ipc wifi toggle              # пример: открыть панель по IPC
beat 1.2                     # анимация + время рассмотреть
mark open

glide 1700 120 800           # подвести курсор к элементу
beat 0.4
# click                      # если есть ydotool
beat 1.5

ipc wifi toggle              # закрыть
beat 0.8

mark out
beat 1
