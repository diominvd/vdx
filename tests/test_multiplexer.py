"""Wizard choice reaches kitty even when both multiplexer binaries exist."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from installer import components, shell, wizard

spec = importlib.util.spec_from_file_location("kitty_multiplexer", Path(__file__).resolve().parents[1] / "packages/kitty/multiplexer.py")
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class Multiplexer(unittest.TestCase):
    def test_switching_selects_one_and_launcher_obeys(self):
        cat = components.load()
        picks = wizard.Picks(cat, {"kitty", "tmux", "zellij"})
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "dotfiles/components.json"
            target.parent.mkdir()
            for selected in ("tmux", "zellij", "none", "tmux"):
                with self.subTest(selected=selected):
                    picks.select_multiplexer(selected)
                    self.assertEqual(picks.on & {"tmux", "zellij"}, set() if selected == "none" else {selected})
                    self.assertIn("kitty", picks.on)
                    target.write_text(shell.render(picks.on, cat))
                    self.assertEqual(json.loads(target.read_text())["multiplexer"], selected)
                    with mock.patch.dict(launcher.os.environ, {"XDG_STATE_HOME": tmp}), mock.patch.object(launcher.shutil, "which", return_value="/bin/available"):
                        self.assertEqual(launcher.choice(), selected)
                        with mock.patch.object(launcher.os, "execvp", side_effect=SystemExit) as execute:
                            with self.assertRaises(SystemExit):
                                launcher.main()
                            self.assertEqual(execute.call_args.args[0], {"tmux": "tmux", "zellij": "python3", "none": "zsh"}[selected])

    def test_missing_selected_binary_falls_back_to_shell(self):
        with mock.patch.object(launcher, "choice", return_value="zellij"), mock.patch.object(launcher.shutil, "which", return_value=None), mock.patch.object(launcher.os, "execvp", side_effect=SystemExit) as execute:
            with self.assertRaises(SystemExit):
                launcher.main()
            execute.assert_called_once_with("zsh", ["zsh", "--login"])
