#!/usr/bin/env bash
#
# mihomo.sh — mihomo backend for modules/mihomo.
#
#   --status          {service, mode, group, node, provider, delay}
#   --providers       [{name, nodes}]
#   --nodes P         [{name, alive, delay}]
#   --select NODE     switch the policy group to NODE
#   --ping P          {ok, alive | error}   health-check P's servers
#   --update          {ok | error}          re-download subscriptions, reload
#   --traffic         {up, down} once a second (controller stream)
#   --config-path     path of config.yaml
#   --path P          path of P's provider file (config.yaml if unknown)
#   --toggle          start / stop mihomo.service
#
# Thin layer between the bar module and the two things it talks to:
#   * the subscription manager (manager.py under packages/scripts/vpn/),
#     which owns subscriptions.json, downloads every subscription and renders
#     config.yaml from config.template.yaml. It is the ONLY writer of
#     config.yaml.
#   * mihomo's REST API — status, node switching, health checks, reload.
#
# config.yaml is a rendered artefact. To add, remove or change a provider,
# edit subscriptions.json and let the renderer rebuild proxy-providers + the
# group `use:` list.

set -euo pipefail

API="${MIHOMO_API:-http://127.0.0.1:9090}"
SERVICE="${MIHOMO_SERVICE:-mihomo.service}"
GROUP="${MIHOMO_GROUP:-Proxies}"
TIMEOUT="${MIHOMO_TIMEOUT:-3}"
MIHOMO_DIR="${MIHOMO_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mihomo}"

error()      { jq -cn --arg e "$1" '{ok:false, error:$e}'; }
service_on() { systemctl --user is-active --quiet "$SERVICE"; }

# The subscription manager (packages/scripts/vpn), run with `uv` so its
# inline `requests` dependency resolves on the fly.
VPN_MANAGER="${VPN_MANAGER:-$HOME/.config/scripts/vpn/manager.py}"

# Single entry point. Everything that needs the manager goes through here.
vpn() {
    uv run --quiet "$VPN_MANAGER" "$@"
}

vpn_available() {
    [[ -f "$VPN_MANAGER" ]] && command -v uv >/dev/null 2>&1
}

# curl that never trips `set -e` (the controller may legitimately be down).
api() { curl -sf --max-time "$TIMEOUT" "$API$1" 2>/dev/null || true; }

# The policy group the rules actually use. Prefer $GROUP; otherwise fall back to
# the first non-GLOBAL Selector / URLTest / Fallback / LoadBalance group.
group_name() {
    local g
    g="$(api "/proxies/$GROUP" | jq -r '.type // ""' 2>/dev/null || true)"
    if [[ -n "$g" ]]; then
        printf '%s\n' "$GROUP"
        return 0
    fi
    api /proxies | jq -r '
        .proxies | to_entries[]
        | select(.value.type | test("^(Selector|URLTest|Fallback|LoadBalance)$"))
        | select(.key != "GLOBAL")
        | .key
    ' 2>/dev/null | head -n1 || true
}

cmd_status() {
    local svc="off" mode="rule" group node provider delay="0" proxies
    if service_on; then svc="on"; fi
    mode="$(api /configs | jq -r '.mode // "rule"' 2>/dev/null || true)"
    group="$(group_name)"
    if [[ -n "$group" ]]; then
        node="$(api "/proxies/$group" | jq -r '.now // ""' 2>/dev/null || true)"
    fi
    # A server of a provider is not in /proxies: its name, ping history and the
    # provider that owns it come from /providers/proxies (one call, no URL-encoding).
    if [[ -n "$node" ]]; then
        proxies="$(api /providers/proxies)"
        provider="$(printf '%s' "$proxies" | jq -r --arg n "$node" '
            .providers | to_entries[] | select(any(.value.proxies[]?; .name == $n)) | .key' 2>/dev/null | head -n1 || true)"
        delay="$(printf '%s' "$proxies" | jq -r --arg n "$node" '
            [.providers[].proxies[]? | select(.name == $n) | ((.history // []) | last | .delay) // 0] | first // 0' 2>/dev/null || true)"
        if [[ -z "$provider" ]]; then   # a built-in or a group: /proxies has it
            delay="$(api /proxies | jq -r --arg n "$node" '((.proxies[$n].history // []) | last | .delay) // 0' 2>/dev/null || true)"
        fi
    fi
    [[ -z "$delay" || ! "$delay" =~ ^[0-9]+$ ]] && delay=0
    jq -nc --arg s "$svc" --arg m "${mode:-rule}" --arg g "${group:-}" \
           --arg n "${node:-}" --arg p "${provider:-}" --argjson d "$delay" \
        '{service:$s, mode:$m, group:$g, node:$n, provider:$p, delay:$d}'
}

cmd_providers() {
    api /providers/proxies | jq -c '
        [ .providers | to_entries[]
          | select(.key != "default")
          | select(.value.vehicleType != "Compatible")
          | select((.value.proxies // []) | length > 0)
          | { name: .key, nodes: ((.value.proxies // []) | length) } ]
    ' 2>/dev/null || true
}

cmd_nodes() {
    local provider="${1:-}"
    [[ -z "$provider" ]] && { printf '[]\n'; return 0; }
    api "/providers/proxies/$provider" | jq -c '
        [ (.proxies // [])[]
          | { name: .name,
              alive: (.alive // false),
              delay: (((.history // []) | last | .delay) // 0) } ]
    ' 2>/dev/null || true
}

cmd_select() {
    local node="${1:-}" group
    [[ -z "$node" ]] && return 0
    group="$(group_name)"
    [[ -z "$group" ]] && return 0
    curl -sf --max-time "$TIMEOUT" -X PUT "$API/proxies/$group" \
        -H 'Content-Type: application/json' \
        -d "$(jq -nc --arg n "$node" '{name:$n}')" >/dev/null 2>&1 || true
}

cmd_ping() {
    local provider="${1:-}" code alive
    if [[ -z "$provider" ]]; then
        printf '{"ok":false,"error":"no provider"}\n'
        return 1
    fi
    # Blocking health-check; the provider detail is re-read afterwards. The
    # endpoint answers 204 with no body, so read the status code explicitly.
    code="$(curl -s -o /dev/null -w '%{http_code}' \
        --max-time "${MIHOMO_PING_TIMEOUT:-20}" \
        "$API/providers/proxies/$provider/healthcheck" 2>/dev/null || true)"
    if [[ "$code" != "204" && "$code" != "200" ]]; then
        printf '{"ok":false,"error":"healthcheck HTTP %s"}\n' "${code:-000}"
        return 1
    fi
    alive="$(api "/providers/proxies/$provider" \
        | jq -r '[ (.proxies // [])[] | select(.alive == true) ] | length' 2>/dev/null || true)"
    if [[ "${alive:-0}" -gt 0 ]]; then
        printf '{"ok":true,"alive":%s}\n' "$alive"
    else
        printf '{"ok":false,"error":"no alive servers"}\n'
        return 1
    fi
}

cmd_traffic() {
    # Stream the controller's per-second traffic. `exec` so the Process can be
    # stopped cleanly (no bash left waiting on curl -> no orphan).
    exec curl -sN "$API/traffic"
}

# Timestamped line in the mihomo directory — only written on a failed update,
# so the folder keeps the most recent failure for diagnosis.
update_log() {
    mkdir -p "$MIHOMO_DIR" 2>/dev/null || true
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" \
        >> "$MIHOMO_DIR/update.log" 2>/dev/null || true
}

# Best-effort config reload. If the controller is down the render still stands
# and takes effect the next time mihomo starts.
reload_config() {
    local cfg="$1"
    curl -sf --max-time "$TIMEOUT" "$API/version" >/dev/null 2>&1 || return 0
    curl -s -o /dev/null --max-time "${MIHOMO_RELOAD_TIMEOUT:-10}" \
        -X PUT "$API/configs?force=true" \
        -H 'Content-Type: application/json' \
        -d "$(jq -nc --arg p "$cfg" '{path:$p}')" 2>/dev/null || true
}

# ---- update ------------------------------------------------------------------
# Re-download every subscription through the manager, then ask mihomo to
# reload config.yaml so it picks up the freshly written provider files and the
# re-rendered proxy-providers block. The manager is the only thing that talks
# to subscription URLs — mihomo uses `type: file` providers and never fetches.
cmd_update() {
    local out rc=0

    if ! vpn_available; then
        update_log "manager not found at $VPN_MANAGER or uv missing"
        printf '{"ok":false,"error":"vpn manager not found"}\n'
        return 1
    fi

    out="$(vpn --update 2>&1)" || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        update_log "vpn --update failed: $out"
        printf '{"ok":false,"error":"vpn --update failed"}\n'
        return 1
    fi

    reload_config "$MIHOMO_DIR/config.yaml"
    printf '{"ok":true}\n'
}

# ---- provider file / config path --------------------------------------------
# The renderer writes absolute paths into config.yaml (see manager.py), so the
# lookup is a straight read of `path:` out of the rendered file.
provider_file() {
    local provider="$1" rel
    rel="$(awk -v p="$provider" '
        $0 ~ "^  " p ":[[:space:]]*$" { inblk = 1; next }
        inblk && /^  [^ ]/ { inblk = 0 }
        inblk && /^[[:space:]]+path:[[:space:]]*/ {
            sub(/^[[:space:]]*path:[[:space:]]*/, "");
            gsub(/"/, "");
            print; exit
        }
    ' "$MIHOMO_DIR/config.yaml" 2>/dev/null || true)"
    if [[ -z "$rel" ]]; then
        rel="$MIHOMO_DIR/providers/$provider.yaml"
    fi
    if [[ "$rel" != /* ]]; then
        printf '%s\n' "$MIHOMO_DIR/${rel#./}"
    else
        printf '%s\n' "$rel"
    fi
}

cmd_config_path() {
    printf '%s\n' "$MIHOMO_DIR/config.yaml"
}

cmd_path() {
    local provider="${1:-}" file
    [[ -z "$provider" ]] && { printf '\n'; return 0; }
    file="$(provider_file "$provider")"
    if [[ -f "$file" ]]; then
        printf '%s\n' "$file"
    else
        printf '%s\n' "$MIHOMO_DIR/config.yaml"
    fi
}

main() {
    case "${1:-}" in
        --status)    cmd_status ;;
        --providers) cmd_providers ;;
        --nodes)     cmd_nodes "${2:-}" ;;
        --select)    cmd_select "${2:-}" ;;
        --ping)      cmd_ping "${2:-}" ;;
        --update)    cmd_update ;;
        --traffic)   cmd_traffic ;;
        --config-path) cmd_config_path ;;
        --path)      cmd_path "${2:-}" ;;
        --toggle)
            if service_on; then systemctl --user stop "$SERVICE"
            else systemctl --user start "$SERVICE"; fi
            ;;
        *)           error "unknown command: ${1:-}" ;;
    esac
}

main "$@"
