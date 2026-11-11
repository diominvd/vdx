#!/usr/bin/env python3
"""Open session 1, or create the next numbered session from inside Zellij."""
import fcntl
import os
from pathlib import Path
import shutil
import subprocess
import sys


def next_number(names):
    return max((int(name) for name in names if name.isascii() and name.isdecimal()), default=0) + 1


def main():
    binary = shutil.which("zellij")
    if not binary:
        raise SystemExit("zellij is not installed")
    if sys.argv[1:] != ["new"]:
        os.execv(binary, [binary, "attach", "--create", "1"])
    source = os.environ.get("ZELLIJ_SESSION_NAME")
    if not source:
        raise SystemExit("Create sessions from inside Zellij")
    state = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "zellij"
    state.mkdir(parents=True, exist_ok=True)
    with (state / "numbering.lock").open("a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        result = subprocess.run([binary, "list-sessions", "--short", "--no-formatting"],
                                capture_output=True, text=True, check=True)
        counter = state / "last-number"
        try:
            previous = counter.read_text().strip()
        except FileNotFoundError:
            previous = "0"
        number = str(next_number([*result.stdout.splitlines(), previous]))
        # Reserve the number before switching: session creation is asynchronous.
        counter.write_text(number + "\n")
        subprocess.run([binary, "--session", source, "action", "switch-session", number], check=True)


if __name__ == "__main__":
    main()
