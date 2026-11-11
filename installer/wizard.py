"""dotfiles installer — `install`: the wizard, screen by screen, then setup.

Welcome (the machine, the checks) → hardware → one screen per group of
components → terminal multiplexer → settings (theme, keyboard) → summary → setup runs in the
terminal. Keys: ↑ ↓ move · space tick / change · → or enter next · ← or esc
back · q twice quit. Nothing is written before the summary is confirmed.

`Picks` is the selection logic (tested without a terminal); the rest draws.
"""

from __future__ import annotations

import contextlib
import curses
import locale
import textwrap
from dataclasses import dataclass, field

from . import components, detect, machine
from .model import active_theme, find_managed, themes
from .paths import THEME_FILE

TOGGLES = [("Caps Lock", "grp:caps_toggle"), ("Alt + Shift", "grp:alt_shift_toggle"),
           ("Win + Space", "grp:win_space_toggle"), ("Ctrl + Shift", "grp:ctrl_shift_toggle"), ("none", "")]
GROUP_TITLES = {
    "hardware": ("Hardware", "Found on this machine; untick what you don't want"),
    "desktop": ("Desktop", "Hyprland and the shell around it"),
    "terminal": ("Terminal", "The terminal, the shell and command-line tools"),
    "editor": ("Editor", "Neovim"),
    "apps": ("Apps", "Programs with a config here"),
    "music": ("Music", "MPD and what plays through it"),
    "network": ("Network", "Proxy and Wi-Fi tools"),
    "ai": ("AI", "Local and hosted models"),
    "personal": ("Personal", "The owner's own things: leave them off unless they are yours"),
}


# --------------------------------------------------------------------------- the selection

class Picks:
    """Ticked components, kept whole: what a ticked one requires is ticked
    and locked; ticking one ticks its suggestions once."""

    def __init__(self, cat: dict, start: set[str]):
        self.cat = cat
        self.on = components.closure(start, cat)

    def locked_by(self, name: str) -> list[str]:
        """Why it can't be unticked: always on, or required by ticked ones."""
        if self.cat[name]["group"] == "core":
            return ["always"]
        return components.required_by(name, self.on, self.cat)

    def toggle(self, name: str) -> str:
        """Tick or untick; a message when it can't."""
        if name in self.on:
            by = self.locked_by(name)
            if by:
                return f"{name} is required by {', '.join(by)}"
            self.on.discard(name)
            return ""
        self.on = components.closure(self.on | {name} | set(self.cat[name]["suggests"]), self.cat)
        return ""

    def multiplexer(self) -> str:
        return next((n for n in ("zellij", "tmux") if n in self.on), "none")

    def select_multiplexer(self, name: str) -> None:
        self.on.difference_update({"tmux", "zellij"})
        if name != "none":
            self.on = components.closure(self.on | {name}, self.cat)

    def packages(self) -> tuple[list[str], list[str]]:
        return components.unique(self.on, self.cat, "pacman"), components.unique(self.on, self.cat, "aur")

    def chosen(self) -> list[str]:
        return [n for n in self.cat if n in self.on and self.cat[n]["group"] != "core"]


@dataclass
class Answers:
    picks: Picks
    theme: str
    layouts: str
    toggle: str
    hw: dict
    profile: dict = field(default_factory=dict)


def start(cat: dict) -> Answers:
    """What the wizard opens with: the saved choices, else the defaults."""
    profile = machine.load() or {}
    hw = profile.get("hardware") or detect.hardware()
    hw = {**hw, **profile.get("override", {})}
    saved = components.saved(profile)
    if saved is not None:
        first = components.selected(profile, cat)      # with what was split off since
    elif find_managed():
        # set up before choices were saved: start from what is on now, not
        # from a stranger's defaults (they'd switch the owner's things off)
        first = components.selected(profile, cat)
    else:
        first = components.defaults(cat, hw)
    picks = Picks(cat, first)
    cfg = profile.get("hypr", {})
    return Answers(picks=picks, theme=active_theme() or "gruvbox", layouts=cfg.get("layouts", "us"),
                   toggle=cfg.get("layout_options", "grp:caps_toggle" if "," in cfg.get("layouts", "us") else ""),
                   hw=hw, profile=profile)


def save(a: Answers) -> None:
    """The profile and the theme: the only writes, after the summary."""
    p = dict(a.profile)
    p["version"] = machine.VERSION
    p.setdefault("hardware", detect.hardware())
    p["components"] = components.record(a.picks.on, a.picks.cat)
    hypr = dict(p.get("hypr", {}))
    hypr["layouts"] = a.layouts
    if a.toggle and "," in a.layouts:
        hypr["layout_options"] = a.toggle
    else:
        hypr.pop("layout_options", None)
    p["hypr"] = hypr
    machine.save(p)
    THEME_FILE.write_text(a.theme + "\n")


# --------------------------------------------------------------------------- keys

QUIT_ASK = "q again to quit: nothing is written"


def key_name(k) -> str:
    """A key from get_wch as the wizard's word for it; Esc is back."""
    if isinstance(k, int):
        return {curses.KEY_UP: "up", curses.KEY_DOWN: "down", curses.KEY_LEFT: "left", curses.KEY_RIGHT: "right",
                curses.KEY_BACKSPACE: "left", curses.KEY_ENTER: "enter", curses.KEY_RESIZE: "resize"}.get(k, "")
    return {"\n": "enter", "\r": "enter", " ": "space", "k": "up", "j": "down", "h": "left", "l": "right",
            "\x7f": "left", "\x1b": "left", "q": "quit"}.get(k, k)


class Quit:
    """q asks once more: only a second q in a row quits (every pick is lost)."""

    def __init__(self):
        self.armed = False

    def press(self, name: str) -> str:
        if name != "quit":
            self.armed = False
            return name
        if self.armed:
            return "quit"
        self.armed = True
        return "ask"


# --------------------------------------------------------------------------- drawing

class UI:
    def __init__(self, scr, answers: Answers, cat: dict):
        self.scr, self.a, self.cat = scr, answers, cat
        curses.curs_set(0)
        curses.use_default_colors()
        for i, c in enumerate((curses.COLOR_GREEN, curses.COLOR_YELLOW, curses.COLOR_CYAN, curses.COLOR_RED), 1):
            curses.init_pair(i, c, -1)
        self.GREEN, self.YELLOW, self.CYAN, self.RED = (curses.color_pair(i) for i in range(1, 5))
        self.message = ""
        self.quit = Quit()

    # ---- frame ----

    def frame(self, step: int, total: int, title: str, subtitle: str, footer: str) -> tuple[int, int]:
        """Clears and draws the header and footer; returns (top row, rows free)."""
        self.scr.erase()
        h, w = self.scr.getmaxyx()
        self.put(0, 2, "dotfiles", curses.A_BOLD)
        self.put(0, 12, f"step {step} of {total}", curses.A_DIM)
        bar = int((w - 4) * step / total)
        self.put(1, 2, "━" * bar, self.CYAN)
        self.put(1, 2 + bar, "━" * (w - 4 - bar), curses.A_DIM)
        self.put(3, 2, title, curses.A_BOLD)
        self.put(4, 2, subtitle, curses.A_DIM)
        if self.message:
            self.put(h - 3, 2, self.message, self.YELLOW)
            self.message = ""
        self.put(h - 2, 2, footer, curses.A_DIM)
        return 6, h - 6 - 3

    def put(self, y: int, x: int, text: str, attr: int = 0) -> None:
        h, w = self.scr.getmaxyx()
        if 0 <= y < h and x < w - 1:
            with contextlib.suppress(curses.error):     # the bottom-right cell can't be written
                self.scr.addnstr(y, x, text, w - 1 - x, attr)

    def key(self) -> str:
        name = self.quit.press(key_name(self.scr.get_wch()))
        if name == "ask":
            self.message = QUIT_ASK
            return ""
        return name

    # ---- pages ----

    def welcome(self, step, total) -> int:
        env = detect.environment()
        from .preflight import environment_problems
        problems = environment_problems()
        while True:
            top, _ = self.frame(step, total, "Welcome", "This installs the dotfiles on this machine, after a summary",
                                "→ next · q quit")
            hw = self.a.hw
            t = detect.traits(hw)
            rows = [("machine", machine.describe(hw)),
                    ("cpu", hw.get("cpu", "?")),
                    ("graphics", " + ".join(t["gpu"]) + (" (hybrid)" if t["hybrid"] else "") or "none found"),
                    ("battery", hw.get("battery") or "none"),
                    ("monitors", ", ".join(m["name"] for m in hw.get("monitors", [])) or "none found"),
                    ("distro", env["distro"]), ("hyprland", env["hyprland"] or "not installed yet"),
                    ("aur helper", env["aur_helper"] or "none yet (built when needed)")]
            for i, (k, v) in enumerate(rows):
                self.put(top + i, 4, f"{k:12s}", curses.A_DIM)
                self.put(top + i, 17, v)
            y = top + len(rows) + 1
            if problems:
                for i, p in enumerate(problems):
                    self.put(y + i, 4, "✗ " + p, self.RED)
                self.put(y + len(problems) + 1, 4, "fix these first: the install would stop on them", self.YELLOW)
            else:
                self.put(y, 4, "✓ ready", self.GREEN)
            if hw.get("dgpu_off"):
                self.put(y + 2, 4, "! a dGPU is switched off (supergfxctl Integrated): not seen until Hybrid", self.YELLOW)
            k = self.key()
            if k in ("right", "enter") and not problems:
                return 1
            if k in ("right", "enter"):
                self.message = "the checks above have to pass first"
            if k == "quit":
                return 0

    def group(self, step, total, group: str) -> int:
        names = [n for n, c in self.cat.items() if c["group"] == group and n not in {"tmux", "zellij"}]
        title, subtitle = GROUP_TITLES.get(group, (group.title(), ""))
        cur = 0
        offset = 0
        while True:
            top, room = self.frame(step, total, title, subtitle,
                                   "↑ ↓ move · space tick · → next · ← back · q quit")
            if cur < offset:
                offset = cur
            if cur >= offset + room // 2:
                offset = cur - room // 2 + 1
            for i, n in enumerate(names[offset:offset + room // 2]):
                y = top + 2 * i
                c = self.cat[n]
                here = offset + i == cur
                on = n in self.a.picks.on
                tick = "[x]" if on else "[ ]"
                self.put(y, 2, "›" if here else " ", self.CYAN)
                self.put(y, 4, tick, self.GREEN if on else curses.A_DIM)
                self.put(y, 8, n, curses.A_BOLD if here else 0)
                notes = []
                if group == "hardware":
                    notes.append("detected" if components.detected(c, self.a.hw) else "not detected")
                if on and (by := self.a.picks.locked_by(n)):
                    notes.append("required by " + ", ".join(by))
                pk = len(c["pacman"]) + len(c["aur"])
                if pk:
                    notes.append(f"{pk} package" + ("s" if pk > 1 else ""))
                self.put(y, 34, " · ".join(notes), curses.A_DIM)
                self.put(y + 1, 8, c["about"], curses.A_DIM if not here else 0)
            k = self.key()
            if k == "up":
                cur = max(0, cur - 1)
            elif k == "down":
                cur = min(len(names) - 1, cur + 1)
            elif k == "space" and names:
                self.message = self.a.picks.toggle(names[cur])
            elif k in ("right", "enter"):
                return 1
            elif k == "left":
                return -1
            elif k == "quit":
                return 0

    def multiplexer(self, step, total) -> int:
        options = [("tmux", "tmux — prefix-based terminal multiplexer"),
                   ("zellij", "Zellij — modes and built-in key hints"),
                   ("none", "Plain shell — no multiplexer")]
        cur = next(i for i, (n, _) in enumerate(options) if n == self.a.picks.multiplexer())
        while True:
            top, _ = self.frame(step, total, "Terminal multiplexer", "Choose what kitty opens",
                                "↑ ↓ move · space select · → next · ← back · q quit")
            for i, (name, label) in enumerate(options):
                self.put(top + i * 2, 2, "›" if i == cur else " ", self.CYAN)
                self.put(top + i * 2, 4, ("(x) " if name == self.a.picks.multiplexer() else "( ) ") + label)
            k = self.key()
            if k == "up":
                cur = max(0, cur - 1)
            elif k == "down":
                cur = min(len(options) - 1, cur + 1)
            elif k == "space":
                self.a.picks.select_multiplexer(options[cur][0])
            elif k in ("right", "enter"):
                self.a.picks.select_multiplexer(options[cur][0])
                return 1
            elif k == "left":
                return -1
            elif k == "quit":
                return 0

    def edit(self, y: int, x: int, text: str) -> str:
        """A one-line field: enter keeps, escape drops."""
        curses.curs_set(1)
        value = text
        while True:
            self.put(y, x, " " * 40)
            self.put(y, x, value, curses.A_UNDERLINE)
            self.scr.move(y, min(x + len(value), self.scr.getmaxyx()[1] - 2))
            k = self.scr.get_wch()
            if k in ("\n", "\r", curses.KEY_ENTER):
                curses.curs_set(0)
                return value.strip() or text
            if k == "\x1b":
                curses.curs_set(0)
                return text
            if k in (curses.KEY_BACKSPACE, "\x7f", "\b"):
                value = value[:-1]
            elif isinstance(k, str) and k.isprintable() and len(value) < 40:
                value += k

    def settings(self, step, total) -> int:
        names = themes()
        cur = 0
        while True:
            top, _ = self.frame(step, total, "Settings", "Everything here can be changed later",
                                "↑ ↓ move · space change · → next · ← back · q quit")
            toggle_label = next((label for label, v in TOGGLES if v == self.a.toggle), self.a.toggle or "none")
            rows = [("Theme", self.a.theme, "one colour theme for the whole desktop"),
                    ("Keyboard layouts", self.a.layouts, "comma-separated: us,ru · space to edit"),
                    ("Switch layouts", toggle_label if "," in self.a.layouts else "—", "the key combination")]
            for i, (label, val, hint) in enumerate(rows):
                y = top + 2 * i
                self.put(y, 2, "›" if i == cur else " ", self.CYAN)
                self.put(y, 4, label, curses.A_BOLD if i == cur else 0)
                self.put(y, 24, val, self.GREEN)
                self.put(y + 1, 4, hint, curses.A_DIM)
            mons = self.a.hw.get("monitors", [])
            tuned = self.a.profile.get("hypr", {}).get("monitors")
            self.put(top + 7, 4, "Monitors: " + (", ".join(f"{m['name']} {m['mode']}" for m in mons) or "none found")
                     + (" · as set in .machine.toml [hypr]" if tuned else " · each at its preferred mode; tune them in .machine.toml [hypr]"),
                     curses.A_DIM)
            k = self.key()
            if k == "up":
                cur = max(0, cur - 1)
            elif k == "down":
                cur = min(len(rows) - 1, cur + 1)
            elif k == "space":
                if cur == 0 and names:
                    self.a.theme = names[(names.index(self.a.theme) + 1) % len(names)] if self.a.theme in names else names[0]
                elif cur == 1:
                    self.a.layouts = self.edit(top + 2, 24, self.a.layouts).replace(" ", "")
                elif cur == 2 and "," in self.a.layouts:
                    values = [v for _, v in TOGGLES]
                    self.a.toggle = values[(values.index(self.a.toggle) + 1) % len(values)] if self.a.toggle in values else values[0]
            elif k in ("right", "enter"):
                return 1
            elif k == "left":
                return -1
            elif k == "quit":
                return 0

    def summary(self, step, total) -> int:
        while True:
            top, room = self.frame(step, total, "Summary", "Nothing is written until you press enter",
                                   "enter install · ← back · q quit")
            picks = self.a.picks
            repo, aur = picks.packages()
            chosen = picks.chosen()
            lines = [(f"{len(chosen)} components", ", ".join(chosen)),
                     (f"{len(repo)} pacman packages", "installed ones are skipped"),
                     (f"{len(aur)} AUR packages", "built with yay (built itself when missing)"),
                     ("/etc files", str(len(components.unique(picks.on, self.cat, "system"))) + " (shown as a diff when they differ)"),
                     ("theme", self.a.theme),
                     ("keyboard", self.a.layouts + (f" · {self.a.toggle}" if self.a.toggle and "," in self.a.layouts else ""))]
            y = top
            for label, text in lines:
                self.put(y, 4, label, curses.A_BOLD)
                y += 1
                for part in textwrap.wrap(text, self.scr.getmaxyx()[1] - 10)[:max(0, top + room - y)]:
                    self.put(y, 6, part, curses.A_DIM)
                    y += 1
            hints = [n for n in picks.on if self.cat[n].get("hint")]
            if hints:
                self.put(y + 1, 4, f"by hand afterwards: {', '.join(hints)} (listed at the end)", self.YELLOW)
            self.put(y + 3, 4, "Then: preflight, the plan, each step; sudo is asked for in the terminal.", curses.A_DIM)
            k = self.key()
            if k == "enter":
                return 1
            if k == "left":
                return -1
            if k == "quit":
                return 0

    def run(self) -> bool:
        groups = [g for g in components.GROUPS if g != "core" and any(c["group"] == g for c in self.cat.values())]
        pages = ([self.welcome] + [lambda s, t, g=g: self.group(s, t, g) for g in ["hardware"] + [g for g in groups if g != "hardware"]]
                 + [self.multiplexer, self.settings, self.summary])
        i = 0
        while 0 <= i < len(pages):
            h, w = self.scr.getmaxyx()
            if h < 20 or w < 72:
                self.scr.erase()
                self.put(0, 0, f"the window is {w}×{h}: make it at least 72×20 (q twice quits)")
                if self.key() == "quit":
                    return False
                continue
            move = pages[i](i + 1, len(pages))
            if move == 0:
                return False
            i = max(0, i + move)
        return i >= len(pages)


def cmd_install(args) -> int:
    """The wizard; on confirm saves the choices and runs setup."""
    import sys

    from .setup import cmd_setup
    from .ui import err, note
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        err("the wizard needs a terminal — without one: ./install.py components, then setup")
        return 2
    locale.setlocale(locale.LC_ALL, "")         # curses draws ━ › ✓ only in a UTF-8 locale
    cat = components.load()
    answers = start(cat)
    if not curses.wrapper(lambda scr: UI(scr, answers, cat).run()):
        note("nothing changed")
        return 1
    save(answers)
    args.yes = True
    args.dry_run = False
    return cmd_setup(args)
