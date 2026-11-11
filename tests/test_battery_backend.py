"""Exercise battery sysfs writes against an isolated fixture tree."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import shutil
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "packages/quickshell/shell/scripts/battery.sh"


@unittest.skipUnless(shutil.which("jq"), "jq is installed by setup; backend tests need it")
class BatteryBackend(unittest.TestCase):
    def run_backend(self, root: Path, *args: str) -> dict:
        script = root / "battery.sh"
        source = SCRIPT.read_text().replace("/sys/", f"{root}/sys/")
        script.write_text(source)
        result = subprocess.run(
            ["bash", str(script), *args], capture_output=True, text=True, check=True,
        )
        return json.loads(result.stdout)

    def test_profile_write_succeeds(self):
        with tempfile.TemporaryDirectory(prefix="shell-battery-backend-") as tmp:
            root = Path(tmp)
            profile = root / "sys/firmware/acpi/platform_profile"
            profile.parent.mkdir(parents=True)
            profile.write_text("balanced")

            self.assertEqual(self.run_backend(root, "--profile", "quiet"), {"ok": True})
            self.assertEqual(profile.read_text(), "quiet")

    def test_threshold_write_failure_is_reported_as_json(self):
        with tempfile.TemporaryDirectory(prefix="shell-battery-backend-") as tmp:
            root = Path(tmp)
            battery = root / "sys/class/power_supply/BAT0"
            battery.mkdir(parents=True)
            (battery / "type").write_text("Battery")
            (battery / "charge_control_end_threshold").mkdir()

            self.assertEqual(self.run_backend(root, "--threshold", "80"), {
                "ok": False,
                "error": "permission denied: run ./install.py system install (quickshell-power)",
            })


if __name__ == "__main__":
    unittest.main()
