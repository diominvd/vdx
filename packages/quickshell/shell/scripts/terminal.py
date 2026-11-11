#!/usr/bin/env python3
"""Terminal preferences; queried only while their settings page is open."""
import json
import os
from pathlib import Path
import shutil
import sys

from backend import fail, out, run

STATE = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "dotfiles"
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
OPTIONS = {"none", "tmux", "zellij"}


def read_choice(path, fallback):
    try:
        value = json.loads(path.read_text()).get("multiplexer")
        return value if isinstance(value, str) and value in OPTIONS else fallback
    except (OSError, ValueError, AttributeError):
        return fallback


def padding_values():
    try:
        words = (CONFIG / "kitty/padding.conf").read_text().split()
        if len(words) == 5 and words[0] == "window_padding_width":
            top, right, bottom, left = map(int, words[1:])
            if top == bottom and right == left and all(0 <= n <= 40 for n in (top, right)):
                return {"horizontal": right, "vertical": top}
    except (OSError, ValueError):
        pass
    return {"horizontal": 6, "vertical": 6}


def set_padding(axis, value):
    if axis not in {"horizontal", "vertical"}:
        raise ValueError("Unknown padding axis")
    value = int(value)
    if not 0 <= value <= 40:
        raise ValueError("Padding must be between 0 and 40 pt")
    values = padding_values()
    values[axis] = value
    target = CONFIG / "kitty/padding.conf"
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(".tmp")
    temporary.write_text("window_padding_width {vertical} {horizontal} {vertical} {horizontal}\n".format(**values))
    temporary.replace(target)
    return status()


def zen_enabled(multiplexer="zellij"):
    if multiplexer == "tmux":
        try:
            return "set -g @vdx-zen on" in (CONFIG / "tmux/zen.conf").read_text().splitlines()
        except OSError:
            return False
    try:
        return json.loads((STATE / "zellij.json").read_text()).get("zen") is True
    except (OSError, ValueError, AttributeError):
        return False


def set_tmux_zen(value):
    enabled = value == "on"
    target = CONFIG / "tmux/zen.conf"
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(".tmp")
    temporary.write_text("# Zen preference written by Shell Manager.\n"
                         f"set -g @vdx-zen {value}\n"
                         f"set -g status {'off' if enabled else 'on'}\n"
                         f"set -gw pane-border-status {'off' if enabled else 'top'}\n")
    temporary.replace(target)
    result = run(["tmux", "list-windows", "-a", "-F", "#{session_id}\t#{window_id}\t#{window_zoomed_flag}"])
    if result is None:
        raise ValueError("Could not start tmux")
    if result.returncode:
        if "no server running" in result.stderr or "No such file or directory" in result.stderr:
            return status()
        raise ValueError(result.stderr.strip() or "Could not list tmux windows")
    commands = [["source-file", str(target)]]
    sessions, windows = set(), set()
    for line in result.stdout.splitlines():
        session, window, zoomed = line.split("\t")
        if session not in sessions:
            sessions.add(session)
            commands.extend([["set-option", "-t", session, "@vdx-zen", value],
                             ["set-option", "-t", session, "status", "off" if enabled else "on"]])
        if window in windows:
            continue
        windows.add(window)
        commands.append(["set-window-option", "-t", window, "pane-border-status", "off" if enabled else "top"])
        if (zoomed == "1") != enabled:
            commands.append(["resize-pane", "-Z", "-t", window])
    for command in commands:
        reply = run(["tmux", *command])
        if reply is None or reply.returncode:
            info = status()
            info.update(ok=False, error="Preference saved; " + (reply.stderr.strip() if reply else "could not start tmux"))
            return info
    return status()


def set_zen(value, multiplexer=None):
    if value not in {"on", "off"}:
        raise ValueError("Expected on or off")
    multiplexer = multiplexer or status()["selected"]
    if multiplexer == "tmux":
        return set_tmux_zen(value)
    if multiplexer != "zellij":
        raise ValueError("Select tmux or Zellij first")
    result = run(["python3", str(CONFIG / "zellij/session.py"), "zen-set", value], timeout=15)
    if result is None:
        raise ValueError("Could not start the Zellij settings command")
    try:
        reply = json.loads(result.stdout)
    except ValueError as error:
        raise ValueError(result.stderr.strip() or "Invalid Zellij settings reply") from error
    if not isinstance(reply, dict) or not reply.get("ok") or result.returncode:
        info = status()
        info.update(ok=False, error=reply.get("error", "Could not change Zen mode") if isinstance(reply, dict)
                    else "Invalid Zellij settings reply")
        return info
    return status()


def status():
    default = read_choice(STATE / "components.json", "none")
    selected = read_choice(STATE / "terminal.json", default)
    available = {"none": True, "tmux": bool(shutil.which("tmux") and (CONFIG / "tmux/tmux.conf").is_file()),
                 "zellij": bool(shutil.which("zellij") and (CONFIG / "zellij/session.py").is_file())}
    zen = {name: zen_enabled(name) for name in ("tmux", "zellij")}
    return {"ok": True, "selected": selected, "default": default, "available": available, "padding": padding_values(),
            "zen": zen.get(selected, False), "zenAvailable": selected in zen and available[selected],
            "zenChanged": any(zen.values())}


def select(value):
    if value not in OPTIONS:
        raise ValueError("Unknown terminal choice")
    if not status()["available"][value]:
        raise ValueError(f"{value} is not installed or configured: enable it in the dotfiles installer")
    STATE.mkdir(parents=True, exist_ok=True)
    target = STATE / "terminal.json"
    temporary = target.with_suffix(".tmp")
    temporary.write_text(json.dumps({"multiplexer": value}) + "\n")
    temporary.replace(target)
    return status()


def main():
    try:
        if sys.argv[1:] == ["status"]:
            out(status())
        elif len(sys.argv) == 3 and sys.argv[1] == "set":
            out(select(sys.argv[2]))
        elif len(sys.argv) == 4 and sys.argv[1] == "padding":
            out(set_padding(sys.argv[2], sys.argv[3]))
        elif len(sys.argv) == 3 and sys.argv[1] == "zen":
            out(set_zen(sys.argv[2]))
        elif sys.argv[1:] == ["reset"]:
            for multiplexer in ("tmux", "zellij"):
                if zen_enabled(multiplexer):
                    reply = set_zen("off", multiplexer)
                    if not reply["ok"]:
                        out(reply)
            (CONFIG / "kitty/padding.conf").unlink(missing_ok=True)
            (STATE / "terminal.json").unlink(missing_ok=True)
            out(status())
        else:
            fail("Usage: terminal.py status | set none|tmux|zellij | padding horizontal|vertical 0..40 | zen on|off | reset")
    except (OSError, ValueError) as error:
        fail(str(error))


if __name__ == "__main__":
    main()
