#!/usr/bin/env bash
# bluetooth.sh — BlueZ backend for modules/bluetooth/BluetoothService.qml.
# Every command prints one JSON value.
#
#   --devices            {ok, powered, discovering, devices}
#                        devices: [{mac, name, icon, paired, trusted, connected, battery}],
#                        connected first; battery in % or null
#   --power on|off       {ok, error}
#   --scan               {ok, error}     discovery for 8 s; the new devices show in --devices
#   --connect MAC        {ok, error}     a new device is paired and trusted first
#   --disconnect MAC     {ok, error}
#   --trust MAC on|off   {ok, error}     a trusted device connects by itself when it is near
#   --alias [NAME]       {ok, error}     the adapter's name; empty brings the machine's back
#   --discoverable on|off {ok, error}    visible to other devices (the timeout applies)
#   --discoverable-timeout S {ok, error} seconds visible; 0 is forever
#   --pairable on|off    {ok, error}
#   --block MAC on|off   {ok, error}     a blocked device is disconnected and refused
#   --listen             {ok}            one line per signal from BlueZ (gdbus monitor), for the
#                                        service to re-read at once; runs until killed

set -u
export LC_ALL=C

for bin in bluetoothctl gdbus jq; do
  command -v "$bin" >/dev/null || { echo "{\"ok\":false,\"error\":\"$bin is required\"}"; exit 0; }
done

ok()    { echo '{"ok":true}'; }
error() { jq -cn --arg e "$1" '{ok:false, error:$e}'; }

# bluetoothctl's own text, without colour codes (it adds them when stdin is a pipe)
bt()    { bluetoothctl "$@" 2>&1 | sed 's/\x1b\[[0-9;]*[A-Za-z]//g'; }
mac_ok() { [[ ${1:-} =~ ^([0-9A-F]{2}:){5}[0-9A-F]{2}$ ]]; }

# "Key: value" of a bluetoothctl reply: field KEY TEXT
field() { sed -n "s/^[[:space:]]*$1: //p" <<<"$2" | head -n1; }

cmd_devices() {
  local show info mac name powered=false discovering=false discoverable=false pairable=false
  local alias timeout
  show=$(bt show)
  grep -q '^Controller' <<<"$show" || { error "no bluetooth adapter"; return; }
  grep -q 'Powered: yes' <<<"$show" && powered=true
  grep -q 'Discovering: yes' <<<"$show" && discovering=true
  grep -q 'Discoverable: yes' <<<"$show" && discoverable=true
  grep -q 'Pairable: yes' <<<"$show" && pairable=true
  alias=$(field Alias "$show")
  timeout=$(field DiscoverableTimeout "$show" | sed -n 's/.*(\([0-9]*\)).*/\1/p')

  {
    while read -r _ mac name; do
      mac_ok "$mac" || continue
      info=$(bt info "$mac")
      jq -cn --arg mac "$mac" --arg name "$name" \
             --arg icon "$(field Icon "$info")" \
             --arg paired "$(field Paired "$info")" \
             --arg trusted "$(field Trusted "$info")" \
             --arg blocked "$(field Blocked "$info")" \
             --arg connected "$(field Connected "$info")" \
             --arg battery "$(field 'Battery Percentage' "$info" | sed -n 's/.*(\([0-9]*\)).*/\1/p')" \
        '{mac:$mac, name:$name, icon:$icon, paired:($paired == "yes"), trusted:($trusted == "yes"),
          blocked:($blocked == "yes"), connected:($connected == "yes"), battery:(($battery | tonumber?) // null)}'
    done < <(bt devices)
  } | jq -cs --argjson powered "$powered" --argjson discovering "$discovering" \
              --arg alias "$alias" --argjson discoverable "$discoverable" --argjson pairable "$pairable" \
              --argjson timeout "${timeout:-0}" '
    {ok:true, powered:$powered, discovering:$discovering,
     adapter:{alias:$alias, discoverable:$discoverable, timeout:$timeout, pairable:$pairable},
     devices: sort_by([(if .connected then 0 elif .paired then 1 else 2 end), .name])}'
}

cmd_power() {
  case "$1" in on|off) ;; *) error "expected on|off"; return ;; esac
  bt power "$1" | grep -q succeeded && ok || error "could not switch bluetooth"
}

cmd_scan() {
  local out
  out=$(bt --timeout 8 scan on)
  grep -q 'Discovery started' <<<"$out" && ok || error "${out:-could not start bluetooth scan}"
}

# Pairs with an agent that answers without a PIN (most headsets). bluetoothctl
# stays up on a FIFO until the device reports Paired, the pairing fails, or 30 s pass.
pair() {
  local mac=$1 fifo log pid paired=no
  fifo=$(mktemp -u) && mkfifo "$fifo" || return 1
  log=$(mktemp)
  bluetoothctl <"$fifo" >"$log" 2>&1 &
  pid=$!
  exec 3>"$fifo"
  printf 'agent NoInputNoOutput\ndefault-agent\npair %s\n' "$mac" >&3
  for _ in $(seq 30); do
    sleep 1
    grep -q 'Failed to pair' "$log" && break
    [ "$(field Paired "$(bt info "$mac")")" = yes ] && break
  done
  printf 'quit\n' >&3
  exec 3>&-
  wait "$pid" 2>/dev/null
  [ "$(field Paired "$(bt info "$mac")")" = yes ] && paired=yes
  rm -f "$fifo" "$log"
  [ "$paired" = yes ]
}

cmd_connect() {
  local mac=$1 info out
  mac_ok "$mac" || { error "bad address"; return; }
  info=$(bt info "$mac")
  [ "$(field Connected "$info")" = yes ] && { ok; return; }
  if [ "$(field Paired "$info")" != yes ]; then
    pair "$mac" || { error "could not pair"; return; }
  fi
  bt trust "$mac" >/dev/null
  out=$(timeout 25 bluetoothctl connect "$mac" 2>&1 | sed 's/\x1b\[[0-9;]*[A-Za-z]//g')
  if grep -q 'Connection successful' <<<"$out"; then
    ok
  else
    out=$(sed -n 's/.*Failed to connect: //p' <<<"$out" | tail -n1)
    error "${out:-could not connect}"
  fi
}

cmd_disconnect() {
  mac_ok "$1" || { error "bad address"; return; }
  bt disconnect "$1" | grep -q 'successful' && ok || error "could not disconnect"
}

cmd_trust() {
  mac_ok "$1" || { error "bad address"; return; }
  case "$2" in
    on)  bt trust "$1" | grep -q succeeded ;;
    off) bt untrust "$1" | grep -q succeeded ;;
    *)   error "expected on|off"; return ;;
  esac && ok || error "could not change trust"
}

# The adapter's name; an empty one brings back the machine's own.
cmd_alias() {
  if [ -n "${1:-}" ]; then
    bluetoothctl system-alias "$1" >/dev/null 2>&1
  else
    bluetoothctl reset-alias >/dev/null 2>&1
  fi && ok || error "could not rename the adapter"
}

# A bluetoothctl switch: discoverable | pairable on|off.
cmd_switch() {
  case "${2:-}" in on|off) ;; *) error "expected on|off"; return ;; esac
  bluetoothctl "$1" "$2" >/dev/null 2>&1 && ok || error "could not change $3"
}

cmd_discoverable_timeout() {
  [[ ${1:-} =~ ^[0-9]+$ ]] || { error "expected seconds"; return; }
  bluetoothctl discoverable-timeout "$1" >/dev/null 2>&1 && ok || error "could not set the timeout"
}

# A blocked device is disconnected and cannot connect until unblocked.
cmd_block() {
  mac_ok "${1:-}" || { error "bad address"; return; }
  case "${2:-}" in
    on)  bluetoothctl block "$1" >/dev/null 2>&1 ;;
    off) bluetoothctl unblock "$1" >/dev/null 2>&1 ;;
    *)   error "expected on|off"; return ;;
  esac && ok || error "could not change the block"
}

case "${1:-}" in
  --devices)    cmd_devices ;;
  --power)      cmd_power "${2:-}" ;;
  --scan)       cmd_scan ;;
  --connect)    cmd_connect "${2:-}" ;;
  --disconnect) cmd_disconnect "${2:-}" ;;
  --trust)      cmd_trust "${2:-}" "${3:-}" ;;
  --alias)      cmd_alias "${2:-}" ;;
  --discoverable)         cmd_switch discoverable "${2:-}" visibility ;;
  --discoverable-timeout) cmd_discoverable_timeout "${2:-}" ;;
  --pairable)             cmd_switch pairable "${2:-}" pairing ;;
  --block)                cmd_block "${2:-}" "${3:-}" ;;
  --listen)     . "${BASH_SOURCE[0]%/*}/listen.sh"; listen_to gdbus monitor --system --dest org.bluez ;;
  *)            error "unknown command: ${1:-}" ;;
esac
