"""Cursor backend validates persisted state and Xcursor data before applying it."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "packages/quickshell/shell/scripts"
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location("cursors", SCRIPTS / "cursors.py")
cursors = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cursors)


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


def image_cursor(width=1, height=1, pixels=b"\0\0\0\xff"):
    image_offset = 28
    toc = struct.pack("<III", cursors.IMAGE, 24, image_offset)
    header = b"Xcur" + struct.pack("<III", 16, 1, 1)
    chunk = struct.pack("<IIIIIIIII", 36, cursors.IMAGE, 24, 1, width, height, 0, 0, 0)
    return header + toc + chunk + pixels


class Cursors(unittest.TestCase):
    def test_corrupt_saved_state_falls_back_to_clean_default(self):
        corrupt = [
            "null", "[]", '{"base": 12}', '{"name": []}', '{"size": true}',
            '{"size": "24"}', '{"size": 11}', '{"mode": "unknown"}',
            '{"fill": 4}', '{"mode": "theme", "fill": "000000", "outline": "bad"}',
        ]
        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(cursors, "STATE", Path(tmp) / "cursor.json"):
            state = cursors.STATE
            for raw in corrupt:
                with self.subTest(raw=raw):
                    state.write_text(raw)
                    self.assertEqual(cursors.saved(), cursors.DEFAULT)

    def test_valid_saved_state_is_preserved(self):
        value = {"base": "Bibata", "name": "dotfiles-cursor-000000-ffffff", "size": 32,
                 "mode": "theme", "fill": "000000", "outline": "ffffff"}
        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(cursors, "STATE", Path(tmp) / "cursor.json"):
            cursors.STATE.write_text(json.dumps(value))
            self.assertEqual(cursors.saved(), value)

    def test_xcursor_chunks_validate_header_table_ranges_and_pixels(self):
        valid = image_cursor()
        self.assertEqual(list(cursors.chunks(valid)), [(24, 64, 1, 1)])
        self.assertEqual(list(cursors.chunks(b"PNG unsupported")), [])
        self.assertEqual(cursors.tint_file(b"PNG unsupported", lambda data: b"changed"), b"PNG unsupported")
        malformed = [
            b"Xcur",
            b"Xcur" + struct.pack("<III", 16, 1, 2),
            valid[:28] + struct.pack("<III", cursors.IMAGE, 24, 9999),
            image_cursor(width=2, pixels=b"\0\0\0\xff"),
        ]
        for data in malformed:
            with self.subTest(data=data):
                with self.assertRaises(ValueError):
                    list(cursors.chunks(data))

    def test_preview_turns_malformed_cursor_into_json_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            theme = Path(tmp) / "theme"
            (theme / "cursors").mkdir(parents=True)
            (theme / "cursors/left_ptr").write_bytes(b"Xcur")
            with mock.patch.object(cursors, "theme_dir", return_value=theme), \
                 mock.patch.object(cursors, "PREVIEWS", Path(tmp) / "preview"):
                result, code = reply(cursors.main, ["preview", "theme"])
        self.assertEqual(code, 1)
        self.assertFalse(result["ok"])
        self.assertIn("Xcursor", result["error"])

    def test_required_apply_commands_report_missing_and_nonzero(self):
        success = subprocess.CompletedProcess([], 0, "", "")
        failure = subprocess.CompletedProcess([], 1, "", "command failed")
        cases = [
            ([None], "hyprctl", "unavailable or timed out"),
            ([failure], "hyprctl", "command failed"),
            ([success, None], "gsettings", "unavailable or timed out"),
            ([success, failure], "gsettings", "command failed"),
        ]
        for results, command, message in cases:
            with self.subTest(command=command, results=results), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                with mock.patch.object(cursors, "installed", return_value={"Adwaita"}), \
                     mock.patch.object(cursors, "ICONS", root / "icons"), \
                     mock.patch.object(cursors, "STATE", root / "state/cursor.json"), \
                     mock.patch.object(subprocess, "run", side_effect=results):
                    output, code = reply(cursors.main, ["set", "Adwaita", "24", "original"])
            self.assertEqual(code, 1)
            self.assertFalse(output["ok"])
            self.assertIn(command, output["error"])
            self.assertIn(message, output["error"])

    def test_successful_apply_runs_bounded_commands_and_writes_state(self):
        success = subprocess.CompletedProcess([], 0, "", "")
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with mock.patch.object(cursors, "installed", return_value={"Adwaita"}), \
                 mock.patch.object(cursors, "ICONS", root / "icons"), \
                 mock.patch.object(cursors, "STATE", root / "state/cursor.json"), \
                 mock.patch.object(subprocess, "run", return_value=success) as command:
                output, code = reply(cursors.main, ["set", "Adwaita", "24", "original"])
            self.assertEqual((output, code), ({"ok": True}, 0))
            self.assertEqual([call.args[0][0] for call in command.call_args_list], ["hyprctl", "gsettings", "gsettings"])
            self.assertTrue(all(call.kwargs["timeout"] == 5 for call in command.call_args_list))
            self.assertEqual(json.loads((root / "state/cursor.json").read_text())["base"], "Adwaita")

    def test_command_entry_turns_filesystem_errors_into_json(self):
        with mock.patch.object(cursors, "cmd_list", side_effect=OSError("read only")):
            result, code = reply(cursors.main, ["list"])
        self.assertEqual(code, 1)
        self.assertEqual(result, {"ok": False, "error": "read only"})


if __name__ == "__main__":
    unittest.main()
