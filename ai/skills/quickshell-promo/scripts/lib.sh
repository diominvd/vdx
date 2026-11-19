#!/usr/bin/env bash
# API для дублей. Подключается из promo/takes/*.sh:  source "$PROMO_LIB"
# Все функции синхронные; время между действиями задаётся только beat.

: "${PROMO_T0:=$(date +%s%N)}"
: "${PROMO_MARKERS:=/dev/null}"

log() { printf '[promo] %s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

_qs() {
  if [[ -n "${QS_CONFIG:-}" ]]; then qs -c "$QS_CONFIG" "$@"; else qs "$@"; fi
}

# ipc <target> <function> [args...]   — qs ipc call
ipc() { _qs ipc call "$@" >/dev/null || die "ipc $*"; }

# gshort <appid>:<name>   — Quickshell GlobalShortcut
gshort() { hyprctl dispatch global "$1" >/dev/null || die "gshort $1"; }

# hc <hyprctl args...>
hc() { hyprctl "$@" >/dev/null || die "hyprctl $*"; }

# beat <seconds>
beat() { sleep "${1:-1}"; }

# mark <name>   — время от старта записи в .markers
mark() {
  local now; now=$(date +%s%N)
  awk -v a="$now" -v b="$PROMO_T0" -v n="$1" 'BEGIN{printf "%.3f %s\n", (a-b)/1e9, n}' >>"$PROMO_MARKERS"
}

_cursor() { hyprctl cursorpos | tr -d ' ' | tr ',' ' '; }

# cursor_to <x> <y>   — мгновенно, логические координаты
cursor_to() { hc dispatch movecursor "$1" "$2"; }

# glide <x> <y> [ms=700]   — плавно, ease-in-out
glide() {
  local tx=$1 ty=$2 ms=${3:-700} sx sy
  read -r sx sy < <(_cursor)
  local steps=$(( ms * 60 / 1000 )); (( steps < 1 )) && steps=1
  local dt; dt=$(awk -v m="$ms" -v s="$steps" 'BEGIN{printf "%.4f", m/1000/s}')
  awk -v sx="$sx" -v sy="$sy" -v tx="$tx" -v ty="$ty" -v n="$steps" 'BEGIN{
    for(i=1;i<=n;i++){t=i/n; e=(t<.5)?4*t*t*t:1-((-2*t+2)^3)/2;
      printf "%d %d\n", sx+(tx-sx)*e, sy+(ty-sy)*e}}' |
  while read -r x y; do
    hyprctl dispatch movecursor "$x" "$y" >/dev/null
    sleep "$dt"
  done
}

# click [left|right|middle]   — нужен ydotoold
click() {
  command -v ydotool >/dev/null || die "click: ydotool не установлен"
  case "${1:-left}" in
    left) ydotool click 0xC0 ;; right) ydotool click 0xC1 ;; middle) ydotool click 0xC2 ;;
    *) die "click: $1" ;;
  esac >/dev/null
}

# type_text "строка" [delay_ms=45]
type_text() {
  command -v wtype >/dev/null || die "type_text: wtype не установлен"
  wtype -d "${2:-45}" "$1"
}

# key <keysym> [mods...]   — например: key Escape;  key Return
key() {
  command -v wtype >/dev/null || die "key: wtype не установлен"
  local k=$1; shift; local down=() up=()
  for m in "$@"; do down+=(-M "$m"); up+=(-m "$m"); done
  wtype "${down[@]}" -k "$k" "${up[@]}"
}
