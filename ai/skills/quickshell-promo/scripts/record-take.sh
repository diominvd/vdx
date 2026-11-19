#!/usr/bin/env bash
# record-take.sh promo/takes/NN-slug.sh
# Переключается на пустой воркспейс, пишет монитор, выполняет дубль, возвращается.
# Выход: promo/raw/NN-slug.mp4 и promo/raw/NN-slug.markers
set -euo pipefail

take=${1:?usage: record-take.sh <take.sh>}
[[ -f $take ]] || { echo "нет файла: $take" >&2; exit 1; }

SKILL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
slug=$(basename "$take" .sh)
raw=${PROMO_RAW:-$(cd "$(dirname "$take")/.." && pwd)/raw}
mkdir -p "$raw"
out="$raw/$slug.mp4"
markers="$raw/$slug.markers"
: >"$markers"

ws=${PROMO_WORKSPACE:-name:promo}
mon=${PROMO_MONITOR:-$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')}
prev=$(hyprctl activeworkspace -j | jq -r '.id')
warmup=${PROMO_WARMUP:-1}

rec_pid=""
cleanup() {
  if [[ -n $rec_pid ]] && kill -0 "$rec_pid" 2>/dev/null; then
    kill -INT "$rec_pid"; wait "$rec_pid" 2>/dev/null || true
  fi
  hyprctl dispatch workspace "$prev" >/dev/null || true
}
trap cleanup EXIT

hyprctl dispatch workspace "$ws" >/dev/null
sleep 0.6   # анимация переключения воркспейса

T0=$(date +%s%N)
if command -v gpu-screen-recorder >/dev/null; then
  gpu-screen-recorder -w "$mon" -f 60 -fm cfr -k h264 -q ultra -cursor yes -o "$out" \
    >"$raw/$slug.log" 2>&1 &
else
  wf-recorder -o "$mon" -r 60 -c libx264 -p crf=14 -p preset=fast -f "$out" \
    >"$raw/$slug.log" 2>&1 &
fi
rec_pid=$!
sleep "$warmup"
kill -0 "$rec_pid" 2>/dev/null || { echo "рекордер упал, см. $raw/$slug.log" >&2; exit 1; }

PROMO_T0=$T0 PROMO_MARKERS=$markers PROMO_LIB="$SKILL_DIR/scripts/lib.sh" \
  bash "$take"

cleanup; rec_pid=""; trap - EXIT
dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out")
echo "OK $out (${dur}s)"
echo "markers:"; cat "$markers"
