#!/usr/bin/env python3
"""Terminal launcher preference; queried only while its settings page is open."""
import json
import os
from pathlib import Path
import shutil
import sys

from backend import fail, out

STATE = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "dotfiles"
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
OPTIONS = {"none", "tmux", "zellij"}


def read_choice(path, fallback):
    try:
        value = json.loads(path.read_text()).get("multiplexer")
        return value if value in OPTIONS else fallback
    except (OSError, ValueError, AttributeError):
        return fallback


def status():
    default = read_choice(STATE / "components.json", "none")
    selected = read_choice(STATE / "terminal.json", default)
    available = {"none": True, "tmux": bool(shutil.which("tmux") and (CONFIG / "tmux/tmux.conf").is_file()),
                 "zellij": bool(shutil.which("zellij") and (CONFIG / "zellij/session.py").is_file())}
    return {"ok": True, "selected": selected, "default": default, "available": available}


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
        elif sys.argv[1:] == ["reset"]:
            (STATE / "terminal.json").unlink(missing_ok=True)
            out(status())
        else:
            fail("Usage: terminal.py status | set none|tmux|zellij | reset")
    except (OSError, ValueError) as error:
        fail(str(error))


if __name__ == "__main__":
    main()
