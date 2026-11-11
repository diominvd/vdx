"""music.sh: a station and the music share MPD's one queue and replace each other; --status names the
source; --listen reports every MPD event, also the ones that come while it reads the state. mpc is a
stand-in that logs its calls."""

from __future__ import annotations

import json
import os
import select
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "packages/quickshell/shell/scripts/music.sh"

# the queue: two tracks, the second playing at 1:05; the station is "http://r/love"
FAKE_MPC = r"""#!/bin/bash
echo "mpc $*" >> "$FAKE_LOG"
case "$*" in
  "-q add") cat >> "$FAKE_ADDED" ;;
  "current -f %file%") echo "$FAKE_FILE" ;;
  current\ -f\ *) printf '%s\tSong\tBand\tAlbum\t2024-05-01\t\n' "$FAKE_FILE" ;;
  playlist\ -f\ *) printf '1\ta.mp3\tFirst\tOne\tA1\t2023\t2:00\n2\tdir/b.flac\t\tTwo\t\t\t3:20\n' ;;
  "status") ;;
  "playlist") echo "One - First" ;;
  status\ *) if [[ "$*" == *songpos*currenttime* && "$*" != *state* ]]; then printf '2\t1:05\n'
             else printf '%s\t2\t2\t1:05\t3:20\toff\toff\toff\n' "$(cat "$FAKE_STATE")"; fi ;;
  # three events on one connection, the state changed before each
  "idleloop player playlist options") for s in paused stopped playing; do sleep 0.2; echo "$s" > "$FAKE_STATE"; echo player; done
                                      exec sleep 30 ;;
esac
exit 0
"""


@unittest.skipUnless(shutil.which("jq"), "jq is installed by setup; backend tests need it")
class MusicScript(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        home = self.tmp / "home"
        (home / ".config/scripts/radio").mkdir(parents=True)
        (home / ".config/scripts/radio/stations.json").write_text(
            json.dumps({"love": {"name": "Love Radio", "url": "http://r/love"}}))
        (self.tmp / "bin").mkdir()
        mpc = self.tmp / "bin/mpc"
        mpc.write_text(FAKE_MPC)
        mpc.chmod(0o755)
        self.log = self.tmp / "log"
        self.added = self.tmp / "added"
        self.state = self.tmp / "state"

    def env(self, playing="dir/b.flac", state="playing"):
        (self.tmp / "mpd-state").write_text(state)
        return {**os.environ, "HOME": str(self.tmp / "home"), "XDG_STATE_HOME": str(self.state),
                "PATH": f"{self.tmp / 'bin'}:{os.environ['PATH']}", "FAKE_LOG": str(self.log),
                "FAKE_ADDED": str(self.added), "FAKE_FILE": playing, "FAKE_STATE": str(self.tmp / "mpd-state")}

    def run_script(self, *args, **kw):
        out = subprocess.run(["bash", str(SCRIPT), *args], env=self.env(**kw), capture_output=True,
                             text=True, check=True).stdout
        return json.loads(out.strip().splitlines()[-1])

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    # ---- a station and the music share MPD's one queue: each replaces the other ----
    def test_a_station_replaces_the_queue(self):
        self.assertTrue(self.run_script("--radio", "love")["ok"])
        calls = self.calls()
        self.assertEqual([c for c in calls if c.startswith("mpc -q ")],
                         ["mpc -q clear", "mpc -q add http://r/love", "mpc -q play"])

    def test_status_names_the_source(self):
        self.assertEqual(self.run_script("--status", playing="http://r/love")["source"], "radio")
        self.assertEqual(self.run_script("--status", playing="dir/b.flac")["source"], "likes")
        self.assertEqual(self.run_script("--status", playing="/home/x/a.mp3")["source"], "files")

    def test_music_over_a_station_replaces_it(self):
        music = self.tmp / "music"
        music.mkdir()
        (music / "x.mp3").write_text("")
        self.assertTrue(self.run_script("--files-play", str(music), playing="http://r/love")["ok"])
        self.assertIn("mpc -q clear", self.calls())

    def test_on_plays_what_the_queue_kept(self):
        self.assertTrue(self.run_script("--on")["ok"])
        self.assertIn("mpc -q play", self.calls())

    # ---- listening ----
    def test_listen_reports_every_event(self):
        proc = subprocess.Popen(["bash", str(SCRIPT), "--listen"], env=self.env(), stdout=subprocess.PIPE, text=True)
        self.addCleanup(proc.stdout.close)
        self.addCleanup(proc.wait)
        self.addCleanup(proc.kill)
        states, deadline = [], time.time() + 5
        while len(states) < 4 and time.time() < deadline:
            if select.select([proc.stdout], [], [], 0.1)[0]:
                states.append(json.loads(proc.stdout.readline())["state"])
        self.assertEqual(states, ["playing", "paused", "stopped", "playing"])


if __name__ == "__main__":
    unittest.main()
