#!/usr/bin/env bash
#
# notifications.sh — mako backend for modules/notifications.
#
#   --list    [{id, app, desktop, summary, body, urgency, category}]  shown + history, newest first
#
# New notifications are detected by the service itself (dbus-monitor on the
# Notify method); this script only reads what mako holds.

case "${1:-}" in
    --list)
        { makoctl list -j 2>/dev/null || echo '[]'; makoctl history -j 2>/dev/null || echo '[]'; } |
        jq -cs 'add | map({id, app: (.app_name // ""), desktop: (.desktop_entry // ""),
                           summary: (.summary // ""), body: (.body // ""), urgency: (.urgency // 1),
                           category: (.category // "")})
                    | unique_by(.id) | sort_by(-.id)'
        ;;
    *) jq -cn --arg c "${1:-}" '{ok:false, error:("unknown command: " + $c)}' ;;
esac
