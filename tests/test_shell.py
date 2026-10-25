"""What the shell is told (the bar modules whose components are all off), and
what `check shell` finds wrong in it."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from installer import check, components, shell
from tests.test_components import catalog

CAT = catalog(
    quickshell={"group": "desktop", "modules": ["clock", "audio"]},
    ollama={"group": "ai", "modules": ["ai"]},
    claude={"group": "ai", "modules": ["ai"]},
    yandex={"group": "music", "modules": ["yandex"]},
)


class Render(unittest.TestCase):
    def off(self, on):
        return json.loads(shell.render(on, CAT))["off"]

    def test_everything_on_is_nothing_off(self):
        self.assertEqual(self.off(set(CAT)), {})

    def test_a_module_stays_while_one_of_its_components_is_on(self):
        self.assertEqual(self.off({"quickshell", "claude"}), {"yandex": ["yandex"]})
        self.assertEqual(self.off({"quickshell"}), {"ai": ["ollama", "claude"], "yandex": ["yandex"]})


class Sections(unittest.TestCase):
    """A music section is off with its component, as a bar module is."""

    def test_files_is_off_without_mpd(self):
        cat = catalog(quickshell={"group": "desktop", "modules": ["music"]},
                      mpd={"group": "music", "modules": ["files"]},
                      ytm={"group": "music", "modules": ["yandex"], "requires": ["mpd"]})
        self.assertEqual(json.loads(shell.render({"quickshell"}, cat))["off"], {"files": ["mpd"], "yandex": ["ytm"]})
        self.assertEqual(json.loads(shell.render({"quickshell", "mpd", "ytm"}, cat))["off"], {})


class Apply(unittest.TestCase):
    def test_written_only_when_changed(self):
        with tempfile.TemporaryDirectory() as tmp, \
             mock.patch.object(components, "load", return_value=CAT), \
             mock.patch.object(components, "selected", return_value={"quickshell"}):
            f = Path(tmp) / "dotfiles" / "components.json"
            self.assertTrue(shell.apply(f))
            self.assertFalse(shell.apply(f))
            self.assertIn("yandex", json.loads(f.read_text())["off"])


class ShellProblems(unittest.TestCase):
    """A tiny shell tree: one icon, one registered module."""

    def problems(self, files):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name, text in files.items():
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_text(text)
            with mock.patch.object(check, "SHELL", root), mock.patch.object(check, "PKG", root):
                return check.shell_problems()

    SVG = '<svg fill="#ffffff"/>'
    TREE = {
        "kit/icons/clock.svg": SVG, "kit/icons/solid/clock.svg": SVG,
        "kit/icons/round/clock.svg": SVG, "kit/icons/round/solid/clock.svg": SVG,
        "bar/BarLayout.qml": '{ id: "clock", label: "Clock" }\n',
        "bar/ModuleFaces.qml": "Component { id: clock; Clock {} }\n",
    }

    def test_a_whole_tree_is_clean(self):
        self.assertEqual(self.problems(self.TREE), [])

    def test_an_icon_needs_its_rounded_twins(self):
        tree = {k: v for k, v in self.TREE.items() if k != "kit/icons/round/solid/clock.svg"}
        self.assertEqual(self.problems(tree), ["kit/icons/clock.svg: no round/solid/ twin"])

    def test_a_module_needs_its_component_in_module_faces(self):
        tree = dict(self.TREE, **{"bar/ModuleFaces.qml": ""})
        self.assertEqual(self.problems(tree), ["bar/ModuleFaces.qml: no Component for module clock"])

    def phosphor_tree(self):
        tree = dict(self.TREE)
        tree.update({
            "kit/KitIcon.qml": '''
readonly property string phosphorName: ({ "clock": "clock" }[name] ?? "")
source: Qt.resolvedUrl("icons/phosphor/" + phosphorName + ".svg")
brightness: 1
colorization: 1
colorizationColor: root.tint
''',
            "kit/icons/material.txt": "clock\\n",
            "kit/icons/phosphor/clock.svg": self.SVG,
            "kit/icons/phosphor/clock-fill.svg": self.SVG,
        })
        return tree

    def test_phosphor_alias_requires_both_weights(self):
        tree = self.phosphor_tree()
        del tree["kit/icons/phosphor/clock-fill.svg"]
        self.assertEqual(self.problems(tree), [
            "kit/KitIcon.qml: 'clock' maps to missing Phosphor asset clock-fill.svg"
        ])

    def test_legacy_catalogue_key_requires_phosphor_alias(self):
        tree = self.phosphor_tree()
        tree["kit/KitIcon.qml"] = '''
readonly property string phosphorName: ({ }[name] ?? "")
source: Qt.resolvedUrl("icons/phosphor/" + phosphorName + ".svg")
brightness: 1
colorization: 1
colorizationColor: root.tint
'''
        self.assertEqual(self.problems(tree), [
            "kit/KitIcon.qml: missing Phosphor alias for legacy key 'clock'"
        ])


if __name__ == "__main__":
    unittest.main()
