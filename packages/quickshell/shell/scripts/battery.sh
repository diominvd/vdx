#!/usr/bin/env bash
#
# battery.sh — battery, power profile and GPU mode backend for modules/battery.
#
#   --status          {present, capacity, status, plugged, energy, energyFull, energyDesign,
#                      power, voltage, cycles, threshold, limit, profile, profiles}   Wh / W / V / %;
#                      limit: the kernel takes a charge limit
#   --threshold N     {ok, error}   charge limit, %
#   --profile NAME    {ok, error}   platform profile
#   --gpu             {mode, pending, action}
#   --gpu-mode MODE   {ok, error}   supergfxctl mode, applied after logout / reboot
#
# Writing the limit and the profile needs system/etc/tmpfiles.d/quickshell-power.conf
# (the limit) and system/etc/udev/rules.d/90-quickshell-power.rules (the profile).

PROFILE=/sys/firmware/acpi/platform_profile

ok()    { echo '{"ok":true}'; }
error() { jq -cn --arg e "$1" '{ok:false, error:$e}'; }

# Main battery: type Battery, not a peripheral (scope Device).
battery() {
    local d
    for d in /sys/class/power_supply/*; do
        [[ "$(cat "$d/type" 2>/dev/null)" == Battery ]] || continue
        [[ "$(cat "$d/scope" 2>/dev/null)" == Device ]] && continue
        echo "$d"
        return
    done
}

plugged() {
    local d
    for d in /sys/class/power_supply/*; do
        [[ "$(cat "$d/online" 2>/dev/null)" == 1 ]] && { echo true; return; }
    done
    echo false
}

cmd_status() {
    local b cycles
    b=$(battery)
    [[ -z "$b" ]] && { echo '{"present":false}'; return; }
    num() { local v; v=$(cat "$b/$1" 2>/dev/null); echo "${v:-0}"; }
    # µWh; a battery that counts charge (µAh) instead is converted with its voltage
    uwh() { local v; v=$(num "energy_$1"); (( v )) || v=$(( $(num "charge_$1") * $(num voltage_now) / 1000000 )); echo "$v"; }
    local watts; watts=$(num power_now)
    (( watts )) || watts=$(( $(num current_now) * $(num voltage_now) / 1000000 ))
    watts=${watts#-}
    cycles=$(cat "$b/cycle_count" 2>/dev/null)
    cycles=${cycles:-null}
    jq -cn \
        --arg status "$(cat "$b/status" 2>/dev/null)" \
        --argjson capacity "$(num capacity)" \
        --argjson plugged "$(plugged)" \
        --argjson energy "$(uwh now)" \
        --argjson energyFull "$(uwh full)" \
        --argjson energyDesign "$(uwh full_design)" \
        --argjson power "$watts" \
        --argjson voltage "$(num voltage_now)" \
        --argjson cycles "$cycles" \
        --argjson threshold "$(cat "$b/charge_control_end_threshold" 2>/dev/null || echo 100)" \
        --argjson limit "$([[ -e "$b/charge_control_end_threshold" ]] && echo true || echo false)" \
        --arg profile "$(cat "$PROFILE" 2>/dev/null)" \
        --arg profiles "$(cat "$PROFILE"_choices 2>/dev/null)" \
        '{present: true, status: $status, capacity: $capacity, plugged: $plugged,
          energy: ($energy / 1e6), energyFull: ($energyFull / 1e6), energyDesign: ($energyDesign / 1e6),
          power: ($power / 1e6), voltage: ($voltage / 1e6), cycles: $cycles, threshold: $threshold, limit: $limit,
          profile: $profile, profiles: ($profiles | split(" ") | map(select(. != "")))}'
}

write() {
    if { printf '%s' "$2" > "$1"; } 2>/dev/null; then ok
    else error "permission denied: run ./install.py system install (quickshell-power)"; fi
}

cmd_gpu() {
    command -v supergfxctl >/dev/null || { echo '{"mode":"","pending":"","action":""}'; return; }
    jq -cn --arg mode "$(supergfxctl -g 2>/dev/null)" \
           --arg pending "$(supergfxctl -P 2>/dev/null)" \
           --arg action "$(supergfxctl -p 2>/dev/null)" \
        '{mode:$mode, pending:$pending, action:$action}'
}

cmd_gpu_mode() {
    local out
    out=$(supergfxctl -m "$1" 2>&1) && ok || error "${out%%$'\n'*}"
}

case "${1:-}" in
    --status)    cmd_status ;;
    --threshold) [[ "${2:-}" =~ ^[0-9]+$ ]] && write "$(battery)/charge_control_end_threshold" "$2" || error "bad limit" ;;
    --profile)   write "$PROFILE" "${2:-}" ;;
    --gpu)       cmd_gpu ;;
    --gpu-mode)  cmd_gpu_mode "${2:-}" ;;
    *)           error "unknown command: ${1:-}" ;;
esac
