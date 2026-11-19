#!/usr/bin/env bash
# contact-sheet.sh <video> [sec]
#   без sec — сетка 4×3 кадров по всей длине -> <video>.png
#   с sec   — один кадр в полном разрешении -> <video>@<sec>.png
set -euo pipefail
in=${1:?usage: contact-sheet.sh <video> [sec]}
base=${in%.*}

if [[ -n ${2:-} ]]; then
  ffmpeg -v error -y -ss "$2" -i "$in" -frames:v 1 "$base@$2.png"
  echo "$base@$2.png"; exit 0
fi

dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$in")
rate=$(awk -v d="$dur" 'BEGIN{printf "%.5f", 12/d}')
label="drawtext=text='%{pts\:hms}':x=8:y=8:fontsize=22:fontcolor=white:box=1:boxcolor=black@0.6"
vf="fps=$rate,scale=640:-2"

ffmpeg -v error -y -i "$in" -vf "$vf,$label,tile=4x3:padding=4" -frames:v 1 "$base.png" 2>/dev/null ||
ffmpeg -v error -y -i "$in" -vf "$vf,tile=4x3:padding=4" -frames:v 1 "$base.png"
echo "$base.png (${dur}s, 12 кадров, шаг $(awk -v d="$dur" 'BEGIN{printf "%.2f", d/12}')s)"
