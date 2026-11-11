"""Keep Bluetooth scan replies tied to the bluetoothctl result."""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "packages/quickshell/shell/scripts/bluetooth.sh"


@unittest.skipUnless(shutil.which("jq"), "jq is installed by setup; backend tests need it")
class BluetoothScanBackend(unittest.TestCase):
    def run_scan(self, reply: str) -> tuple[dict, str]:
        with tempfile.TemporaryDirectory() as tmp:
            fake = Path(tmp) / "bluetoothctl"
            args_file = Path(tmp) / "args"
            fake.write_text(
                "#!/bin/sh\nprintf '%s\\n' \"$*\" > \"$SCAN_ARGS\"\n"
                "printf '%s\\n' \"$SCAN_REPLY\"\n"
            )
            fake.chmod(0o755)
            env = os.environ | {
                "PATH": tmp + os.pathsep + os.environ["PATH"],
                "SCAN_REPLY": reply,
                "SCAN_ARGS": str(args_file),
            }
            result = subprocess.run(
                ["bash", str(SCRIPT), "--scan"], capture_output=True, text=True,
                env=env, check=True,
            )
            return json.loads(result.stdout), args_file.read_text().strip()

    def test_scan_start_reply_is_success(self):
        reply, args = self.run_scan("Discovery started")
        self.assertEqual(reply, {"ok": True})
        self.assertEqual(args, "--timeout 8 scan on")

    def test_scan_rejection_is_reported(self):
        reply = "Failed to start discovery: org.bluez.Error.InProgress"
        result, args = self.run_scan(reply)
        self.assertEqual(result, {"ok": False, "error": reply})
        self.assertEqual(args, "--timeout 8 scan on")


if __name__ == "__main__":
    unittest.main()
