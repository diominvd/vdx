#!/usr/bin/env bash
# Проверка зависимостей. Ничего не устанавливает.
miss=() ; opt=()
declare -A pkg=(
  [hyprctl]=hyprland [qs]=quickshell [ffmpeg]=ffmpeg [ffprobe]=ffmpeg [jq]=jq
  [node]=nodejs [npx]=npm [gpu-screen-recorder]=gpu-screen-recorder [wf-recorder]=wf-recorder
  [ydotool]=ydotool [wtype]=wtype
)
for c in hyprctl qs ffmpeg ffprobe jq node npx; do
  if command -v "$c" >/dev/null; then echo "ok   $c"
  else echo "MISS $c"; miss+=("${pkg[$c]}"); fi
done

if command -v gpu-screen-recorder >/dev/null; then echo "ok   gpu-screen-recorder"
elif command -v wf-recorder >/dev/null; then echo "ok   wf-recorder (VFR — normalize.sh обязателен)"
else echo "MISS рекордер"; miss+=(gpu-screen-recorder); fi

for c in ydotool wtype; do
  if command -v "$c" >/dev/null; then echo "ok   $c (opt)"
  else echo "--   $c (opt)"; opt+=("${pkg[$c]}"); fi
done
command -v ydotool >/dev/null && ! pgrep -x ydotoold >/dev/null && echo "     ydotoold не запущен: systemctl --user enable --now ydotool"

if command -v node >/dev/null; then
  v=$(node -p 'process.versions.node.split(".")[0]')
  (( v >= 18 )) || echo "WARN node $v < 18 — Remotion не заведётся"
fi

[[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && echo "WARN не в сессии Hyprland"

(( ${#miss[@]} )) && echo -e "\nобязательно: sudo pacman -S ${miss[*]}  (если пакета нет в репозиториях — искать в AUR)"
(( ${#opt[@]} ))  && echo "опционально:  sudo pacman -S ${opt[*]}"
(( ${#miss[@]} == 0 ))
