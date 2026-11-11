"""dotfiles installer — what the shell needs to know about the components.

`link` writes $XDG_STATE_HOME/dotfiles/components.json: the bar modules and the
music sections (BarLayout.sections: files, yandex, radio) whose components are
off, each with the components that would bring it

  {"off": {"yandex": ["yandex-music"], "ai": ["ollama", "claude-code"]}}

The shell (bar/BarLayout.qml) keeps them off the bars and shows them as not
installed in the Shell Manager (a music section: not offered in the Music
module); a missing file means every module is there.
"""

from __future__ import annotations

import json
from pathlib import Path

from . import components
from .paths import STATE

FILE = STATE / "components.json"


def render(on: set[str], cat: dict) -> str:
    bring: dict[str, list[str]] = {}
    for name, c in cat.items():
        for m in c["modules"]:
            bring.setdefault(m, []).append(name)
    off = {m: names for m, names in bring.items() if not any(n in on for n in names)}
    multiplexer = next((n for n in ("zellij", "tmux") if n in on), "none")
    return json.dumps({"off": off, "multiplexer": multiplexer}, indent=2, ensure_ascii=False) + "\n"


def apply(target: Path = FILE) -> bool:
    """Write the file when it changed; True then."""
    cat = components.load()
    text = render(components.selected(cat=cat), cat)
    if target.is_file() and target.read_text() == text:
        return False
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text)
    return True
