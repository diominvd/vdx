"""The Shell Manager's search: the index is current, every target is a page the
Shell Manager opens, and the common tasks (05 › Journeys) are found by a word."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "packages/quickshell/shell/scripts/settings_index.py"
spec = importlib.util.spec_from_file_location("settings_index", SCRIPT)
si = importlib.util.module_from_spec(spec)
spec.loader.exec_module(si)

TABS = {"vpn", "profile", "themes", "fonts", "icons", "wallpaper", "cursor", "appearance", "colours", "glow", "animations",
        "bar", "barlook", "barmonitor", "modules", "windows", "lockscreen", "notifications",
        "hub", "live", "network", "sound", "power", "updates", "bluetooth", "displays", "apps", "about", "system", "settings"}

# a word typed -> where the task is done
JOURNEYS = {
    "wallpaper": "wallpaper",
    "toast": "notifications",
    "show bar": "barmonitor",
    "clock format": "lockscreen",
    "animations": "animations:general",
    "seconds": "modules:clock",
    "theme": "themes",
    "text size": "fonts:size",
    "hub width": "hub",
    "sliders": "hub",
    "accent": "colours",
    "gap": "windows:look",
    "search field": "modules:clipboard",
    "pause": "sound",
    "updates": "updates",
    "aur": "updates",
    "dot colour": "notifications",
    "width": "apps:launcher",
    "reset everything": "settings",
    "refresh rate": "displays:monitor",
    # the live activities, the island and the words people use for them
    "live": "live",
    "flash": "live",
    "low battery": "live",
    "island": "barlook",
    "solid": "barlook",
    "wifi": "network:wifi",
    "hotspot": "network:hotspot",
    "ethernet": "network:ethernet",
    "dark mode": "themes",
    "shortcut": "apps:keybinds",
    "tile": "hub",
    "app colour": "notifications",
    "vpn": "modules:mihomo",
    "night light": "displays",
    "charge limit": "power",
    # the sidebar's pages by their names, and rows that moved
    "glow": "glow",
    "strength": "glow",
    "bar look": "barlook",
    "density": "appearance",
    "input text": "appearance",
    "window frames": "windows:look",
    "update without asking": "updates",
    "notify when done": "updates",
    "restart the shell": "system",
    "badge": "notifications",
}

# a row is found on the page that shows it: (label, where it is not)
NOT_THERE = {("Preset", "Windows"), ("Width × height", "Windows"), ("Spot", "Windows")}

# a row's hint is its own: these used to carry the next row's
NOT_THIS_HINT = {("Open the hub", "Hub row modules"), ("Bar style", "Off and nothing beside it"),
                 ("Icon size", "Lines between neighbouring modules")}


def norm(s):
    return "".join(c for c in s.lower() if c.isalnum())


def search(index, q):
    """What ShellManager.qml's results find: the label, its aliases, then the hint and the place."""
    q = norm(q)
    return [e for e in index if q in norm(e["label"]) or any(q in norm(a) for a in e.get("aliases", []))
            or q in norm(e["hint"] + " " + e["where"])]


class Index(unittest.TestCase):
    index = si.build()

    def test_current(self):
        self.assertEqual(si.main(["settings_index.py", "--check"]), 0, "run scripts/settings_index.py")

    def test_targets(self):
        for e in self.index:
            self.assertIn(e["target"].split(":")[0], TABS, e)
            self.assertTrue(e["label"].strip(), e)

    def test_hints_are_their_own(self):
        for label, wrong in NOT_THIS_HINT:
            for e in self.index:
                if e["label"] == label:
                    self.assertNotIn(wrong, e["hint"], e)

    def test_rows_are_where_they_show(self):
        for label, page in NOT_THERE:
            for e in self.index:
                if e["label"] == label:
                    self.assertNotEqual(e["where"].split(" › ")[0], page, e)

    def test_sidebar_titles(self):
        # `where` names the page as the sidebar does, never the form it shares (Appearance)
        for e in self.index:
            self.assertNotEqual(e["where"].split(" › ")[0], "Appearance", e)

    def test_no_computed_labels(self):
        for e in self.index:
            self.assertEqual(e["label"], e["label"].strip(), e)

    def test_shared_blocks_are_read_where_used(self):
        # a page that uses a shared block (KitPanelOptions) is found by the block's rows
        for app in ("Launcher", "Keybinds"):
            where = [e["where"] for e in self.index if e["label"] == "Open from the island"]
            self.assertIn(f"Apps › {app} › ISLAND", where)
        self.assertIn("rows", si.keys_of(SCRIPT.parent.parent / "apps/launcher/LauncherSettings.qml"))

    def test_journeys(self):
        for q, target in JOURNEYS.items():
            self.assertIn(target, [e["target"] for e in search(self.index, q)], q)


SHELL = SCRIPT.parent.parent
# the files that show settings rows: the Shell Manager's pages and the options of each module and app
SETTINGS_FILES = sorted(set((SHELL / "apps/shellmanager").glob("*.qml")) | set(SHELL.glob("modules/*/*Settings.qml"))
                        | set(SHELL.glob("apps/*/*Settings.qml")) | set(SHELL.glob("modules/*/*Colours.qml")))
# a key written from two files on purpose: a `needs` button that switches the bar's style, the
# layout's undo (it puts the Folder's dot back), the wallpaper's service; accentWhere is a map of
# places: Colours sets the controls', Windows › Look the frame's (test_moved_rows_have_one_home)
NOT_A_SECOND_HOME = {"barStyle", "barFolderDot", "wallpaperMode", "accentWhere"}


class OneHome(unittest.TestCase):
    """Every setting has one row: a second place is a KitLinkRow, never a second control."""

    def writers(self):
        import re
        found = {}
        for f in SETTINGS_FILES:
            text = f.read_text()
            keys = {f"{m}.{k}" for m, k in re.findall(r'module:\s*"([\w-]+)";\s*key:\s*"(\w+)"', text)}
            keys |= {f"{m}.{k}" for m, k in re.findall(r'ModuleSettings\.set\("([\w-]+)",\s*"(\w+)"', text)}
            keys |= {k for k in re.findall(r'ShellSettings\.set(?:Look)?\("(\w+)"', text) if k not in NOT_A_SECOND_HOME}
            for k in keys:
                found.setdefault(k, []).append(f.name)
        return found

    def test_one_file_writes_each_key(self):
        for key, files in self.writers().items():
            self.assertEqual(len(files), 1, f"{key} is set in {files}")

    def test_moved_rows_have_one_home(self):
        updates = (SHELL / "apps/shellmanager/UpdatesPage.qml").read_text()
        packages = (SHELL / "apps/packages/PackagesSettings.qml").read_text()
        for key in ("noConfirm", "notify"):
            self.assertIn(f'key: "{key}"', updates)
            self.assertNotIn(f'key: "{key}"', packages)
        # the window frames' accent is Windows › Look's Frames; Colours links there
        accent = (SHELL / "apps/shellmanager/AccentSection.qml").read_text()
        self.assertNotIn('value: "window"', accent)
        self.assertIn('target: "windows:look"', accent)
        # a live line or a card: the Messages activity's switch; Notifications links there
        notes = (SHELL / "modules/notifications/NotificationsSettings.qml").read_text()
        self.assertNotIn('key: "appear"', notes)
        self.assertIn('target: "live:notice"', notes)

    def test_interface_holds_density_and_input_text(self):
        index = si.build()
        for label in ("Density", "Input text"):
            targets = {e["target"] for e in index if e["label"] == label and not e["where"].startswith("Apps")}
            self.assertEqual(targets, {"appearance"}, label)

    def test_app_reset_leaves_a_shared_page(self):
        keys = si.build_keys()
        self.assertIn("apps/shellmanager/UpdatesPage.qml", keys)
        self.assertTrue({"noConfirm", "notify", "autoInstall"} <= set(keys["apps/shellmanager/UpdatesPage.qml"]))
        page = (SHELL / "apps/shellmanager/ShellAppsPage.qml").read_text()
        self.assertIn('packages: "apps/shellmanager/UpdatesPage.qml"', page)


if __name__ == "__main__":
    unittest.main()
