"""The backups' backend (packages/quickshell/shell/scripts/backup.py): setup, runs,
snapshots, restore, the package plan and the timer — with a fake restic and
systemctl on PATH, in a sandbox HOME."""

from __future__ import annotations

import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "packages/quickshell/shell/scripts/backup.py"

# restic, reduced to what backup.py calls: the repository is a folder with a marker file
FAKE_RESTIC = '''#!/usr/bin/env python3
import json, os, sys
args = sys.argv[1:]
repo = args[args.index("-r") + 1]
rest = args[:args.index("-r")] + args[args.index("-r") + 2:]
rest = rest[:rest.index("--password-file")] + rest[rest.index("--password-file") + 2:]
cmd, a = rest[0], rest[1:]
here = lambda *p: os.path.join(repo, *p)
if cmd == "init":
    if os.path.exists(here("config")):
        print("Fatal: config file already exists", file=sys.stderr); sys.exit(1)
    os.makedirs(repo, exist_ok=True); open(here("config"), "w").write("c"); sys.exit(0)
if cmd == "cat":
    sys.exit(0 if os.path.exists(here("config")) else 1)
if cmd == "backup":
    print(json.dumps({"message_type": "status", "percent_done": 0.5}))
    print(json.dumps({"message_type": "summary", "snapshot_id": "abcdef1234567890", "total_bytes_processed": 2048}))
    open(here("snaps"), "a").write("abcdef12 2026-10-17T03:00:01.123456789+03:00 /home/x\\n")
    sys.exit(0)
if cmd == "snapshots":
    rows = [l.split(" ", 2) for l in open(here("snaps")).read().splitlines() if l] if os.path.exists(here("snaps")) else []
    print(json.dumps([{"id": r[0] + "0" * 24, "short_id": r[0], "time": r[1], "tags": ["auto"], "paths": [r[2]], "summary": {"total_bytes_processed": 2048}} for r in rows]))
    sys.exit(0)
if cmd == "restore":
    target = a[a.index("--target") + 1]
    for p in [a[i + 1] for i, x in enumerate(a) if x == "--include"]:
        dst = os.path.join(target, p.lstrip("/")); os.makedirs(os.path.dirname(dst), exist_ok=True)
        open(dst, "w").write(os.environ.get("FAKE_LIST", "data"))
    sys.exit(0)
if cmd == "check":
    print("no errors were found"); sys.exit(0)
sys.exit(0)  # forget
'''

FAKE_SYSTEMCTL = "#!/bin/sh\nexit 0\n"


class Backup(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name) / "home"
        self.bin = Path(self.tmp.name) / "bin"
        self.home.mkdir()
        self.bin.mkdir()
        self.repo = Path(self.tmp.name) / "repo"
        # a run notifies by default: without a stand-in the tests toast on the real desktop
        for name, text in (("restic", FAKE_RESTIC), ("systemctl", FAKE_SYSTEMCTL), ("notify-send", "#!/bin/sh\nexit 0\n")):
            path = self.bin / name
            path.write_text(text)
            path.chmod(path.stat().st_mode | stat.S_IXUSR)
        self.env = dict(os.environ, HOME=str(self.home), PATH=f"{self.bin}:{os.environ['PATH']}")

    def tearDown(self):
        self.tmp.cleanup()

    def cli(self, *args, json_out=True, env=None):
        cmd = [sys.executable, str(SCRIPT)] + (["--json"] if json_out else []) + list(args)
        proc = subprocess.run(cmd, capture_output=True, text=True, env=dict(self.env, **(env or {})))
        if not json_out:
            return proc
        replies = [json.loads(l) for l in proc.stdout.splitlines() if l.strip() and "progress" not in l]
        return replies[-1], proc

    def setup_repo(self):
        reply, _ = self.cli("init", "--repo", str(self.repo))
        self.assertTrue(reply["ok"], reply)

    def test_init_makes_a_private_password_and_saves_the_repository(self):
        self.setup_repo()
        password = self.home / ".local/state/dotfiles/restic/password"
        self.assertEqual(stat.S_IMODE(password.stat().st_mode), 0o600)
        config = json.loads((password.parent / "config.json").read_text())
        self.assertEqual(config["repo"], str(self.repo))

    def test_init_refuses_a_missing_drive_folder(self):
        reply, _ = self.cli("init", "--repo", str(self.tmp.name) + "/no/such/drive/backups")
        self.assertFalse(reply["ok"])
        self.assertIn("mounted", reply["error"])
        self.assertFalse((self.home / ".local/state/dotfiles/restic/password").exists())

    def test_run_streams_progress_then_one_reply(self):
        self.setup_repo()
        proc = subprocess.run([sys.executable, str(SCRIPT), "--json", "run"], capture_output=True, text=True, env=self.env)
        lines = proc.stdout.splitlines()
        self.assertEqual(json.loads(lines[0]), {"progress": 50})
        reply = json.loads(lines[-1])
        self.assertTrue(reply["ok"])
        self.assertEqual(reply["snapshot"], "abcdef12")
        self.assertIn("Backed up", reply["message"])

    def test_a_manual_run_notifies_when_notify_is_on(self):
        self.setup_repo()
        log = Path(self.tmp.name) / "notified"
        send = self.bin / "notify-send"
        send.write_text(f'#!/bin/sh\necho "$@" >> {log}\n')
        send.chmod(send.stat().st_mode | stat.S_IXUSR)
        subprocess.run([sys.executable, str(SCRIPT), "--json", "run"], capture_output=True, text=True, env=self.env)
        self.assertIn("Backup done", log.read_text())

    def test_snapshots_list_and_last_run(self):
        self.setup_repo()
        self.cli("run")
        reply, _ = self.cli("snapshots")
        self.assertEqual(reply["snapshots"][0]["short"], "abcdef12")
        # 03:00:01.123456789 at +03:00 is 00:00:01.123456 UTC: the stamp keeps microseconds
        self.assertAlmostEqual(reply["snapshots"][0]["ts"], datetime(2026, 10, 17, 0, 0, 1, 123456, tzinfo=UTC).timestamp(), places=6)
        status, _ = self.cli("status")
        self.assertTrue(status["configured"])
        self.assertTrue(status["last"]["ok"])

    def test_restore_goes_to_a_new_folder_and_never_over_one(self):
        self.setup_repo()
        target = Path(self.tmp.name) / "out"
        reply, _ = self.cli("restore", "abcdef12", "--include", "/home/x/a.txt", "--target", str(target))
        self.assertTrue(reply["ok"], reply)
        self.assertTrue((target / "home/x/a.txt").exists())
        again, _ = self.cli("restore", "abcdef12", "--target", str(target))
        self.assertFalse(again["ok"])

    def test_packages_plan_rebuilds_packages_services_and_groups(self):
        self.setup_repo()
        self.cli("run")
        env = {"FAKE_LIST": "# native\nbash\ngit\n# foreign\nyay-bin\n# services\nNetworkManager.service\n# groups\nvideo\n"}
        reply, _ = self.cli("packages", "abcdef12", env=env)
        self.assertTrue(reply["ok"], reply)
        self.assertEqual(reply["steps"][0]["command"], "pacman -S --needed --noconfirm bash git")
        self.assertIn("NetworkManager.service", reply["script"])
        self.assertIn("systemctl enable", reply["script"])
        self.assertIn("usermod -aG", reply["script"])
        self.assertEqual(reply["aur"], ["yay-bin"])
        aur, _ = self.cli("aur", "abcdef12", env=env)
        self.assertEqual(aur["aur"], ["yay-bin"])
        bad, _ = self.cli("packages", "abcdef12", env={"FAKE_LIST": "# native\nbash; rm -rf /\n"})
        self.assertFalse(bad["ok"])

    def test_config_set_merges_and_validates(self):
        reply, _ = self.cli("config", "set", '{"keep": {"daily": 3}, "sources": {"etc": false}}')
        self.assertTrue(reply["ok"])
        self.assertEqual(reply["config"]["keep"], {"on": True, "daily": 3, "weekly": 4, "monthly": 6})
        self.assertFalse(reply["config"]["sources"]["etc"])
        bad, _ = self.cli("config", "set", '{"schedule": {"mode": "hourly"}}')
        self.assertFalse(bad["ok"])

    def test_schedule_writes_the_timer_and_off_removes_it(self):
        self.setup_repo()
        reply, _ = self.cli("schedule", "daily", "--time", "04:30")
        self.assertTrue(reply["ok"], reply)
        timer = self.home / ".config/systemd/user/dotfiles-backup.timer"
        self.assertIn("OnCalendar=*-*-* 04:30:00", timer.read_text())
        self.assertIn("run --auto", (timer.parent / "dotfiles-backup.service").read_text())
        off, _ = self.cli("schedule", "off")
        self.assertTrue(off["ok"])
        self.assertFalse(timer.exists())

    def test_guide_names_the_repository_and_the_restore_steps(self):
        self.setup_repo()
        reply, _ = self.cli("guide")
        self.assertTrue(reply["ok"])
        text = reply["text"]
        self.assertIn(str(self.repo), text)
        self.assertIn("restore latest --target /mnt/restore", text)
        self.assertIn("--tag root", text)

    def test_schedule_is_kept_without_a_repository_and_starts_with_one(self):
        reply, _ = self.cli("schedule", "daily", "--time", "05:00")
        self.assertTrue(reply["ok"])
        self.assertFalse(reply["running"])
        self.assertIn("once a repository is set", reply["message"])
        timer = self.home / ".config/systemd/user/dotfiles-backup.timer"
        self.assertFalse(timer.exists())
        self.setup_repo()
        self.assertTrue(timer.exists())
        self.assertIn("OnCalendar=*-*-* 05:00:00", timer.read_text())

    def test_text_mode_prints_a_sentence(self):
        self.setup_repo()
        proc = self.cli("snapshots", json_out=False)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("No snapshots yet", proc.stdout)


if __name__ == "__main__":
    unittest.main()
