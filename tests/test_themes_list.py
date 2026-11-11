import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "packages/quickshell/shell/scripts/themes.sh"
ROLES = (
    "background0 background1 background2 background3 foreground0 foreground1 "
    "foreground2 red orange yellow green aqua blue purple gray muted frame dim"
).split()


class ThemesListTests(unittest.TestCase):
    def run_list(self, dotfiles):
        env = os.environ.copy()
        env["HOME"] = str(dotfiles.parent)
        return subprocess.run(
            ["bash", str(SCRIPT)],
            check=True,
            capture_output=True,
            text=True,
            env=env,
        ).stdout

    def test_lists_colors_and_active_theme(self):
        with tempfile.TemporaryDirectory() as tmp:
            dotfiles = Path(tmp) / ".dotfiles"
            themes = dotfiles / "themes"
            spaced = themes / "a space" / "quickshell/shell/config/Colors.qml"
            spaced.parent.mkdir(parents=True)
            spaced.write_text(
                """property   color background0 : "#123456"
property color red: "#abc"
property color red: "#AaBbCc"
property color red: "#ffffff"
property color orange: "#1234567"
property color orange: "#010203"
property color blue: "#a1B2c3" trailing text
"""
            )
            (themes / "b-empty").mkdir(parents=True)
            dotfiles.mkdir(exist_ok=True)
            (dotfiles / ".theme").write_text("a space\n")

            first = {"background0": "#123456", "red": "#AaBbCc", "orange": "#010203", "blue": "#a1B2c3"}
            second = {}
            expected = "".join(
                f"{name} " + " ".join(first.get(role, "#000000") for role in ROLES) + "\n"
                for name, first in (("a space", first), ("b-empty", second))
            ) + "---\na space\n"
            self.assertEqual(self.run_list(dotfiles), expected)

    def test_missing_active_file_uses_gruvbox(self):
        with tempfile.TemporaryDirectory() as tmp:
            dotfiles = Path(tmp) / ".dotfiles"
            (dotfiles / "themes" / "empty").mkdir(parents=True)
            self.assertEqual(
                self.run_list(dotfiles),
                "empty " + " ".join(["#000000"] * len(ROLES)) + "\n---\ngruvbox\n",
            )


if __name__ == "__main__":
    unittest.main()
