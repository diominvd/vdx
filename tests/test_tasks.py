"""Task sampling handles corrupt caches and PID reuse; signals target only PIDs."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "packages/quickshell/shell/scripts"
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location("tasks_backend", SCRIPTS / "tasks.py")
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)


def reply(fn, *args):
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        try:
            fn(*args)
        except SystemExit as exited:
            code = exited.code
        else:
            raise AssertionError("backend did not exit with its reply")
    return code, json.loads(output.getvalue())


class Tasks(unittest.TestCase):
    def test_invalid_signal_targets_never_reach_os_kill(self):
        with patch.object(backend.os, "kill") as kill:
            code, result = reply(backend.cmd_kill, "TERM", ["0", "-1", "-200", "not-a-pid"])
        self.assertEqual(code, 1)
        self.assertEqual(result["killed"], 0)
        kill.assert_not_called()

    def test_signal_partial_failure_and_missing_process(self):
        with patch.object(backend.os, "kill", side_effect=[None, ProcessLookupError(), PermissionError()]) as kill:
            code, result = reply(backend.cmd_kill, "TERM", ["123", "456", "789"])
        self.assertEqual(code, 1)
        self.assertEqual(result["killed"], 2)
        self.assertIn("789", result["error"])
        self.assertEqual([call.args[0] for call in kill.call_args_list], [123, 456, 789])

    def test_signal_os_and_integer_overflow_errors_keep_partial_success(self):
        with patch.object(backend.os, "kill", side_effect=[None, OverflowError(), OSError()]) as kill:
            code, result = reply(backend.cmd_kill, "TERM", ["123", "456", "789"])
        self.assertEqual(code, 1)
        self.assertEqual(result["killed"], 1)
        self.assertIn("456", result["error"])
        self.assertIn("789", result["error"])
        self.assertEqual([call.args[0] for call in kill.call_args_list], [123, 456, 789])

    def test_corrupt_snapshots_reset_sampling_without_crashing(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(backend, "SNAPSHOT", Path(tmp) / "tasks.json"), \
             patch.object(backend, "cpu_times", return_value=(100, 30)), \
             patch.object(backend, "boot_time", return_value=1), \
             patch.object(backend, "meminfo", return_value=(10, 100)), patch.object(backend.os, "scandir", return_value=[]):
            for saved in (None, [], {"boot": 1, "total": "bad"},
                          {"boot": 1, "total": 90, "idle": 20, "procs": []},
                          {"boot": 1, "total": 90, "idle": None, "procs": {}},
                          {"boot": 1, "total": 90, "idle": 20, "procs": {"123": 42}},
                          {"boot": 1, "total": 90, "idle": 20,
                           "procs": {"123": {"jiffies": "bad", "start": 1}}}):
                with self.subTest(saved=saved):
                    backend.SNAPSHOT.write_text(json.dumps(saved))
                    code, result = reply(backend.cmd_list)
                    self.assertEqual(code, 0)
                    self.assertEqual(result["cpu"], 0)

    def test_reused_pid_with_more_jiffies_has_no_previous_process_baseline(self):
        def process(start, jiffies):
            return {"pid": 123, "ppid": 1, "name": "worker", "user": "me", "mine": True,
                    "kernel": False, "jiffies": jiffies, "start": start, "mem": 1, "threads": 1, "cmd": "worker"}

        with tempfile.TemporaryDirectory() as tmp, patch.object(backend, "SNAPSHOT", Path(tmp) / "tasks.json"), \
             patch.object(backend, "cpu_times", side_effect=[(100, 30), (200, 60)]), \
             patch.object(backend, "boot_time", return_value=1), patch.object(backend, "meminfo", return_value=(10, 100)), \
             patch.object(backend.os, "scandir", side_effect=lambda _: [SimpleNamespace(name="123")]), \
             patch.object(backend, "read_proc", side_effect=[process(10, 100), process(20, 200)]):
            reply(backend.cmd_list)
            code, result = reply(backend.cmd_list)
        self.assertEqual(code, 0)
        self.assertEqual(result["procs"][0]["cpu"], 0)

    def test_same_pid_and_starttime_uses_valid_jiffies_delta(self):
        def process(start, jiffies):
            return {"pid": 123, "ppid": 1, "name": "worker", "user": "me", "mine": True,
                    "kernel": False, "jiffies": jiffies, "start": start, "mem": 1,
                    "threads": 1, "cmd": "worker"}

        with tempfile.TemporaryDirectory() as tmp, patch.object(backend, "SNAPSHOT", Path(tmp) / "tasks.json"), \
             patch.object(backend, "cpu_times", side_effect=[(100, 30), (200, 60)]), \
             patch.object(backend, "boot_time", return_value=1), patch.object(backend, "meminfo", return_value=(10, 100)), \
             patch.object(backend.os, "scandir", side_effect=lambda _: [SimpleNamespace(name="123")]), \
             patch.object(backend, "read_proc", side_effect=[process(10, 100), process(10, 120)]):
            reply(backend.cmd_list)
            code, result = reply(backend.cmd_list)
            saved = json.loads(backend.SNAPSHOT.read_text())
        self.assertEqual(code, 0)
        self.assertEqual(result["procs"][0]["cpu"], 20.0)
        self.assertEqual(saved["procs"]["123"], {"jiffies": 120, "start": 10})
        self.assertNotIn("start", result["procs"][0])

    def test_read_proc_parses_starttime_from_stat_field_22(self):
        fields = ["0"] * 20
        fields[0], fields[1], fields[11], fields[12], fields[17], fields[19] = (
            "S", "1", "7", "8", "2", "987654")
        files = {
            "/proc/123/stat": "123 (worker (with spaces)) " + " ".join(fields),
            "/proc/123/statm": "10 4 0 0 0 0 0",
            "/proc/123/cmdline": b"worker\0--arg\0",
        }

        def fake_open(path, mode="r", *args, **kwargs):
            value = files[path]
            return io.BytesIO(value) if "b" in mode else io.StringIO(value)

        with patch("builtins.open", side_effect=fake_open), \
             patch.object(backend.os, "stat", return_value=SimpleNamespace(st_uid=1000)), \
             patch.object(backend, "PAGE", 4096), patch.object(backend, "ME", 1000), \
             patch.object(backend, "user", return_value="tester"):
            proc = backend.read_proc(123)
        self.assertEqual(proc["start"], 987654)
        self.assertEqual(proc["jiffies"], 15)
        self.assertEqual(proc["name"], "worker (with spaces)")

    def test_main_returns_json_for_expected_proc_errors(self):
        with patch.object(backend, "cpu_times", side_effect=OSError("proc unavailable")):
            code, result = reply(backend.main, ["list"])
        self.assertEqual(code, 1)
        self.assertEqual(result, {"ok": False, "error": "proc unavailable"})


if __name__ == "__main__":
    unittest.main()
