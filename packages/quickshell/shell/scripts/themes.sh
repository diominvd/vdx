#!/usr/bin/env bash
# themes.sh — the dotfiles themes for the Shell Manager.
# Prints one line per theme: "<name> <colour per role in $roles>"
# (from themes/<name>/quickshell/shell/config/Colors.qml), then "---" and the
# active theme (.theme, gruvbox when absent).
set -u
cd "$HOME/.dotfiles" || exit 1
roles=(background0 background1 background2 background3 foreground0 foreground1 foreground2 red orange yellow green aqua blue purple gray muted frame dim)
color_re='property[[:space:]]+color[[:space:]]+([[:alnum:]_]+)[[:space:]]*:[[:space:]]*"(#[[:xdigit:]]{6})"'
for dir in themes/*/; do
  name=${dir%/}
  name=${name##*/}
  file="$dir/quickshell/shell/config/Colors.qml"
  line=$name
  declare -A colors=()
  if [[ -r $file ]]; then
    while IFS= read -r row || [[ -n $row ]]; do
      if [[ $row =~ $color_re ]]; then
        role=${BASH_REMATCH[1]}
        if [[ " ${roles[*]} " == *" $role "* && -z ${colors[$role]+present} ]]; then
          colors[$role]=${BASH_REMATCH[2]}
        fi
      fi
    done < "$file"
  fi
  for role in "${roles[@]}"; do
    hex=${colors[$role]:-#000000}
    line+=" ${hex:-#000000}"
  done
  printf '%s\n' "$line"
  unset colors
done
printf '%s\n' ---
if [[ -r .theme ]]; then
  while IFS= read -r active || [[ -n $active ]]; do
    printf '%s\n' "$active"
  done < .theme
else
  printf '%s\n' gruvbox
fi
