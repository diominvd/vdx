"""Run production list consumers with JSON fixtures, without backend actions."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


CONSUMERS = [
    ("modules/wifi/WifiService.qml", "id: networksProc", "networks", True),
    ("modules/wifi/WifiService.qml", 'path: Quickshell.shellDir + "/modules/wifi/dns_providers.json"', "dnsProviders", False),
    ("modules/mpd/MpdService.qml", "id: queueProc", "queue", True),
    ("modules/radio/RadioService.qml", "id: stationsProc", "stations", True),
    ("modules/ai/ClaudeService.qml", "id: sessionsProc", "sessions", True),
    ("modules/mihomo/MihomoService.qml", "id: providersProc", "providers", True),
    ("modules/mihomo/MihomoService.qml", "id: nodesProc", "nodes", True),
    ("modules/notifications/NotificationsService.qml", "id: listProc", "notifications", True),
]


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class ListReplies(unittest.TestCase):
    def consume(self, payload):
        with tempfile.TemporaryDirectory(prefix="shell-list-replies-") as tmp:
            root = Path(tmp)
            (root / "kit").mkdir()
            (root / "mpd").mkdir()
            shutil.copy(SHELL / "kit/reply.js", root / "kit/reply.js")
            mpd = (SHELL / "modules/mpd/MpdService.qml").read_text()
            (root / "mpd/MpdService.qml").write_text(
                'pragma Singleton\nimport QtQuick\nimport "../kit/reply.js" as Reply\nQtObject {\n'
                + qml_function(mpd, "parseList") + '\n}\n')
            objects = []
            for index, (file, marker, field, _) in enumerate(CONSUMERS):
                source = (SHELL / file).read_text()
                start = source.index(marker)
                handler = "    onLoaded:" if "dns_providers" in marker else "      onStreamFinished:"
                position = source.index(handler, start)
                line = source[position:].splitlines()[0]
                block = qml_block(source[position:], handler) if line.rstrip().endswith("{") else line
                body = block.split(":", 1)[1].replace("text()", "text")
                helpers = ""
                if field in ("queue", "stations"):
                    validator, acceptor = ("validQueue", "acceptQueue") if field == "queue" else ("validStations", "acceptStations")
                    helpers = qml_function(source, validator) + "\n" + qml_function(source, acceptor)
                    body = "root." + acceptor + "(MpdService.parseList(text));"
                elif field == "sessions":
                    helpers = "\n".join(qml_function(source, name) for name in ("record", "finite", "validSessions"))
                elif field in ("providers", "nodes"):
                    acceptor = "acceptProviders" if field == "providers" else "acceptNodes"
                    helpers = qml_function(source, acceptor)
                    suffix = ", provider" if field == "nodes" else ""
                    body = "root." + acceptor + "(Reply.parseList(text, null)" + suffix + ");"
                objects.append('''  Scope {
    QtObject {
      id: root
      property string text: ''' + json.dumps(payload) + '''
      property var ''' + field + ''': [{old: true}]
      property string error: ""
      property string networkError: ""
      property bool serviceOn: true
      property string nodesWantedProvider: ""
      property string provider: ""
      property string currentProvider: ""
      function refreshNodes() {}
      function ingest(list) { notifications = list; }
      function parseList(text) { return MpdService.parseList(text); }
      ''' + helpers + '''
      function read() { ''' + body + ''' }
    }
    Component.onCompleted: { root.read(); results.values[''' + str(index) + '''] = root.''' + field + '''; }
  }
''')
            objects = [block.replace("id: root", f"id: consumer{index}").replace("root.", f"consumer{index}.")
                       for index, block in enumerate(objects)]
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import "mpd"
import "kit/reply.js" as Reply
Scope {
  QtObject { id: results; property var values: [] }
''' + "\n".join(objects) + '''
  Timer { interval: 20; running: true; onTriggered: {
    console.warn("LIST_RESULT:" + JSON.stringify(results.values)); Qt.quit();
  } }
}
''')
            output = run_quickshell(root)
            lines = [line.split("LIST_RESULT:", 1)[1] for line in output.splitlines() if "LIST_RESULT:" in line]
            self.assertEqual(len(lines), 1, output)
            return json.loads(lines[0])

    def test_valid_arrays_reach_all_list_consumers(self):
        rows = [{"name": "first", "ssid": "network", "key": "station", "pos": 1,
                 "artist": "artist", "title": "title", "genre": "genre", "about": "about",
                 "cwd": "/project", "status": "busy", "version": "1", "started": 1,
                 "nodes": 1, "alive": True, "delay": 10, "signal": 75, "secure": True, "active": False, "saved": True}]
        self.assertEqual(self.consume(json.dumps(rows)), [rows] * len(CONSUMERS))

    def test_empty_arrays_reach_each_consumer(self):
        self.assertEqual(self.consume("[]"), [[]] * len(CONSUMERS))

    def test_error_objects_and_malformed_replies_never_become_list_models(self):
        expected = [[{"old": True}] if retain else [] for _, _, _, retain in CONSUMERS]
        for payload in ('{"ok":false,"error":"offline"}', "null", "bad JSON"):
            with self.subTest(payload=payload):
                self.assertEqual(self.consume(payload), expected)
