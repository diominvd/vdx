"""Numbered Zellij sessions reserve names even before the server lists them."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SESSION = ROOT / "packages/zellij/session.py"


class Zellij(unittest.TestCase):
    def test_numbered_sessions_reserve_names_and_ignore_random_names(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            fake = work / "zellij"
            fake.write_text("#!" + sys.executable + "\n" + '''import json, os, sys
from pathlib import Path
if sys.argv[1] == 'list-sessions':
    print('1\\n3\\nrandom-name')
else:
    with Path(os.environ['SESSION_CALLS']).open('a') as log:
        log.write(json.dumps(sys.argv[1:])+'\\n')
''')
            fake.chmod(0o755)
            calls = work / "calls"
            env = os.environ | {"PATH": str(work), "XDG_STATE_HOME": str(work / "state"),
                                "ZELLIJ_SESSION_NAME": "1", "SESSION_CALLS": str(calls)}
            for _ in range(2):
                subprocess.run([sys.executable, str(SESSION), "new"], env=env, check=True,
                               capture_output=True, text=True, timeout=5)
            self.assertEqual([json.loads(line) for line in calls.read_text().splitlines()], [
                ["--session", "1", "action", "switch-session", "4"],
                ["--session", "1", "action", "switch-session", "5"],
            ])
