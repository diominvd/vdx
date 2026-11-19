#!/usr/bin/env bash
# normalize.sh <raw_dir> <clips_dir>
# CFR 60 fps, yuv420p, h264 crf 14, без звука, faststart. Копирует .markers рядом.
set -euo pipefail
src=${1:?usage: normalize.sh <raw_dir> <clips_dir>}
dst=${2:?usage: normalize.sh <raw_dir> <clips_dir>}
mkdir -p "$dst"

shopt -s nullglob
for f in "$src"/*.mp4; do
  name=$(basename "$f")
  ffmpeg -v error -y -i "$f" -an \
    -vf "fps=60,format=yuv420p" -c:v libx264 -crf 14 -preset slow \
    -movflags +faststart "$dst/$name"
  [[ -f ${f%.mp4}.markers ]] && cp "${f%.mp4}.markers" "$dst/"
  wh=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$dst/$name")
  echo "$dst/$name $wh"
done
