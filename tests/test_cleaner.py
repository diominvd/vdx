"""Cleaner validates AI/cache data and reports bounded command failures."""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

SCRIPTS = Path(__file__).resolve().parents[1] / "packages/quickshell/shell/scripts"
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location("cleaner", SCRIPTS / "cleaner.py")
cleaner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cleaner)


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


def run_reply(fn, *args):
    return reply(cleaner.main, [fn, *args])


class Cleaner(unittest.TestCase):
    def setUp(self):
        self.addCleanup(setattr, cleaner, "summary", cleaner.summary)
        self.tmp = tempfile.TemporaryDirectory(prefix="cleaner-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.cache = self.home / ".cache"
        self.context = self.cache / "dotfiles/cleaner-ai.json"
        self.protected = [self.home / ".dotfiles", self.home / ".ssh"]
        patches = [
            mock.patch.object(cleaner, "HOME", self.home),
            mock.patch.object(cleaner, "CACHE", self.cache),
            mock.patch.object(cleaner, "CONTEXT", self.context),
            mock.patch.object(cleaner, "PROTECTED", self.protected),
            mock.patch.object(cleaner, "USER", []),
            mock.patch.object(cleaner, "ROOT", [("orphans", "Orphans", "", "orphans", "")]),
        ]
        for patcher in patches:
            patcher.start()
            self.addCleanup(patcher.stop)

    def test_ai_rejects_non_list_suggestions_as_json_error(self):
        cleaner.summary = lambda: []
        answer = {"result": json.dumps({"suggestions": {"path": "~/example"}})}
        with mock.patch.object(cleaner.subprocess, "run", return_value=subprocess.CompletedProcess(
                [], 0, json.dumps(answer), "")):
            result, code = run_reply("ai")
        self.assertEqual(code, 1)
        self.assertFalse(result["ok"])
        self.assertIn("wasn't the list", result["error"])

    def test_ai_sanitizes_records_and_filters_paths_to_summary_and_protection(self):
        safe = self.home / "old-cache"
        safe.write_text("safe candidate")
        protected = self.home / ".dotfiles"
        protected.mkdir()
        (protected / "secret").write_text("keep")
        outside = self.root / "outside"
        outside.mkdir()
        (self.home / "escape").symlink_to(outside, target_is_directory=True)
        items = [
            {"path": "~/old-cache", "kind": "file", "mb": 5, "days": 365},
            {"path": "~/.dotfiles/secret", "kind": "file", "mb": 1, "days": 90},
            {"path": "~/escape", "kind": "dir", "mb": 20, "days": 300},
        ]
        cleaner.summary = lambda: items
        answer = {"result": json.dumps({"suggestions": [
            None,
            {"path": 7, "why": "wrong path type"},
            {"path": "~/not-in-summary", "why": "invented"},
            {"path": "~/.dotfiles/secret", "why": "protected"},
            {"path": "~/escape", "why": "outside through symlink"},
            {"path": "~/old-cache", "why": 42, "risk": {"level": "high"}},
        ]})}
        with mock.patch.object(cleaner.subprocess, "run", return_value=subprocess.CompletedProcess(
                [], 0, json.dumps(answer), "")) as claude:
            result, code = run_reply("ai", "sonnet")
        self.assertEqual(code, 0)
        self.assertEqual(result, {"ok": True, "suggestions": [
            {"path": "~/old-cache", "size": 5 * 1048576, "days": 365, "kind": "file", "why": "", "risk": "low"},
        ]})
        self.assertEqual(claude.call_args.kwargs["timeout"], 240)
        self.assertEqual(claude.call_args.kwargs["cwd"], str(self.cache))
        self.assertEqual(json.loads(self.context.read_text()), items)

    def test_ai_reports_claude_permission_failure(self):
        cleaner.summary = lambda: []
        with mock.patch.object(cleaner.subprocess, "run", side_effect=PermissionError("permission denied")):
            result, code = run_reply("ai")
        self.assertEqual(code, 1)
        self.assertIn("could not start claude", result["error"])

    def test_corrupt_trash_context_fails_closed_without_calling_gio(self):
        for raw in ("{", "{}", "[1]", '[{"path": 5}]', '[{"other": "~/candidate"}]'):
            with self.subTest(raw=raw):
                self.context.parent.mkdir(parents=True, exist_ok=True)
                self.context.write_text(raw)
                with mock.patch.object(subprocess, "run") as command:
                    result, code = run_reply("trash", "~/candidate")
                self.assertEqual(code, 1)
                self.assertFalse(result["ok"])
                command.assert_not_called()

    def test_trash_rejects_protected_and_symlink_escape_paths(self):
        (self.home / ".dotfiles").mkdir()
        outside = self.root / "outside"
        outside.mkdir()
        (self.home / "escape").symlink_to(outside, target_is_directory=True)
        self.context.parent.mkdir(parents=True)
        self.context.write_text(json.dumps([{"path": "~/.dotfiles"}, {"path": "~/escape"}]))
        with mock.patch.object(subprocess, "run") as command:
            result, code = run_reply("trash", "~/.dotfiles", "~/escape")
        self.assertEqual(code, 1)
        self.assertEqual(result["freed"], 0)
        self.assertIn("protected", result["error"])
        command.assert_not_called()

    def test_trash_preserves_partial_freed_bytes_when_gio_fails(self):
        first, second, third = (self.home / name for name in ("one", "two", "three"))
        first.write_bytes(b"first")
        second.write_bytes(b"second")
        third.write_bytes(b"third")
        paths = ["~/one", "~/two", "~/three"]
        self.context.parent.mkdir(parents=True)
        self.context.write_text(json.dumps([{"path": path} for path in paths]))
        results = [subprocess.CompletedProcess([], 0, "", ""),
                   subprocess.CompletedProcess([], 1, "", "gio refused"), None]
        with mock.patch.object(subprocess, "run", side_effect=results) as command:
            result, code = run_reply("trash", *paths)
        self.assertEqual(code, 1)
        self.assertFalse(result["ok"])
        self.assertEqual(result["freed"], len(b"first"))
        self.assertIn("gio refused", result["error"])
        self.assertIn("unavailable or timed out", result["error"])
        self.assertEqual([call.args[0][0] for call in command.call_args_list], ["gio", "gio", "gio"])
        self.assertTrue(all(call.kwargs["timeout"] == 30 for call in command.call_args_list))

    def test_successful_trash_reports_bytes_freed(self):
        path = self.home / "candidate"
        path.write_bytes(b"discard later")
        self.context.parent.mkdir(parents=True)
        self.context.write_text('[{"path":"~/candidate"}]')
        with mock.patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "", "")) as command:
            result, code = run_reply("trash", "~/candidate")
        self.assertEqual((result, code), ({"ok": True, "freed": len(b"discard later")}, 0))
        command.assert_called_once()
        self.assertEqual(command.call_args.args[0], ["gio", "trash", str(path)])
        self.assertEqual(command.call_args.kwargs["timeout"], 30)

    def test_probe_failures_remain_unknown_and_plan_requires_orphan_query(self):
        for result in (None, subprocess.CompletedProcess([], 1, "", "pacman failed")):
            with mock.patch.object(subprocess, "run", return_value=result) as command:
                self.assertEqual(cleaner.probe("orphans"), 0)
            self.assertEqual(command.call_args.kwargs["timeout"], 15)

        with mock.patch.object(subprocess, "run", return_value=None) as command:
            result, code = run_reply("plan", "orphans")
        self.assertEqual(code, 1)
        self.assertFalse(result["ok"])
        self.assertIn("pacman is unavailable or timed out", result["error"])
        command.assert_called_once()
        self.assertEqual(command.call_args.args[0], ["pacman", "-Qdtq"])
        self.assertEqual(command.call_args.kwargs["timeout"], 15)

    def test_summary_uses_bounded_du_and_find_and_reports_command_failure(self):
        big = self.home / "big"
        big.mkdir()
        large = big / "large.bin"
        large.write_bytes(b"x")
        du = subprocess.CompletedProcess([], 0, f"0\t{self.home}\n104857600\t{big}\n", "")
        find = subprocess.CompletedProcess([], 0, f"209715200\t{large}\n", "")
        with mock.patch.object(subprocess, "run", side_effect=[du, find]) as command:
            result = cleaner.summary()
        self.assertEqual([item["path"] for item in result], ["~/big/large.bin", "~/big"])
        self.assertEqual([call.args[0][0] for call in command.call_args_list], ["du", "find"])
        self.assertTrue(all(call.kwargs["timeout"] == 120 for call in command.call_args_list))

        with mock.patch.object(subprocess, "run", return_value=None):
            error, code = run_reply("ai")
        self.assertEqual(code, 1)
        self.assertIn("du is unavailable or timed out", error["error"])


if __name__ == "__main__":
    unittest.main()
