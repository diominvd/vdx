#!/usr/bin/env bash
# Чистое окружение для записи. Только рантайм-изменения; откат — restore-env.sh.
set -euo pipefail
state=${XDG_RUNTIME_DIR:-/tmp}/qs-promo
mkdir -p "$state"

hyprctl activeworkspace -j | jq -r '.id' >"$state/workspace"
: >"$state/notify"

hyprctl --batch "keyword misc:disable_hyprland_logo true; keyword misc:disable_splash_rendering true; keyword cursor:inactive_timeout 0" >/dev/null

if command -v makoctl >/dev/null && pgrep -x mako >/dev/null; then
  makoctl mode -a do-not-disturb >/dev/null && echo mako >>"$state/notify"
fi
if command -v swaync-client >/dev/null && pgrep -x swaync >/dev/null; then
  swaync-client -dn >/dev/null && echo swaync >>"$state/notify"
fi
if command -v dunstctl >/dev/null && pgrep -x dunst >/dev/null; then
  dunstctl set-paused true && echo dunst >>"$state/notify"
fi

ws=${PROMO_WORKSPACE:-name:promo}
wsname=${ws#name:}
n=$(hyprctl clients -j | jq --arg w "$wsname" '[.[] | select(.workspace.name == $w)] | length')
[[ $n -eq 0 ]] || echo "ВНИМАНИЕ: на воркспейсе $wsname $n окон — они попадут в кадр"

hyprctl monitors -j | jq -r '.[] | "монитор \(.name): \(.width)x\(.height)@\(.refreshRate|floor) scale \(.scale)\(if .focused then " (focused)" else "" end)"'
echo "уведомления заглушены: $(tr '\n' ' ' <"$state/notify")"
