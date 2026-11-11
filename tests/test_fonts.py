"""Font backend reports required fontconfig failures and tolerates reload misses."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "packages/quickshell/shell/scripts"
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location("fonts", SCRIPTS / "fonts.py")
fonts = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fonts)


def reply(fn, *args):
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        try:
            fn(*args)
        except SystemExit as e:
            code = e.code
        else:
            code = 0
    return json.loads(output.getvalue()), code


class Fonts(unittest.TestCase):
    def test_required_queries_report_missing_and_nonzero_tools(self):
        for result, message in [
            (None, "unavailable or timed out"),
            (subprocess.CompletedProcess([], 1, "", "bad query"), "bad query"),
        ]:
            for command, results in (("fc-list", [result]), ("fc-match", [
                subprocess.CompletedProcess([], 0, "JetBrainsMono Nerd Font\n", ""), result,
            ])):
                with self.subTest(command=command, result=result), mock.patch.object(subprocess, "run", side_effect=results):
                    output, code = reply(fonts.main, ["list"])
                self.assertEqual(code, 1)
                self.assertFalse(output["ok"])
                self.assertIn(message, output["error"])

    def test_cache_failure_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(fonts, "FONTS", Path(tmp)):
            root = Path(tmp)
            for result, message in [
                (None, "unavailable or timed out"),
                (subprocess.CompletedProcess([], 1, "", "cache failed"), "cache failed"),
            ]:
                def download(_url, archive):
                    source = root / "source"
                    source.mkdir(exist_ok=True)
                    (source / "ExampleNerdFont.ttf").write_bytes(b"font")
                    with tarfile.open(archive, "w:xz") as tar:
                        tar.add(source / "ExampleNerdFont.ttf", arcname="ExampleNerdFont.ttf")

                with mock.patch.object(fonts.urllib.request, "urlretrieve", side_effect=download), \
                     mock.patch.object(subprocess, "run", return_value=result):
                    output, code = reply(fonts.main, ["install", "JetBrainsMono"])
                self.assertEqual(code, 1)
                self.assertFalse(output["ok"])
                self.assertIn(message, output["error"])

    def test_list_and_set_succeed_even_when_optional_reload_commands_fail(self):
        listed = subprocess.CompletedProcess([], 0, "JetBrainsMono Nerd Font\n", "")
        matched = subprocess.CompletedProcess([], 0, "JetBrainsMono Nerd Font", "")
        with mock.patch.object(subprocess, "run", side_effect=[listed, matched]):
            result, code = reply(fonts.cmd_list)
        self.assertEqual(code, 0)
        self.assertTrue(result["ok"])
        self.assertEqual(result["current"], "JetBrainsMono Nerd Font")
        self.assertTrue(next(f for f in result["fonts"] if f["family"] == "JetBrainsMono Nerd Font")["installed"])

        failures = [None, subprocess.CompletedProcess([], 1, "", "reload unavailable")]
        for failure in failures:
            with self.subTest(reload_result=failure), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                with mock.patch.object(fonts, "FONTS", root / "fonts"), \
                     mock.patch.object(fonts, "CHOICE", root / "state/font.conf"), \
                     mock.patch.object(fonts, "KITTY", root / "kitty/font.conf"), \
                     mock.patch.object(subprocess, "run", side_effect=[listed, failure, failure]) as command:
                    result, code = reply(fonts.cmd_set, "JetBrainsMono Nerd Font")
                self.assertEqual(code, 0)
                self.assertTrue(result["ok"])
                self.assertIn("JetBrainsMono Nerd Font", (root / "state/font.conf").read_text())
                self.assertIn("font_family JetBrainsMono Nerd Font", (root / "kitty/font.conf").read_text())
                self.assertEqual([call.args[0][0] for call in command.call_args_list], ["fc-list", "pkill", "makoctl"])

    def test_command_entry_turns_filesystem_errors_into_json(self):
        with mock.patch.object(fonts, "cmd_set", side_effect=OSError("read only")):
            result, code = reply(fonts.main, ["set", "Example"])
        self.assertEqual(code, 1)
        self.assertEqual(result, {"ok": False, "error": "read only"})


if __name__ == "__main__":
    unittest.main()
