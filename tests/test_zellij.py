"""Numbered Zellij sessions reserve names even before the server lists them."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SESSION = ROOT / "packages/zellij/session.py"


class Zellij(unittest.TestCase):
    def test_numbered_sessions_reserve_names_and_ignore_random_names(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            fake = work / "zellij"
            fake.write_text("#!" + sys.executable + "\n" + '''import json, os, sys
from pathlib import Path
if sys.argv[1] == 'list-sessions':
    print('1\\n3\\nrandom-name')
else:
    with Path(os.environ['SESSION_CALLS']).open('a') as log:
        log.write(json.dumps(sys.argv[1:])+'\\n')
''')
            fake.chmod(0o755)
            calls = work / "calls"
            env = os.environ | {"PATH": str(work), "XDG_STATE_HOME": str(work / "state"),
                                "ZELLIJ_SESSION_NAME": "1", "SESSION_CALLS": str(calls)}
            for _ in range(2):
                subprocess.run([sys.executable, str(SESSION), "new"], env=env, check=True,
                               capture_output=True, text=True, timeout=5)
            self.assertEqual([json.loads(line) for line in calls.read_text().splitlines()], [
                ["--session", "1", "action", "switch-session", "4"],
                ["--session", "1", "action", "switch-session", "5"],
            ])


spec = importlib.util.spec_from_file_location("zellij_session", SESSION)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Zen(unittest.TestCase):
    def test_targets_active_tab_and_distinguishes_regular_zoom(self):
        tabs = [{"tab_id": 3, "active": True}, {"tab_id": 7, "active": False}]
        pane = {"id": 22, "tab_id": 3, "is_focused": True, "is_plugin": False,
                "is_fullscreen": True, "pane_y": 1, "pane_x": 0}
        other = pane | {"id": 99, "tab_id": 7}
        with mock.patch.object(module, "query", side_effect=[tabs, [other, pane]]), mock.patch.object(module.subprocess, "run") as action:
            self.assertTrue(module.apply_zen("zellij", "1", True))
            self.assertEqual(action.call_args.args[0][-2:], ["--pane-id", "terminal_22"])
        pane["pane_y"] = 0
        with mock.patch.object(module, "query", side_effect=[tabs, [pane]]), mock.patch.object(module.subprocess, "run") as action:
            self.assertTrue(module.apply_zen("zellij", "1", True))
            action.assert_not_called()
        with mock.patch.object(module, "query", side_effect=[tabs, [pane]]), mock.patch.object(module.subprocess, "run") as action:
            self.assertTrue(module.apply_zen("zellij", "1", False))
            action.assert_called_once()

    def test_preference_persists_and_exited_sessions_are_ignored(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.dict(os.environ, {"XDG_STATE_HOME": tmp}):
            response = subprocess.CompletedProcess([], 0, "1 [Created 1m ago]\nold [Created 2m ago] (EXITED - attach to resurrect)\n", "")
            with mock.patch.object(module.subprocess, "run", return_value=response), mock.patch.object(module, "apply_zen") as apply:
                module.set_zen("zellij", True)
                self.assertTrue(module.zen_enabled())
                apply.assert_called_once_with("zellij", "1", True)
                apply.reset_mock()
                module.set_zen("zellij", False)
                self.assertFalse(module.zen_enabled())
                apply.assert_called_once_with("zellij", "1", False)
            module.zen_preference().write_text('{"zen":"false"}')
            self.assertFalse(module.zen_enabled())

    def test_no_startup_child_when_disabled_and_retry_until_ready(self):
        with mock.patch.object(module, "zen_enabled", return_value=False), mock.patch.object(module.subprocess, "Popen") as child:
            module.schedule_zen("1")
            child.assert_not_called()
        with mock.patch.object(module, "zen_enabled", return_value=True), mock.patch.object(module, "apply_zen", side_effect=[False, True]) as apply, mock.patch.object(module.time, "sleep"):
            module.initialise_zen("zellij", "1")
            self.assertEqual(apply.call_count, 2)
        with mock.patch.object(module, "zen_enabled", return_value=True), mock.patch.object(module.time, "monotonic", side_effect=[0, 9]), mock.patch.object(module, "apply_zen") as apply:
            module.initialise_zen("zellij", "1")
            apply.assert_not_called()

    def test_query_rejects_invalid_json_shape(self):
        for text in ('{}', '[42]', 'broken'):
            with mock.patch.object(module.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, text, "")):
                with self.assertRaises(ValueError):
                    module.query("zellij", "1", "list-tabs")
