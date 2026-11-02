#!/usr/bin/env python3
"""The shell's option files brought up to the current schema before it starts
(supervise.sh). One JSON object on stdout.

    settings_migrate.py [<state dir>]     {"ok", "changed": [file, ...]}

The state dir is Quickshell's for this shell (by-shell/<md5 of shell.qml's
path>) unless given. Each of settings.json, modules.json and layout.json
carries "version"; a file below VERSION goes through MIGRATIONS[n] for every
n from its version up, then gets the new version. A file is written only when
it changed: atomically, the old one kept as <file>.bak. A file that is missing,
not JSON or not an object is left alone (the shell writes its defaults).
QML keeps reading the old shapes too (a live reload runs without this)."""
import hashlib, json, os, sys
from pathlib import Path

VERSION = 11
FILES = ("settings.json", "modules.json", "layout.json")
RENAMED = {"claude": "ai", "plugins": "shell", "player": "music", "yandex": "music", "radio": "music"}   # module ids that changed (BarLayout.renamed)


def state_dir() -> Path:
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    shell = str(config / "quickshell/shell/shell.qml")
    return state / "quickshell/by-shell" / hashlib.md5(shell.encode()).hexdigest()


def _ids(ids):
    """A list of module ids with the renamed ones replaced, order kept, no repeats."""
    out = []
    for i in ids if isinstance(ids, list) else []:
        i = RENAMED.get(i, i)
        if i not in out:
            out.append(i)
    return out


def _layout_entry(e: dict) -> None:
    """One saved layout (the top level or a role): ids renamed everywhere."""
    if isinstance(e.get("zones"), dict):
        e["zones"] = {z: _ids(v) for z, v in e["zones"].items()}
    for key in ("hidden", "folder"):
        if isinstance(e.get(key), list):
            e[key] = _ids(e[key])
    if isinstance(e.get("island"), dict):
        e["island"] = {z: _ids(v) for z, v in e["island"].items()}
    if isinstance(e.get("bars"), list):
        for b in e["bars"]:
            if isinstance(b, dict) and isinstance(b.get("modules"), list):
                b["modules"] = _ids(b["modules"])


def to_1(name: str, data: dict) -> None:
    """Version 1: the fixes the pages and BarLayout did inline until now."""
    if name == "modules.json":
        values = data.get("values")
        if isinstance(values, dict):
            # a title length of 0 once meant "icon only" (MusicSettings / RadioSettings)
            for mod in ("music", "radio"):
                m = values.get(mod)
                if isinstance(m, dict) and m.get("titleLength") == 0:
                    m["show"], m["titleLength"] = "icon", 60
    elif name == "layout.json":
        _layout_entry(data)
        screens = data.get("screens")
        if isinstance(screens, dict):
            # per-monitor-name entries predate the main / extra roles
            data["screens"] = {r: screens[r] for r in ("main", "extra") if isinstance(screens.get(r), dict)}
            for e in data["screens"].values():
                _layout_entry(e)


def to_2(name: str, data: dict) -> None:
    """Version 2: the file manager's bookmarks are the sidebar's folder entries (its ordered list,
    defaults added by the shell); the frames option is gone."""
    if name == "modules.json":
        values = data.get("values")
        files = values.get("files") if isinstance(values, dict) else None
        if isinstance(files, dict):
            marks = files.pop("bookmarks", None)
            files.pop("frames", None)
            if "sidebar" not in files and isinstance(marks, list):
                files["sidebar"] = [{"path": b["path"], "name": b.get("name") or b["path"], "kind": "folder",
                                     "hidden": False} for b in marks if isinstance(b, dict) and b.get("path")]


def to_3(name: str, data: dict) -> None:
    """Version 3: the Yandex Music module's id is "yandex" (was "music"); its options move with it."""
    if name == "modules.json":
        values = data.get("values")
        if isinstance(values, dict) and "music" in values:
            values.setdefault("yandex", values.pop("music"))


def to_4(name: str, data: dict) -> None:
    """Version 4: the file manager's key hints line is gone, and its option with it."""
    if name == "modules.json":
        values = data.get("values")
        files = values.get("files") if isinstance(values, dict) else None
        if isinstance(files, dict):
            files.pop("hints", None)


def to_5(name: str, data: dict) -> None:
    """Version 5: Capture has no popup: the shortcut freezes the screens and the overlay's
    toolbar holds the choices, so how the shortcut opens and the popup's own window are gone."""
    if name == "modules.json":
        values = data.get("values")
        capture = values.get("capture") if isinstance(values, dict) else None
        if isinstance(capture, dict):
            for key in ("shortcut", "detached", "detachedSide", "popupFps", "popupSound"):
                capture.pop(key, None)


def to_6(name: str, data: dict) -> None:
    """Version 6: the Yandex Music window is the Music app (id "music"): its options leave
    "yandex" (the bar module's stay); the tab it opened on becomes the page, likes or Now playing."""
    if name == "modules.json":
        values = data.get("values")
        yandex = values.get("yandex") if isinstance(values, dict) else None
        if isinstance(yandex, dict):
            music = values.setdefault("music", {})
            tab = yandex.pop("defaultTab", None)
            if tab is not None:
                music.setdefault("opensOn", "likes" if tab == "likes" else "playing")
            for key in ("showRemaining", "closeOnPlay"):
                if key in yandex:
                    music.setdefault(key, yandex.pop(key))
            if not music:
                values.pop("music")


def to_7(name: str, data: dict) -> None:
    """Version 7: the bar's music module is one, "music" (was yandex, player and radio: their
    layout ids are renamed, RENAMED). Its face options (text, show, titleLength) come from
    yandex, else player, else radio; the Music window's "opensOn" moves to the new pages."""
    if name == "layout.json":
        _layout_entry(data)
        screens = data.get("screens")
        for e in screens.values() if isinstance(screens, dict) else []:
            if isinstance(e, dict):
                _layout_entry(e)
    elif name == "modules.json":
        values = data.get("values")
        if not isinstance(values, dict):
            return
        music = values.get("music") if isinstance(values.get("music"), dict) else {}
        for old in ("yandex", "player", "radio"):
            m = values.pop(old, None)
            if isinstance(m, dict):
                for key in ("text", "show", "titleLength"):
                    if key in m:
                        music.setdefault(key, m[key])
        opens = {"likes": "yandex", "playing": "last"}
        if music.get("opensOn") in opens:
            music["opensOn"] = opens[music["opensOn"]]
        if music:
            values["music"] = music
        else:
            values.pop("music", None)


def to_8(name: str, data: dict) -> None:
    """Version 8: keys nothing reads any more go (the accent's gradient and its custom
    colours, the password dots), and the unseen dot's old colour "light" is "theme"."""
    if name != "settings.json":
        return
    for key in ("accentGradient", "accentCustom", "passwordDots"):
        data.pop(key, None)
    if data.get("barDotColor") == "light":
        data["barDotColor"] = "theme"


def to_9(name: str, data: dict) -> None:
    """Version 9: the hub's picture is the profile's (Shell Manager › Profile)."""
    if name != "modules.json":
        return
    values = data.get("values")
    hub = values.get("hub") if isinstance(values, dict) else None
    if isinstance(hub, dict) and "avatar" in hub:
        avatar = hub.pop("avatar")
        profile = values.setdefault("profile", {})
        if isinstance(profile, dict):
            profile.setdefault("avatar", avatar)


# the modules that have a tile in the hub (BarLayout `tile: true`)
HUB_TILES = ("mode", "wifi", "bluetooth", "mihomo", "timer", "focus")


def to_10(name: str, data: dict) -> None:
    """Version 10: the hub's tiles have a zone of their own ("tiles"); the tile modules the
    saved hub held move there, in their order, the rest stay its chips."""
    if name != "layout.json":
        return
    entries = [data] + [e for e in (data.get("screens") or {}).values() if isinstance(e, dict)]
    for e in entries:
        island = e.get("island")
        if not isinstance(island, dict) or "tiles" in island or not isinstance(island.get("hub"), list):
            continue
        island["tiles"] = [i for i in island["hub"] if i in HUB_TILES]
        island["hub"] = [i for i in island["hub"] if i not in HUB_TILES]


def to_11(name: str, data: dict) -> None:
    """Version 11: the global accent no longer targets bar modules."""
    if name != "settings.json":
        return
    where = data.get("accentWhere")
    if isinstance(where, dict):
        where.pop("modules", None)


MIGRATIONS = {0: to_1, 1: to_2, 2: to_3, 3: to_4, 4: to_5, 5: to_6, 6: to_7, 7: to_8, 8: to_9, 9: to_10, 10: to_11}          # n -> the step from version n to n + 1


def migrate(name: str, data: dict) -> dict:
    v = data.get("version", 0)
    if not isinstance(v, int) or v < 0:
        v = 0
    while v < VERSION:
        MIGRATIONS[v](name, data)
        v += 1
    data["version"] = v          # a newer file than this script keeps its own
    return data


def migrate_file(path: Path) -> bool:
    try:
        text = path.read_text()
        data = json.loads(text)
    except (OSError, ValueError):
        return False
    if not isinstance(data, dict):
        return False
    before = json.dumps(data, sort_keys=True)
    migrate(path.name, data)
    if json.dumps(data, sort_keys=True) == before:
        return False
    path.with_name(path.name + ".bak").write_text(text)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(json.dumps(data, indent=4) + "\n")
    tmp.replace(path)
    return True


def main(argv: list[str]) -> int:
    folder = Path(argv[1]) if len(argv) > 1 else state_dir()
    changed = [n for n in FILES if migrate_file(folder / n)]
    print(json.dumps({"ok": True, "changed": changed}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
