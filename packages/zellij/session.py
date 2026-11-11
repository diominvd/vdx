#!/usr/bin/env python3
"""Numbered sessions, Zen preference, and session restoration preference."""
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


def next_number(names):
    return max((int(name) for name in names if name.isascii() and name.isdecimal()), default=0) + 1


def zen_preference():
    state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    return state / "dotfiles/zellij.json"


def zen_enabled():
    try:
        return json.loads(zen_preference().read_text()).get("zen") is True
    except (OSError, ValueError, AttributeError):
        return False


def restore_sessions_enabled():
    state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    try:
        return json.loads((state / "dotfiles/terminal.json").read_text()).get("restoreSessions") is True
    except (OSError, ValueError, AttributeError):
        return False


def discard_exited_default_session(binary):
    result = subprocess.run([binary, "list-sessions", "--no-formatting"],
                            capture_output=True, text=True, timeout=2)
    if result.returncode:
        if "No active zellij sessions" in result.stderr + result.stdout:
            return
        raise ValueError(result.stderr.strip() or "Could not list Zellij sessions")
    for line in result.stdout.splitlines():
        name = line.split(" [Created ", 1)[0]
        if name == "1" and "(EXITED" in line:
            subprocess.run([binary, "delete-session", "1"], capture_output=True,
                           text=True, timeout=2, check=True)
            return


def query(binary, session, action):
    result = subprocess.run([binary, "--session", session, "action", action, "--all", "--json"],
                            capture_output=True, text=True, timeout=2, check=True)
    value = json.loads(result.stdout)
    if not isinstance(value, list) or not all(isinstance(row, dict) for row in value):
        raise ValueError("Invalid Zellij response")
    return value


def apply_zen(binary, session, enabled):
    tabs = query(binary, session, "list-tabs")
    active = next((tab for tab in tabs if tab.get("active") is True), None)
    if active is None:
        return False
    panes = query(binary, session, "list-panes")
    pane = next((pane for pane in panes if pane.get("tab_id") == active.get("tab_id")
                 and pane.get("is_focused") is True and not pane.get("is_plugin")), None)
    if pane is None:
        return False
    # No-UI fullscreen reaches the display origin, unlike ordinary pane zoom.
    current = pane.get("is_fullscreen") is True and pane.get("pane_y") == 0 and pane.get("pane_x") == 0
    if current != enabled:
        subprocess.run([binary, "--session", session, "action", "toggle-no-ui-fullscreen",
                        "--pane-id", "terminal_" + str(pane["id"])],
                       capture_output=True, text=True, timeout=2, check=True)
    return True


def set_zen(binary, enabled):
    target = zen_preference()
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(".tmp")
    temporary.write_text(json.dumps({"zen": enabled}) + "\n")
    temporary.replace(target)
    result = subprocess.run([binary, "list-sessions", "--no-formatting"],
                            capture_output=True, text=True, timeout=2)
    if result.returncode and "No active zellij sessions" not in result.stderr + result.stdout:
        raise ValueError(result.stderr.strip() or "Could not list Zellij sessions")
    failures = []
    for line in result.stdout.splitlines():
        if " [Created " not in line or "(EXITED" in line:
            continue
        name = line.split(" [Created ", 1)[0]
        try:
            apply_zen(binary, name, enabled)
        except (OSError, ValueError, subprocess.SubprocessError):
            failures.append(name)
    if failures:
        raise ValueError("Preference saved; could not update sessions: " + ", ".join(failures))


def schedule_zen(session):
    if zen_enabled():
        subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "zen-apply", session],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)


def initialise_zen(binary, session):
    # Bounded startup work only: attaching creates the client and its focused tab asynchronously.
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        if not zen_enabled():
            return
        try:
            if apply_zen(binary, session, True):
                return
        except (OSError, ValueError, subprocess.SubprocessError):
            pass
        time.sleep(0.1)


def main():
    binary = shutil.which("zellij")
    if not binary:
        raise SystemExit("zellij is not installed")
    if len(sys.argv) == 3 and sys.argv[1] == "zen-set":
        try:
            if sys.argv[2] not in {"on", "off"}:
                raise ValueError("Expected on or off")
            set_zen(binary, sys.argv[2] == "on")
            print(json.dumps({"ok": True, "zen": zen_enabled()}))
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            print(json.dumps({"ok": False, "error": str(error)}))
            raise SystemExit(1) from error
        return
    if len(sys.argv) == 3 and sys.argv[1] == "zen-apply":
        initialise_zen(binary, sys.argv[2])
        return
    if sys.argv[1:] != ["new"]:
        schedule_zen("1")
        restore = restore_sessions_enabled()
        if not restore:
            discard_exited_default_session(binary)
        serialization = "true" if restore else "false"
        os.execv(binary, [binary, "attach", "--create", "1", "options", "--session-serialization", serialization])
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
        schedule_zen(number)


if __name__ == "__main__":
    main()
