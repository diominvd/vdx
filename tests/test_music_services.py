"""Isolated regression fixtures for MPD, Yandex likes, and radio services."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


MPD = SHELL / "modules/mpd/MpdService.qml"
YANDEX = SHELL / "modules/yandex/YandexService.qml"
RADIO = SHELL / "modules/radio/RadioService.qml"


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class MusicServices(unittest.TestCase):
    def run_fixture(self, root: Path, source: str) -> str:
        (root / "kit").mkdir(exist_ok=True)
        shutil.copy(SHELL / "kit/reply.js", root / "kit/reply.js")
        (root / "shell.qml").write_text(source)
        return run_quickshell(root)

    def result(self, output: str, marker: str):
        results = [line.split(marker, 1)[1] for line in output.splitlines() if marker in line]
        self.assertEqual(len(results), 1, output)
        return json.loads(results[0])

    def test_mpd_load_while_running_does_not_replace_active_request(self):
        source = MPD.read_text()
        process = qml_block(source, "Process {\n    id: loadProc")
        funcs = "\n".join(qml_function(source, name) for name in ("load", "run", "finishLoad"))
        with tempfile.TemporaryDirectory(prefix="music-mpd-load-") as tmp:
            root = Path(tmp)
            script = root / "backend.sh"
            script.write_text("#!/bin/sh\nsleep 0.25\nprintf '{\"ok\":true}\\n'\n")
            script.chmod(0o700)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property string script: ''' + json.dumps(str(script)) + '''
  property var busy: null
  property string error: ""
  property var original: null
  property var duringSecondLoad: null
  property int phase: 0
  function parse(text) { return Reply.parse(text, "music.sh", null); }
  function refreshQueue() {}
  function refresh() {}
''' + funcs + '\n' + process + '''
  Component.onCompleted: root.load("first", ["--first"])
  Timer { interval: 20; running: true; repeat: true; property int ticks: 0
    onTriggered: {
      ticks++;
      if (root.phase === 0 && loadProc.running) {
        root.original = loadProc.command;
        root.load("second", ["--second"]);
        root.duringSecondLoad = {busy: root.busy, command: loadProc.command};
        root.phase = 1;
      } else if (root.phase === 1 && !loadProc.running) {
        console.warn("MPD_ACTIVE_LOAD:" + JSON.stringify({original:root.original,
          duringSecondLoad:root.duringSecondLoad, finalBusy:root.busy}));
        Qt.quit();
      }
      if (ticks > 200) { console.warn("MPD_LOAD_TIMEOUT"); Qt.quit(); }
    }
  }
}
''')
            self.assertEqual(self.result(output, "MPD_ACTIVE_LOAD:"), {
                "original": ["bash", str(script), "--first"],
                "duringSecondLoad": {"busy": "first", "command": ["bash", str(script), "--first"]},
                "finalBusy": None,
            })

    def test_yandex_failed_like_rolls_back_exact_snapshot_and_retry_succeeds(self):
        source = YANDEX.read_text()
        process = qml_block(source, "Process {\n    id: likeProc").replace(
            "MpdService.error", "root.mpdError").replace("MpdService.parse(text)", "root.parse(text)")
        funcs = "\n".join(qml_function(source, name) for name in ("toggleLike", "finishLike"))
        funcs = funcs.replace("MpdService.error", "root.mpdError").replace(
            'likeProc.command = ["uv", "run", "--script", root.script, like ? "--like" : "--unlike", target];',
            "likeProc.command = root.likeCommand;")
        with tempfile.TemporaryDirectory(prefix="music-yandex-like-") as tmp:
            root = Path(tmp)
            success = root / "like.py"
            success.write_text("import time\ntime.sleep(0.08)\nprint('{\"ok\":true}')\n")
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property var liked: ["keep", "other"]
  property string trackId: "target"
  property string mpdError: ""
  property var likeCommand: ["/no/such/yandex-like"]
  property int phase: 0
  property int ticks: 0
  property var rolledBack: null
  function parse(text) { return JSON.parse(text); }
''' + funcs + '\n' + process + '''
  Timer { interval: 20; running: true; repeat: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) { root.toggleLike(); root.phase = 1; }
    else if (root.phase === 1 && root.mpdError === "could not start Yandex like request") {
      root.rolledBack = root.liked;
      root.likeCommand = ["''' + str(sys.executable) + '''", "''' + str(success) + '''"];
      root.mpdError = ""; root.toggleLike(); root.phase = 2;
    } else if (root.phase === 2 && !likeProc.running && root.liked.includes("target")) {
      console.warn("YANDEX_LIKE_RETRY:" + JSON.stringify({rolledBack:root.rolledBack,
        liked:root.liked, error:root.mpdError}));
      Qt.quit();
    }
    if (root.ticks > 250) { console.warn("YANDEX_LIKE_TIMEOUT:" + root.mpdError); Qt.quit(); }
  } }
}
''')
            self.assertEqual(self.result(output, "YANDEX_LIKE_RETRY:"), {
                "rolledBack": ["keep", "other"], "liked": ["keep", "other", "target"], "error": "",
            })

    def test_yandex_cover_discards_stale_reply_and_does_not_repeat_same_request(self):
        source = YANDEX.read_text()
        functions = []
        for name in ("refreshCover", "startCover"):
            function = qml_function(source, name).replace("MpdService.source", "root.source")
            function = function.replace('coverProc.command = ["uv", "run", "--script", root.script, "--cover", coverProc.requestId];',
                                        "coverProc.command = root.coverCommandFactory(coverProc.requestId);")
            functions.append(function)
        process = qml_block(source, "Process {\n    id: coverProc").replace(
            "MpdService.source", "root.source").replace("MpdService.trackId", "root.trackId")
        process = process.replace("MpdService.error", "root.mpdError").replace(
            "MpdService.parse(text)", "root.parse(text)")
        with tempfile.TemporaryDirectory(prefix="music-yandex-cover-") as tmp:
            root = Path(tmp)
            script = root / "cover.py"
            log = root / "requests.log"
            script.write_text("import sys,time\nfrom pathlib import Path\n"
                              f"with Path({str(log)!r}).open('a') as f: f.write(sys.argv[1]+'\\n')\n"
                              "time.sleep(0.12 if sys.argv[1] == 'old' else 0.02)\n"
                              "print('{\"ok\":true,\"path\":\"/covers/' + sys.argv[1] + '.jpg\"}')\n")
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property string source: "likes"
  property string trackId: "old"
  property string script: "unused"
  property string cover: ""
  property string coverRequestId: ""
  property string mpdError: ""
  property var coverCommandFactory: function(id) { return ["''' + sys.executable + '''", "''' + str(script) + '''", id]; }
  property int phase: 0
  property int ticks: 0
  function parse(text) { return JSON.parse(text); }
''' + '\n'.join(functions) + '\n' + process + '''
  Component.onCompleted: root.refreshCover()
  Timer { interval: 20; running: true; repeat: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0 && coverProc.running) {
      root.trackId = "new"; root.refreshCover(); root.phase = 1;
    } else if (root.phase === 1 && root.cover === "file:///covers/new.jpg" && !coverProc.running) {
      console.warn("YANDEX_COVER_LATEST:" + JSON.stringify({cover:root.cover, error:root.mpdError}));
      Qt.quit();
    }
    if (root.ticks > 250) { console.warn("YANDEX_COVER_TIMEOUT:" + root.cover + ":" + root.mpdError); Qt.quit(); }
  } }
}
''')
            self.assertEqual(self.result(output, "YANDEX_COVER_LATEST:"), {
                "cover": "file:///covers/new.jpg", "error": "",
            })
            self.assertEqual(log.read_text().splitlines(), ["old", "new"])

    def test_radio_schema_preserves_stations_and_favorites_setting_is_string_filtered(self):
        source = RADIO.read_text()
        self.assertIn('ModuleSettings.strings("music", "favoriteStations", [])', source)
        functions = "\n".join(qml_function(source, name) for name in ("validStations", "acceptStations"))
        with tempfile.TemporaryDirectory(prefix="music-radio-schema-") as tmp:
            root = Path(tmp)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
Scope {
  id: root
  property var stations: [{key:"keep", name:"Keep", genre:"old", about:"old"}]
''' + functions + '''
  Timer { interval: 0; running: true; onTriggered: {
    const old = root.stations;
    const bad = root.acceptStations([{key:"bad",name:"Bad",genre:"x",about:4}]);
    const preserved = root.stations === old;
    const good = root.acceptStations([{key:"new",name:"New",genre:"rock",about:"live"}]);
    console.warn("RADIO_STATIONS:" + JSON.stringify({bad,preserved,good,stations:root.stations}));
    Qt.quit();
  } }
}
''')
            self.assertEqual(self.result(output, "RADIO_STATIONS:"), {
                "bad": False, "preserved": True, "good": True,
                "stations": [{"key": "new", "name": "New", "genre": "rock", "about": "live"}],
            })


if __name__ == "__main__":
    unittest.main()
