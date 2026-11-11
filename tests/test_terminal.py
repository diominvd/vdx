"""Terminal settings persist through launcher reads and reject unavailable choices."""
import importlib.util
from pathlib import Path
import sys
import subprocess
import tempfile
import unittest
from unittest import mock
from tests.test_multiplexer import launcher

SCRIPT = Path(__file__).resolve().parents[1] / "packages/quickshell/shell/scripts/terminal.py"
sys.path.insert(0, str(SCRIPT.parent))
spec = importlib.util.spec_from_file_location("terminal_settings", SCRIPT)
terminal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(terminal)


class Terminal(unittest.TestCase):
    def test_override_survives_default_change_and_reset_restores_default(self):
        with tempfile.TemporaryDirectory() as tmp:
            state = Path(tmp) / "dotfiles"
            state.mkdir()
            (state / "components.json").write_text('{"multiplexer":"tmux"}')
            with mock.patch.object(terminal, "STATE", state), mock.patch.dict(launcher.os.environ, {"XDG_STATE_HOME": tmp}):
                self.assertEqual(launcher.choice(), "tmux")
                terminal.select("none")
                (state / "components.json").write_text('{"multiplexer":"zellij"}')
                self.assertEqual(launcher.choice(), "none")
                (state / "terminal.json").unlink()
                self.assertEqual(launcher.choice(), "zellij")

    def test_unavailable_choice_does_not_overwrite_preference(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(terminal, "STATE", Path(tmp)), mock.patch.object(terminal.shutil, "which", return_value=None):
            terminal.select("none")
            with self.assertRaisesRegex(ValueError, "not installed"):
                terminal.select("zellij")
            self.assertEqual(terminal.status()["selected"], "none")


class TerminalPadding(unittest.TestCase):
    def test_axes_persist_independently_and_invalid_input_preserves_file(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(terminal, "CONFIG", Path(tmp)):
            self.assertEqual(terminal.padding_values(), {"horizontal": 6, "vertical": 6})
            terminal.set_padding("horizontal", "14")
            terminal.set_padding("vertical", "0")
            target = Path(tmp) / "kitty/padding.conf"
            self.assertEqual(target.read_text(), "window_padding_width 0 14 0 14\n")
            self.assertEqual(terminal.padding_values(), {"horizontal": 14, "vertical": 0})
            for axis, value in [("unknown", "5"), ("horizontal", "-1"), ("vertical", "41"), ("vertical", "bad")]:
                with self.assertRaises(ValueError):
                    terminal.set_padding(axis, value)
            self.assertEqual(target.read_text(), "window_padding_width 0 14 0 14\n")

    def test_malformed_padding_uses_default(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(terminal, "CONFIG", Path(tmp)):
            target = Path(tmp) / "kitty/padding.conf"
            target.parent.mkdir()
            for text in ["broken", "window_padding_width -1 6 -1 6", "window_padding_width 1 2 3 4"]:
                target.write_text(text)
                self.assertEqual(terminal.padding_values(), {"horizontal": 6, "vertical": 6})


class TmuxZen(unittest.TestCase):
    def test_saved_without_running_server_and_independent_of_zellij(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(terminal, "CONFIG", Path(tmp)), mock.patch.object(terminal, "STATE", Path(tmp) / "state"):
            result = subprocess.CompletedProcess([], 1, "", "no server running")
            with mock.patch.object(terminal, "run", return_value=result):
                self.assertTrue(terminal.set_zen("on", "tmux")["ok"])
                self.assertTrue(terminal.zen_enabled("tmux"))
                self.assertFalse(terminal.zen_enabled("zellij"))
                self.assertTrue(terminal.set_zen("off", "tmux")["ok"])
                self.assertFalse(terminal.zen_enabled("tmux"))

    def test_updates_open_session_without_unzooming_existing_zen(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(terminal, "CONFIG", Path(tmp)), mock.patch.object(terminal, "STATE", Path(tmp) / "state"):
            listed = subprocess.CompletedProcess([], 0, "$1\t@2\t1\n", "")
            done = subprocess.CompletedProcess([], 0, "", "")
            with mock.patch.object(terminal, "run", side_effect=[listed, done, done, done, done]) as command:
                self.assertTrue(terminal.set_zen("on", "tmux")["ok"])
                calls = [call.args[0] for call in command.call_args_list]
                self.assertIn(["tmux", "set-option", "-t", "$1", "status", "off"], calls)
                self.assertFalse(any("resize-pane" in call for call in calls))
            listed.stdout = "$1\t@2\t0\n"
            with mock.patch.object(terminal, "run", side_effect=[listed, done, done, done, done, done]) as command:
                self.assertTrue(terminal.set_zen("on", "tmux")["ok"])
                self.assertEqual(command.call_args.args[0], ["tmux", "resize-pane", "-Z", "-t", "@2"])
