#!/usr/bin/env bash
# inspect-shell.sh [config_dir] > promo/inventory.md
# Сырая инвентаризация Quickshell-конфига. Дальше Claude дописывает руками.
set -uo pipefail

if [[ -n ${1:-} ]]; then dir=$1
elif [[ -n ${QS_CONFIG:-} ]]; then dir=${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/$QS_CONFIG
else dir=${XDG_CONFIG_HOME:-$HOME/.config}/quickshell; fi
[[ -d $dir ]] || { echo "нет каталога: $dir" >&2; exit 1; }
dir=$(cd "$dir" && pwd)

qsc() { if [[ -n ${QS_CONFIG:-} ]]; then qs -c "$QS_CONFIG" "$@"; else qs "$@"; fi; }

echo "# Inventory: $dir"
echo; echo "Сгенерировано $(date -Iseconds). Ниже — сырые данные; разделы «Модули», «Палитра», «Приватное» дописать после чтения QML."

echo; echo "## Файлы"; echo '```'
(cd "$dir" && find . -type f \( -name '*.qml' -o -name '*.js' -o -name '*.sh' -o -name '*.md' -o -name 'qmldir' \) \
  -not -path './.git/*' | sort)
echo '```'

echo; echo "## IpcHandler (статически)"
grep -rln --include='*.qml' 'IpcHandler' "$dir" | while read -r f; do
  awk -v f="${f#"$dir"/}" '
    /IpcHandler[[:space:]]*\{/ {inb=1; depth=0}
    inb {
      depth += gsub(/\{/,"{"); depth -= gsub(/\}/,"}")
      if (match($0,/target:[[:space:]]*"[^"]+"/)) { t=substr($0,RSTART,RLENGTH); sub(/target:[[:space:]]*/,"",t); gsub(/"/,"",t) }
      if (match($0,/function[[:space:]]+[A-Za-z_0-9]+[[:space:]]*\([^)]*\)/)) { fn=fn (fn?", ":"") substr($0,RSTART+9,RLENGTH-9) }
      if (depth<=0 && t!="") { printf "- `%s` → %s  (%s)\n", t, (fn?fn:"—"), f; t=""; fn=""; inb=0 }
    }' "$f"
done

echo; echo "## IPC (живой процесс: qs ipc show)"; echo '```'
qsc ipc show 2>&1 | head -80 || echo "quickshell не запущен"
echo '```'

echo; echo "## GlobalShortcut"
grep -rn --include='*.qml' -A6 'GlobalShortcut' "$dir" | grep -E 'name:|appid:' |
  sed -E "s|^$dir/||; s|-[0-9]+-[[:space:]]*| |" | sed 's/^/- /'
echo; echo "Вызов: \`hyprctl dispatch global <appid>:<name>\` (appid по умолчанию: quickshell)"

echo; echo "## Бинды Hyprland → quickshell"
hyprctl binds -j 2>/dev/null | jq -r '.[] | select(.dispatcher=="global" or (.arg|test("qs |quickshell"))) |
  "- \(if .modmask>0 then "mod\(.modmask)+" else "" end)\(.key) → \(.dispatcher) \(.arg)"' 2>/dev/null || echo "hyprctl недоступен"

echo; echo "## Цвета (частота hex в QML)"
grep -rhoE --include='*.qml' --include='*.js' '#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?\b' "$dir" |
  tr 'A-F' 'a-f' | sort | uniq -c | sort -rn | head -16 | awk '{printf "- %s ×%s\n",$2,$1}'

echo; echo "## Документация в конфиге"
find "$dir" -maxdepth 3 -name '*.md' -not -path '*/.git/*' | sed "s|^$dir/|- |"

echo; echo "## Потенциально приватное (проверить в кадре)"
grep -rlE --include='*.qml' 'Networking|Ssid|ssid|nmcli|Notification|Mpris|hostname|Quickshell.env\("USER|Bluetooth|Pipewire|calendar|Weather|clipboard|cliphist' "$dir" |
  while read -r f; do
    hits=$(grep -ohE 'Networking|[Ss]sid|nmcli|Notification|Mpris|hostname|USER|Bluetooth|Pipewire|[Cc]alendar|Weather|clipboard|cliphist' "$f" | sort -u | tr '\n' ' ')
    echo "- ${f#"$dir"/}: $hits"
  done

echo; echo "## Монитор"
hyprctl monitors -j 2>/dev/null | jq -r '.[] | "- \(.name) \(.width)x\(.height)@\(.refreshRate|floor) scale \(.scale)"'

cat <<'EOF'

## Модули (дописать)
| Модуль | Что видно в кадре | Как открыть | Анимация, мс | Приватное |
|---|---|---|---|---|

## Палитра (дописать → theme.ts)
- bg:
- fg:
- accent:
- accent2:
EOF
