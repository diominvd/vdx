#!/usr/bin/env python3
"""Show local desktop notices for Codex and Claude Code lifecycle events."""

from __future__ import annotations

import json
import subprocess
import sys


def payload(argv: list[str]) -> dict:
    for value in reversed(argv[2:]):
        try:
            parsed = json.loads(value)
            if isinstance(parsed, dict):
                return parsed
        except (json.JSONDecodeError, TypeError):
            continue
    try:
        parsed = json.load(sys.stdin)
        return parsed if isinstance(parsed, dict) else {}
    except (json.JSONDecodeError, OSError):
        return {}


def main() -> int:
    if len(sys.argv) < 2:
        return 0

    event = sys.argv[1]
    data = payload(sys.argv)
    if event == "codex-complete":
        app, title, body, urgency = "Codex", "Codex finished", "The task is complete", "normal"
    elif event == "codex-permission":
        app, title, body, urgency = "Codex", "Codex needs permission", "A command is waiting for your approval", "critical"
    elif event == "claude-permission":
        kind = data.get("notification_type", "")
        if kind != "permission_prompt":
            return 0
        app, title, body, urgency = "Claude Code", "Claude needs permission", "A command is waiting for your approval", "critical"
    elif event == "claude-complete":
        app, title, body, urgency = "Claude Code", "Claude finished", "The task is complete", "normal"
    else:
        return 0

    try:
        subprocess.run(
            ["notify-send", "-a", app, "-u", urgency, "-t", "7000", title, body],
            check=False,
            timeout=3,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.TimeoutExpired):
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
