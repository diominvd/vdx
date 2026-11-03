#!/usr/bin/env python3
"""The Shell Manager's search index, read from the settings pages' QML.

    settings_index.py            writes config/settings-index.json, config/settings-keys.json
    settings_index.py --check    the paths of the files out of date (exit 1)

An entry is a row the pages write out — {"label", "hint", "where", "target"}:
`where` is "Page › GROUP", `target` what `shell open` takes ("bar:look",
"modules:sysmon", "apps:files"). A row is a `label: "…"` outside a choice
list (a one-line object with a `value:` and no `hint:` is a choice); a computed
label is not found. The group is the KitLabel above it (and an entry itself); a group that is one of
the page's jumps makes the target that jump. Every bar module and app is an
entry of its own too. ./install.py check fails on a stale index.

settings-keys.json: the ModuleSettings keys each settings file of an app and
of its bar module writes ({file: [key, ...]}): the two share one id, so the
module's Reset clears only its keys, the app's every other one."""
import json, re, sys
from pathlib import Path

SHELL = Path(__file__).resolve().parent.parent
OUT = SHELL / "config" / "settings-index.json"
KEYS = SHELL / "config" / "settings-keys.json"
SM = SHELL / "apps" / "shellmanager"

# the pages with their own rows: tab, title, files (Appearance's sections each one jump)
PAGES = [
    ("appearance", "Appearance", ["AppearancePage.qml"]),
    ("themes", "Themes", ["ThemesPage.qml"]),
    ("fonts", "Fonts", ["FontsPage.qml"]),
    ("icons", "Icons", ["IconsPage.qml"]),
    ("wallpaper", "Wallpaper", ["WallpaperPage.qml"]),
    ("cursor", "Cursor", ["CursorPage.qml"]),
    ("animations", "Motion", ["AnimationsPage.qml"]),
    ("bar", "Bar", ["BarPage.qml"]),
    ("profile", "Profile", ["ProfilePage.qml"]),
    ("hub", "Hub", ["HubPage.qml", "HubBlocksList.qml"]),
    ("live", "Live activities", ["LivePage.qml"]),
    ("windows", "Windows", ["WindowsPage.qml"]),
    ("network", "Network", ["NetworkPage.qml"]),
    ("sound", "Sound", ["SoundPage.qml"]),
    ("power", "Power", ["PowerPage.qml"]),
    ("updates", "Updates", ["UpdatesPage.qml"]),
    ("bluetooth", "Bluetooth", ["BluetoothPage.qml"]),
    ("vpn", "VPN", ["VpnPage.qml"]),
    ("displays", "Displays", ["DisplaysPage.qml"]),
    ("about", "About", ["AboutPage.qml"]),
]
# words people type for a thing, by its label: found beside the label (and the normalised
# form: "wifi" = "Wi-Fi", see norm())
ALIASES = {
    "Bar style": ["island", "solid", "strip", "pill"],
    "Motion": ["animations", "animation", "transitions", "speed"],
    "Themes": ["dark", "light", "dark mode", "light mode", "colour mode", "night mode"],
    "Tiles per row": ["tile", "tiles", "toggles"],
    "New ones arrive as": ["card", "toast", "live line", "popup", "banner"],
    "Card stays for": ["toast", "how long", "duration"],
    "Messages": ["notification", "live", "chat"],
    "Brightness": ["night light", "dimming"],
    "Battery": ["power", "charge", "limit"],
    "Keybinds": ["shortcut", "shortcuts", "keys", "keybinding", "hotkey"],
    "Show bar": ["per monitor", "monitors", "extra monitor"],
    "Same bar everywhere": ["per monitor", "monitors"],
    "Add a rule": ["app colour", "avatar colour", "notification colour"],
    "Hub width": ["wider", "narrower", "size"],
    "Blocks": ["sliders", "tiles", "player", "calendar", "volume", "brightness"],
    "Show the clock": ["hide the clock", "time"],
    "Music": ["player", "song", "track"],
    "VPN": ["mihomo", "proxy"],
    "Layout": ["add module", "arrange", "order"],
}
SECTIONS = {"AccentSection.qml": "accent", "CornersSection.qml": "shape"}
# shared option blocks (kit): a file that uses one is read with the block's rows in its place
INCLUDES = {name: SHELL / "kit" / f"{name}.qml"
            for name in ("KitPanelOptions", "KitEnglishRow", "KitClearSearchRow", "KitPickerViewRow")}
INCLUDES["MeteredRow"] = SM / "MeteredRow.qml"

ROW = re.compile(r'\blabel:\s*"([^"]+)"')
GROUP = re.compile(r'(?:KitLabel\s*\{(?:[^{}]|\{[^{}]*\})*?\btext|KitGroup\s*\{(?:[^{}]|\{[^{}]*\})*?\btitle)'
                   r':\s*"([A-Z][A-Z0-9 -]+)"')
ACRONYMS = {"Ai": "AI", "Wi-fi": "Wi-Fi", "Dns": "DNS", "Vpn": "VPN", "Usb": "USB", "Gpu": "GPU", "Cpu": "CPU",
            "Osd": "OSD", "Mpd": "MPD", "Ip": "IP"}


def caption(group: str) -> str:
    """A caps group title as a label: "WI-FI NETWORKS" -> "Wi-Fi networks"."""
    words = group.capitalize().split(" ")
    return " ".join(ACRONYMS.get(w.capitalize(), w) for w in words)


def jumps(text: str) -> dict:
    """Group title (upper case) -> jump key, from the page's `jumps`."""
    return {label.upper(): key for key, label in re.findall(r'\{\s*key:\s*"(\w+)",\s*label:\s*"([^"]+)"', text)}


def hint_of(text: str, pos: int) -> str:
    """The `hint:` of the element the label at `pos` sits in — its own, never the next row's."""
    start = text.rfind("{", 0, pos)
    depth, end = 0, len(text)
    for i in range(start, len(text)):
        depth += {"{": 1, "}": -1}.get(text[i], 0)
        if depth == 0:
            end = i
            break
    body = text[start + 1:end]
    while True:                                         # the element's own lines: nested { } blocks out
        inner = re.sub(r"\{[^{}]*\}", "", body)
        if inner == body:
            break
        body = inner
    m = re.search(r'\bhint:\s*"([^"]*)"', body)
    return m.group(1) if m else ""


def expand(text: str) -> str:
    """The file's text with each shared block (INCLUDES) written out where it is used."""
    for name, path in INCLUDES.items():
        block = path.read_text()
        text = re.sub(r"\b" + name + r"\s*\{[^{}]*\}", lambda m, block=block: block, text)
    return text


def rows(text: str) -> list:
    """(group, label, hint) of every row, in file order."""
    text = re.sub(r"property var jumps: \[.*?\n  \]", "", text, flags=re.S)   # the page's own jump list
    marks = [(m.start(), "g", m.group(1)) for m in GROUP.finditer(text)]
    marks += [(m.start(), "r", m) for m in ROW.finditer(text)]
    out, group = [], ""
    for pos, kind, v in sorted(marks, key=lambda x: x[0]):
        if kind == "g":
            group = v
            continue
        # the object or element the label is in: from the nearest open brace to its close
        start = text.rfind("{", 0, pos)
        end = text.find("}", pos)
        body = text[start:end]
        if "\n" not in body and re.search(r"\bvalue:", body) and not re.search(r"\bhint:", body):
            continue                                    # a choice ({ label, value } on a line), not a row
        if v.group(1) != v.group(1).strip():
            continue                                    # a computed label ("Use " + name), not a row to find
        out.append((group, v.group(1), hint_of(text, pos)))
    return out


def entries_of(path: Path, title: str, tab: str, target: str = "") -> list:
    text = expand(path.read_text())
    own = jumps(text)
    out = []
    # each group is found by its title too
    for group in dict.fromkeys(GROUP.findall(text)):
        t = target or (f"{tab}:{own[group]}" if group in own else tab)
        out.append({"label": caption(group), "hint": "", "where": title, "target": t})
    for group, label, hint in rows(text):
        t = target or (f"{tab}:{own[group]}" if group in own else tab)
        out.append({"label": label, "hint": hint, "where": " › ".join(x for x in (title, group) if x), "target": t})
    return out


def build() -> list:
    out = []
    for tab, title, files in PAGES:
        out.append({"label": title, "hint": "", "where": "", "target": tab})   # the page by its name
        for f in files:
            out += entries_of(SM / f, title, tab)
    for f, key in SECTIONS.items():
        out += entries_of(SM / f, "Appearance", "appearance", f"appearance:{key}")
    out += entries_of(SHELL / "apps/lock/LockSettings.qml", "Lock screen", "lockscreen")
    out += entries_of(SM / "LockScreenPage.qml", "Lock screen", "lockscreen")
    out += entries_of(SHELL / "modules/notifications/NotificationsSettings.qml", "Notifications", "notifications")
    out += entries_of(SHELL / "modules/notifications/NotificationsColours.qml", "Notifications", "notifications")
    out += entries_of(SM / "BarLive.qml", "Live activities", "live")
    out += entries_of(SM / "NetworkHotspot.qml", "Network › Hotspot", "network", "network:hotspot")
    out += entries_of(SM / "NetworkEthernet.qml", "Network › Ethernet", "network", "network:ethernet")
    out += entries_of(SM / "WindowOptions.qml", "Windows", "windows")
    out.append({"label": "Bar text", "hint": "Content, name or icon only, for each bar module", "where": "Bar modules", "target": "modules"})
    layout = (SHELL / "bar" / "BarLayout.qml").read_text()
    for entry in re.findall(r'\{ id: "\w+",[^}]*\}', layout):
        mid = re.search(r'id: "(\w+)"', entry).group(1)
        label = re.search(r'label: "([^"]+)"', entry).group(1)
        about = re.search(r'about: "([^"]*)"', entry)
        target = "notifications" if mid == "notifications" else f"modules:{mid}"
        out.append({"label": label, "hint": about.group(1) if about else "", "where": "Bar modules", "target": target})
        settings = re.search(r'settings: "([\w.]+)"', entry)
        if settings and mid != "notifications":
            out += entries_of(SHELL / "modules" / mid / settings.group(1), f"Bar modules › {label}", "modules", target)
    for a in json.loads((SHELL / "apps" / "apps.json").read_text()):
        target = a.get("page") or f"apps:{a['id']}"
        if a.get("listed", True):           # "listed": false — not in Apps nor the launcher
            out.append({"label": a["label"], "hint": a.get("about", ""), "where": "Apps", "target": target})
        if a.get("settings") and not a.get("page") and a.get("listed", True):
            out += entries_of(SHELL / a["settings"], f"Apps › {a['label']}", "apps", target)
        if a.get("moduleSettings"):
            out += entries_of(SHELL / a["moduleSettings"], f"Bar modules › {a['label']}", "modules", f"modules:{a['module']}")
    seen, unique = set(), []
    for e in out:
        k = (e["label"], e["where"], e["target"])
        if k not in seen:
            seen.add(k)
            if e["label"] in ALIASES:
                e["aliases"] = ALIASES[e["label"]]
            unique.append(e)
    return unique


def keys_of(path: Path) -> list:
    text = expand(path.read_text())
    found = re.findall(r'\bkey:\s*"(\w+)"', text) + re.findall(r'ModuleSettings\.\w+\("[\w-]+",\s*"(\w+)"', text)
    if "BarTextRow" in text:
        found.append("text")
    return sorted(set(found))


def build_keys() -> dict:
    out = {}
    for a in json.loads((SHELL / "apps" / "apps.json").read_text()):
        for k in ("settings", "moduleSettings"):
            if a.get("module") and a.get(k):
                out[a[k]] = keys_of(SHELL / a[k])
    return out


def render() -> dict:
    return {OUT: json.dumps(build(), indent=1, ensure_ascii=False) + "\n",
            KEYS: json.dumps(build_keys(), indent=1) + "\n"}


def main(argv: list) -> int:
    files = render()
    if "--check" in argv:
        stale = [p for p, text in files.items() if not p.is_file() or p.read_text() != text]
        for p in stale:
            print(p.relative_to(SHELL.parent.parent.parent))
        return 1 if stale else 0
    for p, text in files.items():
        p.write_text(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
