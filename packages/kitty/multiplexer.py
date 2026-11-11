"""Launch the selected multiplexer once; no background process remains."""
import json
import os
from pathlib import Path
import shutil


def choice():
    state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    for name in ("terminal.json", "components.json"):
        try:
            value = json.loads((state / "dotfiles" / name).read_text()).get("multiplexer")
            if value in {"none", "tmux", "zellij"}:
                return value
        except (OSError, ValueError, AttributeError):
            pass
    # Compatibility with installations predating the saved launcher choice.
    return next((name for name in ("zellij", "tmux") if
                 (Path.home() / ".config" / name).is_dir() and shutil.which(name)), "none")


def main():
    selected = choice()
    if selected == "zellij" and shutil.which("zellij"):
        os.execvp("python3", ["python3", str(Path.home() / ".config/zellij/session.py")])
    if selected == "tmux" and shutil.which("tmux"):
        os.execvp("tmux", ["tmux", "new-session", "-A"])
    os.execvp("zsh", ["zsh", "--login"])


if __name__ == "__main__":
    main()
