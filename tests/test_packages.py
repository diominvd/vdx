"""packages.py: the download's progress is read from the root script's copy
(pacman's own download-* dirs are the alpm user's), and the script carries a
watcher that ends with its shell."""

from __future__ import annotations

import importlib.util
import sys
import subprocess
import os
from unittest.mock import patch
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "packages/quickshell/shell/scripts"
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location("packages", SCRIPTS / "packages.py")
pk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pk)


class Progress(unittest.TestCase):
    def test_counts_finished_and_downloading_once(self):
        with tempfile.TemporaryDirectory() as d:
            cache, watch = Path(d) / "pkg", Path(d) / "watch"
            cache.mkdir()
            (cache / "foo-1.0-1-x86_64.pkg.tar.zst").write_bytes(b"x" * 100)
            # bar is mid-download; foo shows in both for a moment: counted once
            watch.write_text("40 bar-2.0-1-x86_64.pkg.tar.zst.part\n100 foo-1.0-1-x86_64.pkg.tar.zst\n")
            with patch.object(pk, "CACHE", cache), patch.object(pk, "WATCH", watch):
                r = pk.progress(["foo=1.0-1", "bar=2.0-1", "baz=3.0-1"])
        self.assertEqual(r, {"ok": True, "bytes": 140})

    def test_download_script_has_the_watcher(self):
        plan = pk.plan_download(["foo"])
        self.assertTrue(plan["script"].startswith("( while :;"))
        self.assertTrue(plan["script"].endswith("pacman -Syw --noconfirm -- foo"))
        self.assertEqual(plan["steps"][0]["command"], "pacman -Syw --noconfirm -- foo")

    def test_watcher_reports_partial_bytes_and_exits_with_download(self):
        # Run the real shell monitor without root or pacman. A completed
        # command must close its output pipes and leave no monitor behind.
        with tempfile.TemporaryDirectory() as d:
            cache, watch = Path(d) / "pkg", Path(d) / "watch"
            cache.mkdir()
            nested = cache / "download-test"
            nested.mkdir()
            (nested / "foo-1:2.0-1-x86_64.pkg.tar.zst.part").write_bytes(b"x" * 40)
            (cache / "bar-1.0-1-any.pkg.tar.zst.part").write_bytes(b"x" * 20)
            watcher = pk.WATCHER.replace(str(pk.CACHE), str(cache)).replace(str(pk.WATCH), str(watch))
            script = watcher + "sleep 0.7; cat " + str(watch) + "; exit 7"
            result = subprocess.run(["bash", "-c", script], capture_output=True, text=True, timeout=3)
            self.assertEqual(result.returncode, 7, result.stderr)
            watch.write_text(result.stdout)
            with patch.object(pk, "CACHE", cache), patch.object(pk, "WATCH", watch):
                self.assertEqual(pk.progress(["foo=1:2.0-1", "bar=1.0-1"])["bytes"], 60)
            watch.unlink()
            self.assertFalse(Path(str(watch) + ".tmp").exists())


class DownloadSizes(unittest.TestCase):
    def test_uses_same_temporary_database_as_checkupdates(self):
        with patch.dict(os.environ, {"TMPDIR": "/tmp/package-test", "CHECKUPDATES_DB": ""}), patch.object(
                pk, "run", return_value=subprocess.CompletedProcess([], 0, "Name : foo\nDownload Size : 12.00 KiB\n\nName : bar\nDownload Size : 24.00 KiB\n", "")) as run:
            self.assertEqual(pk.download_sizes(["foo", "bar"]), {"foo": 12288, "bar": 24576})
            self.assertEqual(run.call_args.args[0], ["pacman", "-Si", "--dbpath",
                f"/tmp/package-test/checkup-db-{os.getuid()}", "foo", "bar"])
        with patch.dict(os.environ, {"CHECKUPDATES_DB": "/tmp/explicit-db"}):
            self.assertEqual(pk.temp_db(), "/tmp/explicit-db")


if __name__ == "__main__":
    unittest.main()
