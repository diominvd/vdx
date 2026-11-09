#!/usr/bin/env python3
"""Desktop notices for coding agents (Codex, Claude Code): a command waits for
approval, or a task is done.

    agent_notify.py <codex|claude>-<permission|complete> [json]

The agent's hook payload comes as the last argument or on stdin. The notice
names the project (the payload's cwd) so several sessions can be told apart,
and says what is asked (the permission message) or what was answered (the
last message, one line).
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

APPS = {"codex": "Codex", "claude": "Claude Code"}
TEXT_LIMIT = 140


def payload(argv: list[str]) -> dict:
    for value in reversed(argv[2:]):
        try:
            parsed = json.loads(value)
        except (json.JSONDecodeError, TypeError):
            continue
        if isinstance(parsed, dict):
            return parsed
    if sys.stdin is None or sys.stdin.isatty():
        return {}
    try:
        parsed = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError, ValueError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def one_line(value: object, limit: int = TEXT_LIMIT) -> str:
    """The first non-empty line of a text, cut to `limit` characters."""
    if not isinstance(value, str):
        return ""
    for line in value.splitlines():
        line = " ".join(line.split()).lstrip("#*-> `").strip()
        if line:
            return line if len(line) <= limit else line[: limit - 1].rstrip() + "…"
    return ""


def project(data: dict) -> str:
    cwd = data.get("cwd")
    return os.path.basename(cwd.rstrip("/")) if isinstance(cwd, str) and cwd.strip("/") else ""


def request(data: dict) -> str:
    """What the agent asks to run: its own message, else the tool and its command."""
    message = one_line(data.get("message"))
    if message:
        return message
    tool = data.get("tool_name")
    tool_input = data.get("tool_input") if isinstance(data.get("tool_input"), dict) else {}
    detail = one_line(tool_input.get("command") or tool_input.get("description") or tool_input.get("file_path"))
    if isinstance(tool, str) and tool:
        return f"{tool}: {detail}" if detail else tool
    return "A command is waiting for your approval"


def compose(event: str, data: dict) -> tuple[str, str, str, str] | None:
    """(app, title, body, urgency) of the notice, or None when there is nothing to say."""
    agent, _, kind = event.partition("-")
    app = APPS.get(agent)
    if app is None:
        return None
    where = project(data)
    suffix = f" · {where}" if where else ""
    if kind == "permission":
        # Claude's Notification hook also fires for idle waits: only a permission prompt is ours
        if agent == "claude" and data.get("notification_type", "permission_prompt") != "permission_prompt":
            return None
        return app, f"{app} needs permission{suffix}", request(data), "critical"
    if kind == "complete":
        if data.get("stop_hook_active"):           # a stop hook's own continuation, not the end
            return None
        body = one_line(data.get("last_assistant_message")) or "The task is complete"
        return app, f"{app} finished{suffix}", body, "normal"
    return None


def main() -> int:
    if len(sys.argv) < 2:
        return 0
    notice = compose(sys.argv[1], payload(sys.argv))
    if notice is None:
        return 0
    app, title, body, urgency = notice
    try:
        subprocess.run(
            ["notify-send", "-a", app, "-u", urgency, "-i", "utilities-terminal", "-t", "8000", title, body],
            check=False, timeout=3, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (OSError, subprocess.TimeoutExpired):
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
