#!/usr/bin/env bash
# supervise.sh — runs the shell (`qs -c shell`) and starts it again when its
# process ends by a crash. Quickshell restarts most crashes in place itself
# (same pid, a crash report window); this covers the rest: the OOM killer's
# KILL, a crash it gives up on. Not a JSON backend: Hyprland's autostart and
# the shell's Restart start it, in the foreground of their own process.
#   supervise.sh     until qs ends on purpose or the session ends
# On purpose: exit 0 (a second instance too: `-n` exits 0 at once) or a kill
# by HUP / INT / TERM (Restart, `qs kill`, logout).
# A config that does not load (exit 255, "Failed to load configuration" in its
# log) is not a crash: starting it again changes nothing. One toast names the
# error (once per error), and qs starts again when a .qml / .js file of the
# shell changes, or after a minute.
# Anything else is a crash (SEGV, ABRT, KILL from the OOM killer, an error
# code): qs starts after a second; the 5th crash within a minute stops it,
# with a critical toast. After either, mako draws toasts again (its island
# mode off: no island is left). Its toasts go once qs has run for a few
# seconds: a critical one stays until dismissed, and would show again at every
# restart (island mode off for a moment) long after the shell was fixed.
# Before each start, settings_migrate.py brings the option files up to date.
set -u

limit=5      # crashes ...
window=60    # ... within this many seconds stop it
poll=2       # seconds between looks for a fixed config
retry=60     # a broken config is tried again after this long anyway
settle=3     # seconds qs runs before its toasts are dismissed
crashes=()
told=""      # the config error last shown, so a retry does not toast it again

here=$(dirname "$(readlink -f "$0")")
config=$(dirname "$here")
runtime=${XDG_RUNTIME_DIR:-/run/user/$UID}
logs=$runtime/quickshell/by-pid
toasts=$runtime/shell-supervise.toasts   # ids of its toasts still shown (across runs)

# a toast of ours, its id kept for clear_toasts
toast() {
  local id
  id=$(notify-send -p -a Shell "$@") && echo "$id" >> "$toasts"
}

clear_toasts() {
  [[ -f $toasts ]] || return 0
  while read -r id; do makoctl dismiss -n "$id" >/dev/null 2>&1; done < "$toasts"
  rm -f "$toasts"
}

# A terminal or a previous shell may still carry the signature from before
# Hyprland restarted. Match the live compositor to this Wayland display before
# Quickshell constructs its Hyprland singleton and opens the event socket.
resolve_hyprland_session() {
  local display=${WAYLAND_DISPLAY:-} lock compositor_pid compositor_display
  [[ -n $display ]] || return 0
  display=${display##*/}
  for lock in "$runtime"/hypr/*/hyprland.lock; do
    [[ -f $lock ]] || continue
    {
      read -r compositor_pid
      read -r compositor_display
    } < "$lock"
    [[ $compositor_pid =~ ^[1-9][0-9]*$ && $compositor_display == "$display" ]] || continue
    kill -0 "$compositor_pid" 2>/dev/null || continue
    local directory=${lock%/hyprland.lock}
    export HYPRLAND_INSTANCE_SIGNATURE=${directory##*/}
    return 0
  done
}

resolve_hyprland_session

# the session is still there (after logout there is nothing to start)
session() {
  local display=${WAYLAND_DISPLAY:-}
  [[ -z $display ]] && return 0
  [[ $display == /* ]] || display=$runtime/$display
  [[ -S $display ]]
}

# waits until a file of the shell is newer than $1 (seconds), or $retry
wait_for_fix() {
  local since=$1 waited=0
  while session && (( waited < retry )); do
    [[ -n $(find -L "$config" \( -name '*.qml' -o -name '*.js' -o -name qmldir \) \
              -newermt "@$since" -print -quit 2>/dev/null) ]] && return
    sleep "$poll"
    (( waited += poll ))
  done
}

while session; do
  # the option files up to the current schema first (a failure starts it anyway)
  python3 "$here/settings_migrate.py" >/dev/null 2>&1
  started=$(date +%s)
  qs -n -c shell &
  pid=$!
  # up for a few seconds: the toasts of earlier crashes and errors go
  { sleep "$settle"; kill -0 "$pid" 2>/dev/null && clear_toasts; } &
  wait "$pid"
  code=$?
  case $code in 0 | 129 | 130 | 143) exit 0 ;; esac
  makoctl mode -r island >/dev/null 2>&1
  log=$logs/$pid/log.log
  if (( code == 255 )) && grep -q "Failed to load configuration" "$log" 2>/dev/null; then
    why=$(grep -o "caused by .*" "$log" | tail -1)
    why=${why#caused by }
    if [[ $why != "$told" ]]; then
      toast "The shell's config has an error" \
        "${why:-see qs log -c shell} · it starts again when a file is fixed"
      told=$why
    fi
    wait_for_fix "$started"
    continue
  fi
  told=""
  now=$(date +%s)
  recent=()
  for t in "${crashes[@]}"; do (( now - t < window )) && recent+=("$t"); done
  crashes=("${recent[@]}" "$now")
  if (( ${#crashes[@]} >= limit )); then
    toast -u critical "The shell keeps crashing" \
      "Stopped after $limit crashes in a minute (last exit $code) · qs log -c shell"
    exit 1
  fi
  sleep 1
done
