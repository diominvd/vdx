#!/usr/bin/env bash
# Откат prep-env.sh. Безопасно запускать повторно.
state=${XDG_RUNTIME_DIR:-/tmp}/qs-promo

hyprctl reload >/dev/null   # сбрасывает все hyprctl keyword

while read -r n; do
  case $n in
    mako) makoctl mode -r do-not-disturb >/dev/null ;;
    swaync) swaync-client -df >/dev/null ;;
    dunst) dunstctl set-paused false ;;
  esac
done < <(cat "$state/notify" 2>/dev/null)

[[ -f $state/workspace ]] && hyprctl dispatch workspace "$(cat "$state/workspace")" >/dev/null
rm -rf "$state"
echo "окружение восстановлено"
