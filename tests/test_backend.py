"""Shared command runners preserve output and distinguish required failures."""
from pathlib import Path
import importlib
import subprocess
import sys
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "packages/quickshell/shell/scripts"
sys.path.insert(0, str(SCRIPTS))
backend = importlib.import_module("backend")


class Backend(unittest.TestCase):
    def test_required_missing_timed_out_or_failed_command_raises(self):
        for error in (FileNotFoundError(), subprocess.TimeoutExpired("tool", 1)):
            with self.subTest(error=error), patch.object(subprocess, "run", side_effect=error):
                self.assertIsNone(backend.run(["tool"], timeout=1))
                with self.assertRaisesRegex(RuntimeError, "unavailable or timed out"):
                    backend.run_checked(["tool"], timeout=1)
        with patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 1, "", "denied")):
            with self.assertRaisesRegex(RuntimeError, "tool failed: denied"):
                backend.run_checked(["tool"])

    def test_required_output_is_decoded_without_crashing_on_legacy_bytes(self):
        result = backend.run_checked([sys.executable, "-c", "import os; os.write(1, b'hello\\xff')"])
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "hello\ufffd")


if __name__ == "__main__":
    unittest.main()
