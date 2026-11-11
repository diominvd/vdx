"""Window rules reject malformed state and report backend failures as JSON."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "packages/quickshell/shell/scripts"
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location("shellapps_backend", SCRIPTS / "shellapps.py")
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)


def reply(fn, *args):
    output = io.StringIO()
    with contextlib.redirect_stdout(output), unittest.TestCase().assertRaises(SystemExit) as exited:
        fn(*args)
    return exited.exception.code, json.loads(output.getvalue())


class ShellApps(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        for name, filename in (("STATE", "state.json"), ("RULES", "rules.lua")):
            override = patch.object(backend, name, Path(temporary.name) / filename)
            override.start()
            self.addCleanup(override.stop)

    def test_corrupt_saved_shapes_fall_back_to_app_defaults(self):
        app = backend.APPS[0]
        with tempfile.TemporaryDirectory() as tmp, patch.object(backend, "STATE", Path(tmp) / "state.json"):
            for saved in (None, [], 5, {app["id"]: None}, {app["id"]: {"preset": []}},
                          {app["id"]: {"mode": "broken"}}):
                with self.subTest(saved=saved):
                    backend.STATE.write_text(json.dumps(saved))
                    settings = backend.load()[app["id"]]
                    self.assertEqual(settings, {**backend.DEFAULT, "width": app["width"], "height": app["height"]})
                    self.assertIsInstance(backend.rule(app, settings), str)

    def test_nonobject_or_invalid_changes_do_not_write_files(self):
        app = backend.APPS[0]
        for change in (None, [], 1, {"preset": []}, {"x": True}, {"height": False}):
            with self.subTest(change=change), patch.object(backend, "write") as write, \
                 patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "stub")):
                code, result = reply(backend.cmd_set, app["id"], json.dumps(change))
                self.assertEqual(code, 1)
                self.assertFalse(result["ok"])
                self.assertIsInstance(result["error"], str)
                write.assert_not_called()

    def test_valid_saved_choice_survives_load(self):
        app = backend.APPS[0]
        with tempfile.TemporaryDirectory() as tmp, patch.object(backend, "STATE", Path(tmp) / "state.json"):
            backend.STATE.write_text(json.dumps({app["id"]: {"mode": "tiled"}}))
            self.assertEqual(backend.rule(app, backend.load()[app["id"]]), "{ float = false }")

    def test_reload_failure_and_retry_return_json(self):
        app = backend.APPS[0]
        with tempfile.TemporaryDirectory() as tmp, patch.object(backend, "STATE", Path(tmp) / "state.json"), \
             patch.object(backend, "RULES", Path(tmp) / "rules.lua"):
            for response in (None, subprocess.CompletedProcess([], 1, "", "reload rejected"),
                             subprocess.CompletedProcess([], 0, "", "")):
                with self.subTest(response=response), patch.object(backend, "run", return_value=response):
                    code, result = reply(backend.cmd_set, app["id"], '{"mode":"tiled"}')
                    self.assertEqual(result["ok"], response is not None and response.returncode == 0)
                    self.assertEqual(code, 0 if result["ok"] else 1)
            self.assertIn("float = false", backend.RULES.read_text())


if __name__ == "__main__":
    unittest.main()
