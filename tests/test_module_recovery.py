"""Focused recovery checks for Focus and Mihomo service process lifecycles."""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


FOCUS = SHELL / "modules/focus/FocusService.qml"
MIHOMO = SHELL / "modules/mihomo/MihomoService.qml"


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class ModuleRecovery(unittest.TestCase):
    def fixture(self, root: Path, source: str) -> str:
        (root / "kit").mkdir(exist_ok=True)
        shutil.copy(SHELL / "kit/reply.js", root / "kit/reply.js")
        (root / "shell.qml").write_text(source)
        return run_quickshell(root)

    def result(self, output: str, marker: str):
        matches = [line.split(marker, 1)[1] for line in output.splitlines() if marker in line]
        self.assertEqual(len(matches), 1, output)
        return json.loads(matches[0])

    def test_focus_failed_start_and_failed_confirmation_preserve_state_then_retry(self):
        source = FOCUS.read_text()
        functions = "\n".join(qml_function(source, name) for name in
                               ("toggle", "refresh", "finishSet", "finishRead"))
        functions = functions.replace(
            'set.command = ["makoctl", "mode", toggleBefore ? "-r" : "-a", "do-not-disturb"];',
            "set.command = root.setCommand;")
        read_process = qml_block(source, "Process {\n    id: read").replace(
            'command: ["makoctl", "mode"]', "command: root.readCommand")
        set_process = qml_block(source, "Process {\n    id: set")
        with tempfile.TemporaryDirectory(prefix="module-focus-recovery-") as tmp:
            root = Path(tmp)
            set_ok = root / "set.py"
            set_ok.write_text("pass\n")
            read_on = root / "read_on.py"
            read_on.write_text("print('do-not-disturb\\ncustom mode')\n")
            read_empty = root / "read_empty.py"
            read_empty.write_text("pass\n")
            out = self.fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property bool on: true
  property bool busy: false
  property bool toggleBefore: false
  property bool confirming: false
  property bool readQueued: false
  property string error: ""
  property var setCommand: ["/no/such/focus-set"]
  property var readCommand: ["''' + shutil.which("python3") + '''", "''' + str(read_on) + '''"]
''' + functions + '\n' + read_process + '\n' + set_process + '''
  property int phase: 0
  property int ticks: 0
  Timer { interval: 10; running: true; repeat: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0 && !read.running && !root.busy) {
      root.toggle(); root.phase = -1;
    } else if (root.phase === -1 && root.error === "could not start focus mode change") {
      const failedStart = {on:root.on, busy:root.busy};
      root.error = "";
      root.setCommand = ["''' + shutil.which("python3") + '''", "''' + str(set_ok) + '''"];
      root.readCommand = ["/no/such/focus-read"];
      root.toggle(); root.phase = 1;
      root.failedStart = failedStart;
    } else if (root.phase === 1 && root.error === "could not confirm focus mode") {
      const failedRead = {on:root.on, busy:root.busy};
      root.error = "";
      root.readCommand = ["''' + shutil.which("python3") + '''", "''' + str(read_empty) + '''"];
      root.toggle(); root.phase = 2;
      root.failedRead = failedRead;
    } else if (root.phase === 2 && !root.busy && !set.running && !read.running) {
      console.warn("FOCUS_RECOVERY:" + JSON.stringify({failedStart:root.failedStart,
        failedRead:root.failedRead, finalOn:root.on, error:root.error})); Qt.quit();
    }
    if (root.ticks > 300) { console.warn("FOCUS_TIMEOUT:" + JSON.stringify({phase:root.phase,error:root.error,on:root.on,busy:root.busy,setRunning:set.running,readRunning:read.running})); Qt.quit(); }
  } }
  property var failedStart: null
  property var failedRead: null
  Component.onCompleted: root.refresh()
}
''')
            self.assertEqual(self.result(out, "FOCUS_RECOVERY:"), {
                "failedStart": {"on": True, "busy": False},
                "failedRead": {"on": True, "busy": False},
                "finalOn": False,
                "error": "",
            })

    def test_mihomo_schemas_preserve_last_good_state(self):
        source = MIHOMO.read_text()
        funcs = "\n".join(qml_function(source, name) for name in
                            ("finiteNonnegative", "acceptStatus", "acceptProviders",
                             "acceptNodes", "acceptTraffic"))
        with tempfile.TemporaryDirectory(prefix="module-mihomo-schema-") as tmp:
            root = Path(tmp)
            out = self.fixture(root, '''import QtQuick
import Quickshell
Scope {
  id: root
  property bool serviceOn: true
  property bool toggling: false
  property string mode: "rule"
  property string group: "Proxies"
  property string current: "kept"
  property string currentProvider: "stable"
  property int currentDelay: 12
  property var providers: [{name:"stable",nodes:1}]
  property string provider: "stable"
  property string nodesWantedProvider: "stable"
  property var nodes: [{name:"kept",alive:true,delay:12}]
  property real up: 2
  property real down: 3
  property real upTotal: 20
  property real downTotal: 30
  function refreshProviders() {}
  function refreshNodes() {}
''' + funcs + '''
  Timer { interval: 0; running: true; onTriggered: {
    const old = {mode:root.mode, providers:root.providers, nodes:root.nodes, up:root.up};
    const statusBad = root.acceptStatus({service:"on",mode:"global",group:"Proxies",node:"bad",provider:"stable",delay:-1});
    const providersBad = root.acceptProviders([{name:"bad",nodes:"many"}]);
    const nodesBad = root.acceptNodes([{name:"bad",alive:"yes",delay:1}], "stable");
    const trafficBad = root.acceptTraffic({up:99,down:NaN});
    console.warn("MIHOMO_SCHEMA:" + JSON.stringify({statusBad,providersBad,nodesBad,trafficBad,
      unchanged:old.mode===root.mode && old.providers===root.providers && old.nodes===root.nodes && old.up===root.up,
      goodStatus:root.acceptStatus({service:"on",mode:"rule",group:"Proxies",node:"current",provider:"stable",delay:0}),
      goodTraffic:root.acceptTraffic({up:5,down:6})})); Qt.quit();
  } }
}
''')
            self.assertEqual(self.result(out, "MIHOMO_SCHEMA:"), {
                "statusBad": False, "providersBad": False, "nodesBad": False,
                "trafficBad": False, "unchanged": True,
                "goodStatus": True, "goodTraffic": True,
            })

    def test_mihomo_nodes_discards_old_provider_reply_and_loads_latest(self):
        source = MIHOMO.read_text()
        funcs = []
        for name in ("run", "refreshNodes", "startNodes", "acceptNodes"):
            fn = qml_function(source, name)
            if name == "run":
                fn = fn.replace('proc.command = ["bash", root.script].concat(args);',
                                "proc.command = root.commandFactory(args);")
            funcs.append(fn)
        process = qml_block(source, "Process {\n    id: nodesProc")
        with tempfile.TemporaryDirectory(prefix="module-mihomo-nodes-") as tmp:
            root = Path(tmp)
            script = root / "nodes.sh"
            log = root / "requests.log"
            script.write_text('''#!/bin/sh
echo "$2" >> "''' + str(log) + '''"
if [ "$2" = old ]; then sleep 0.15; fi
printf '[{"name":"%s-node","alive":true,"delay":1}]\\n' "$2"
''')
            script.chmod(0o700)
            out = self.fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property bool serviceOn: true
  property string provider: "old"
  property string nodesWantedProvider: ""
  property var nodes: []
  property var commandFactory: function(args) { return ["''' + shutil.which("bash") + '''", "''' + str(script) + '''", args[0], args[1]]; }
  function parse(text) { return Reply.parse(text, "mihomo.sh", null); }
''' + '\n'.join(funcs) + '\n' + process + '''
  property int phase: 0
  property int ticks: 0
  Component.onCompleted: root.refreshNodes()
  Timer { interval: 10; running: true; repeat: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0 && nodesProc.running) {
      root.provider = "new"; root.refreshNodes(); root.phase = 1;
    } else if (root.phase === 1 && !nodesProc.running && root.nodes.length === 1 && root.nodes[0].name === "new-node") {
      console.warn("MIHOMO_NODES_LATEST:" + JSON.stringify({nodes:root.nodes, wanted:root.nodesWantedProvider})); Qt.quit();
    }
    if (root.ticks > 300) { console.warn("MIHOMO_NODES_TIMEOUT:" + JSON.stringify(root.nodes)); Qt.quit(); }
  } }
}
''')
            self.assertEqual(self.result(out, "MIHOMO_NODES_LATEST:"), {
                "nodes": [{"name": "new-node", "alive": True, "delay": 1}], "wanted": "new",
            })
            self.assertEqual(log.read_text().splitlines(), ["old", "new"])

    def test_mihomo_ping_and_update_start_failures_clear_flags_and_retry(self):
        source = MIHOMO.read_text()
        funcs = "\n".join(qml_function(source, name) for name in
                            ("run", "pingNodes", "finishPing", "runUpdate", "finishUpdate"))
        funcs = funcs.replace('proc.command = ["bash", root.script].concat(args);',
                              "proc.command = root.commandFactory(args);")
        ping = qml_block(source, "Process {\n    id: pingProc")
        update = qml_block(source, "Process {\n    id: updateProc")
        with tempfile.TemporaryDirectory(prefix="module-mihomo-actions-") as tmp:
            root = Path(tmp)
            ok = root / "ok.py"
            ok.write_text("import sys\nprint('{\\\"ok\\\":true,\\\"alive\\\":1}' if sys.argv[1] == '--ping' else '{\\\"ok\\\":true}')\n")
            out = self.fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property bool serviceOn: true
  property string provider: "stable"
  property bool pinging: false
  property bool updating: false
  property string error: ""
  property bool failPing: true
  property bool failUpdate: true
  property int phase: 0
  property int ticks: 0
  function parse(text) { return Reply.parse(text, "mihomo.sh", null); }
  function refreshNodes() {}
  function refreshStatus() {}
  function refresh() {}
  function commandFactory(args) {
    if ((args[0] === "--ping" && root.failPing) || (args[0] === "--update" && root.failUpdate))
      return ["/no/such/mihomo-action"];
    return ["''' + shutil.which("python3") + '''", "''' + str(ok) + '''", args[0]];
  }
''' + funcs + '\n' + ping + '\n' + update + '''
  Component.onCompleted: root.pingNodes()
  Timer { interval: 10; running: true; repeat: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0 && root.error === "could not start ping") {
      const failedPing = !root.pinging; root.failPing = false; root.error = ""; root.pingNodes(); root.phase = 1;
      root.failedPing = failedPing;
    } else if (root.phase === 1 && !root.pinging && root.error === "") {
      root.failUpdate = true; root.runUpdate(); root.phase = 2;
    } else if (root.phase === 2 && root.error === "could not start update") {
      const failedUpdate = !root.updating; root.failUpdate = false; root.error = ""; root.runUpdate(); root.phase = 3;
      root.failedUpdate = failedUpdate;
    } else if (root.phase === 3 && !root.updating && root.error === "") {
      console.warn("MIHOMO_ACTION_RETRY:" + JSON.stringify({failedPing:root.failedPing,
        failedUpdate:root.failedUpdate,pinging:root.pinging,updating:root.updating,error:root.error})); Qt.quit();
    }
    if (root.ticks > 300) { console.warn("MIHOMO_ACTION_TIMEOUT:" + JSON.stringify({phase:root.phase,error:root.error,pinging:root.pinging,updating:root.updating})); Qt.quit(); }
  } }
  property bool failedPing: false
  property bool failedUpdate: false
}
''')
            self.assertEqual(self.result(out, "MIHOMO_ACTION_RETRY:"), {
                "failedPing": True, "failedUpdate": True,
                "pinging": False, "updating": False, "error": "",
            })

    @unittest.skipUnless(shutil.which("bash") and shutil.which("jq"), "needs bash and jq")
    def test_mihomo_select_reports_backend_failure_and_success(self):
        script = MIHOMO.parents[2] / "scripts/mihomo.sh"
        with tempfile.TemporaryDirectory(prefix="module-mihomo-select-") as tmp:
            root = Path(tmp)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            curl = bin_dir / "curl"
            curl.write_text('''#!/bin/sh
put=0
prev=""
for arg in "$@"; do
  [ "$prev" = "-X" ] && [ "$arg" = "PUT" ] && put=1
  prev="$arg"
done
if [ "$put" = 1 ]; then
  if [ "$SELECT_HTTP" = 204 ]; then printf 204; else printf 503; fi
else
  printf '{"type":"Selector"}'
fi
''')
            curl.chmod(0o700)
            env = dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}",
                       HOME=str(root), MIHOMO_API="http://example.invalid")
            fail = subprocess.run(["bash", str(script), "--select", "node"], env=dict(env, SELECT_HTTP="503"),
                                  capture_output=True, text=True)
            good = subprocess.run(["bash", str(script), "--select", "node"], env=dict(env, SELECT_HTTP="204"),
                                  capture_output=True, text=True)
            self.assertNotEqual(fail.returncode, 0)
            self.assertTrue(fail.stdout, f"stdout={fail.stdout!r} stderr={fail.stderr!r}")
            self.assertEqual(json.loads(fail.stdout), {"ok": False, "error": "node selection failed (HTTP 503)"},
                             fail.stderr)
            self.assertEqual(good.returncode, 0)
            self.assertEqual(json.loads(good.stdout), {"ok": True})


if __name__ == "__main__":
    unittest.main()
