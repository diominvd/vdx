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

TABS = {"vpn", "profile", "themes", "fonts", "icons", "wallpaper", "cursor", "appearance", "animations", "bar", "modules", "windows", "lockscreen", "notifications",
        "hub", "live", "network", "sound", "power", "updates", "bluetooth", "displays", "apps", "about"}

# a word typed -> where the task is done
JOURNEYS = {
    "wallpaper": "wallpaper",
    "toast": "notifications",
    "show bar": "bar:monitor",
    "clock format": "lockscreen",
    "animations": "animations:general",
    "seconds": "modules:clock",
    "theme": "themes",
    "text size": "fonts:size",
    "hub width": "hub",
    "sliders": "hub",
    "accent": "appearance:accent",
    "gap": "windows:look",
    "search field": "modules:clipboard",
    "pause": "sound",
    "updates": "updates",
    "aur": "updates",
    "dot colour": "notifications",
    "width": "apps:launcher",
    "reset everything": "about:settings",
    "refresh rate": "displays:monitor",
    # the live activities, the island and the words people use for them
    "live": "live",
    "flash": "live",
    "low battery": "live",
    "island": "bar",
    "solid": "bar",
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
}

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

    def test_no_computed_labels(self):
        for e in self.index:
            self.assertEqual(e["label"], e["label"].strip(), e)

    def test_journeys(self):
        for q, target in JOURNEYS.items():
            self.assertIn(target, [e["target"] for e in search(self.index, q)], q)


if __name__ == "__main__":
    unittest.main()
