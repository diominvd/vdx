"""Clipboard history backend handles paths and command failures safely."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "packages/quickshell/shell/scripts/clipboard.sh"
BASH = shutil.which("bash") or "/usr/bin/bash"


class ClipboardBackend(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="clipboard backend ")
        self.root = Path(self.tmp.name)
        self.data = self.root / "data with spaces"
        self.bin = self.root / "fake commands"
        self.bin.mkdir()
        self.args_log = self.root / "wl-copy args"
        self.copy_log = self.root / "wl-copy data"
        self._write_command("wl-paste", '''#!/usr/bin/env bash
if [[ ${1:-} == --list-types ]]; then
  printf '%s\\n' "${FAKE_TYPES:-text/plain}"
  exit 0
fi
exit 2
''')
        self._write_command("wl-copy", '''#!/usr/bin/env bash
printf '%s\\n' "$*" > "$FAKE_WL_COPY_ARGS"
cat > "$FAKE_WL_COPY_DATA"
exit "${FAKE_WL_COPY_EXIT:-0}"
''')
        self.env = os.environ.copy()
        self.env.update({
            "XDG_DATA_HOME": str(self.data),
            "PATH": str(self.bin) + os.pathsep + os.environ.get("PATH", ""),
            "FAKE_WL_COPY_ARGS": str(self.args_log),
            "FAKE_WL_COPY_DATA": str(self.copy_log),
        })

    def tearDown(self):
        self.tmp.cleanup()

    def _write_command(self, name, body):
        path = self.bin / name
        path.write_text(body)
        path.chmod(0o700)
        return path

    def run_cli(self, *args, data=b"", env=None):
        child_env = self.env.copy()
        child_env.update(env or {})
        return subprocess.run([BASH, str(SCRIPT), *args], input=data,
                              capture_output=True, env=child_env, check=False)

    def json_reply(self, result):
        return json.loads(result.stdout)

    def entry_dir(self):
        return self.data / "clipboard"

    def test_store_list_copy_delete_clear_for_text_and_image(self):
        text = b"meeting notes\nwith spaces\n"
        result = self.run_cli("store", data=text)
        self.assertEqual((result.returncode, result.stdout), (0, b"stored\n"))
        text_id = hashlib.sha1(text).hexdigest()[:16]
        rows = self.json_reply(self.run_cli("list"))
        self.assertEqual(len(rows), 1)
        self.assertEqual((rows[0]["id"], rows[0]["kind"], rows[0]["preview"]),
                         (text_id, "text", text.decode()[:400]))
        self.assertTrue(Path(rows[0]["path"]).is_file())
        self.assertEqual(self.run_cli("copy", text_id).returncode, 0)
        self.assertEqual(self.args_log.read_text(), "\n")
        self.assertEqual(self.copy_log.read_bytes(), text)

        image = b"fake png payload"
        result = self.run_cli("store", data=image, env={"FAKE_TYPES": "image/png"})
        self.assertEqual((result.returncode, result.stdout), (0, b"stored\n"))
        image_id = hashlib.sha1(image).hexdigest()[:16]
        image_rows = self.json_reply(self.run_cli("list"))
        image_row = next(row for row in image_rows if row["id"] == image_id)
        self.assertEqual((image_row["kind"], image_row["preview"]), ("image", ""))
        self.run_cli("copy", image_id)
        self.assertEqual(self.args_log.read_text(), "--type image/png\n")
        self.assertEqual(self.copy_log.read_bytes(), image)

        self.assertEqual(self.json_reply(self.run_cli("delete", text_id)), {"ok": True})
        self.assertEqual([row["id"] for row in self.json_reply(self.run_cli("list"))], [image_id])
        self.assertEqual(self.json_reply(self.run_cli("clear")), {"ok": True})
        self.assertEqual(self.json_reply(self.run_cli("list")), [])

    def test_trim_keeps_newest_entries_when_data_path_contains_spaces(self):
        history = self.entry_dir()
        history.mkdir(parents=True)
        paths = []
        for index in range(3):
            path = history / f"{index + 1}-000000000000000{index}.txt"
            path.write_text(str(index))
            os.utime(path, (100 + index, 100 + index))
            paths.append(path)
        result = self.run_cli("limit", "2")
        self.assertEqual((result.returncode, self.json_reply(result)), (0, {"ok": True}))
        self.assertEqual([p.exists() for p in paths], [False, True, True])
        rows = self.json_reply(self.run_cli("list"))
        self.assertEqual([row["id"] for row in rows], ["0000000000000002", "0000000000000001"])
        self.assertTrue(all(" " in row["path"] for row in rows))

    def test_copy_failures_missing_commands_and_invalid_ids_are_json_errors(self):
        for args in (("copy",), ("copy", "../../etc/passwd"), ("delete",), ("delete", "bad")):
            with self.subTest(args=args):
                result = self.run_cli(*args)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(json.loads(result.stdout)["ok"])

        payload = b"clipboard payload"
        self.run_cli("store", data=payload)
        entry_id = hashlib.sha1(payload).hexdigest()[:16]
        failed = self.run_cli("copy", entry_id, env={"FAKE_WL_COPY_EXIT": "9"})
        self.assertNotEqual(failed.returncode, 0)
        self.assertFalse(self.json_reply(failed)["ok"])

        minimal_path = self.root / "minimal path"
        minimal_path.mkdir()
        shutil.copy2(shutil.which("mkdir"), minimal_path / "mkdir")
        missing_env = self.env | {"PATH": str(minimal_path)}
        absent = self.run_cli("copy", entry_id, env=missing_env)
        self.assertNotEqual(absent.returncode, 0)
        self.assertFalse(self.json_reply(absent)["ok"])

    def test_delete_and_clear_report_removal_failures(self):
        history = self.entry_dir()
        history.mkdir(parents=True)
        entry_id = "0123456789abcdef"
        (history / f"123-{entry_id}.txt").write_text("entry")
        failing_bin = self.root / "failing rm"
        failing_bin.mkdir()
        self._write_command("rm", "#!/usr/bin/env bash\nexit 1\n")
        shutil.copy2(self.bin / "rm", failing_bin / "rm")
        env = {"PATH": str(failing_bin) + os.pathsep + self.env["PATH"]}
        for args in (("delete", entry_id), ("clear",)):
            with self.subTest(args=args):
                result = self.run_cli(*args, env=env)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.json_reply(result)["ok"])

    def test_limit_bounds_and_corrupt_saved_value_falls_back_to_100(self):
        for value in ("0", "10001", "1.5", "", "999999999999999999999"):
            with self.subTest(value=value):
                result = self.run_cli("limit", value)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(self.json_reply(result)["ok"])

        history = self.entry_dir()
        history.mkdir(parents=True, exist_ok=True)
        (history / "limit").write_text("broken\n")
        for index in range(101):
            (history / f"{index:03d}-{index:016x}.txt").write_text(str(index))
        result = self.run_cli("store", data=b"one more")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        entries = list(history.glob("*.txt"))
        self.assertEqual(len(entries), 100)

    def test_failed_store_cleans_its_temporary_file(self):
        temp = self.root / "temporary files"
        temp.mkdir()
        failing_bin = self.root / "failing commands"
        failing_bin.mkdir()
        sha = self._write_command("sha1sum", "#!/usr/bin/env bash\nexit 1\n")
        shutil.copy2(sha, failing_bin / "sha1sum")
        result = self.run_cli("store", data=b"payload", env={
            "TMPDIR": str(temp),
            "PATH": str(failing_bin) + os.pathsep + self.env["PATH"],
        })
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.json_reply(result)["ok"])
        self.assertEqual(list(temp.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
