"""Exercise clipboard service queueing and validation with isolated commands."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


SERVICE = SHELL / "apps/clipboard/ClipboardService.qml"


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class ClipboardService(unittest.TestCase):
    def run_fixture(self, root: Path, source: str) -> str:
        (root / "kit").mkdir(exist_ok=True)
        shutil.copy(SHELL / "kit/reply.js", root / "kit/reply.js")
        (root / "shell.qml").write_text(source)
        return run_quickshell(root)

    def result(self, output: str, marker: str):
        results = [line.split(marker, 1)[1] for line in output.splitlines() if marker in line]
        self.assertEqual(len(results), 1, output)
        return json.loads(results[0])

    def test_action_fifo_and_copy_signal_waits_for_successful_exit(self):
        source = SERVICE.read_text()
        functions = []
        for name in ("setLimit", "enqueueAction", "startNextAction", "parse", "actionError", "finishAction"):
            function = qml_function(source, name).replace(
                'Paths.scriptsDir + "/clipboard.sh"', json.dumps("/fake/clipboard.sh"))
            functions.append(function)
        process = qml_block(source, "Process {\n    id: actionProc")
        with tempfile.TemporaryDirectory(prefix="shell-clipboard-queue-") as tmp:
            root = Path(tmp)
            log = root / "actions.log"
            fake = root / "clipboard.sh"
            fake.write_text(
                "#!/bin/sh\n"
                f"printf '%s\\n' \"$*\" >> {json.dumps(str(log))}\n"
                "if [ \"$1\" = copy ]; then sleep 0.15; fi\n"
                "printf '{\"ok\":true}\\n'\n"
            )
            fake.chmod(0o700)
            # The extracted production starter points at this temporary script.
            functions = [f.replace(json.dumps("/fake/clipboard.sh"), json.dumps(str(fake)))
                         for f in functions]
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property var actionQueue: []
  property var activeAction: null
  property var actionReply: null
  property string error: ""
  property bool actionFailed: false
  property int limit: 100
  property string copiedId: ""
  property bool copiedWhileRunning: false
  property bool copiedWithActive: false
  signal copied(string id)
  function refresh() {}
  ''' + "\n".join(functions) + '''
  Connections { target: root; function onCopied(id) {
    root.copiedId = id;
    root.copiedWhileRunning = actionProc.running;
    root.copiedWithActive = root.activeAction !== null;
  } }
''' + process + '''
  Timer { interval: 20; running: true; repeat: true; property int ticks: 0
    onTriggered: {
      ticks++;
      if (ticks === 1) {
        root.enqueueAction("delete", ["first"]);
        root.enqueueAction("clear", []);
        root.setLimit(250);
        root.enqueueAction("copy", ["last"]);
      }
      if (root.copiedId !== "") {
        console.warn("CLIPBOARD_FIFO:" + JSON.stringify({id: root.copiedId,
          whileRunning: root.copiedWhileRunning, withActive: root.copiedWithActive,
          queued: root.actionQueue, active: root.activeAction, limit: root.limit}));
        Qt.quit();
      }
      if (ticks > 200) { console.warn("CLIPBOARD_FIFO_TIMEOUT:" + root.error); Qt.quit(); }
    }
  }
}
''')
            self.assertEqual(self.result(output, "CLIPBOARD_FIFO:"), {
                "id": "last", "whileRunning": False, "withActive": False,
                "queued": [], "active": None, "limit": 250,
            })
            self.assertEqual(log.read_text().splitlines(),
                             ["delete first", "clear", "limit 250", "copy last"])

    def test_failed_limit_preserves_value_and_successful_list_keeps_action_error(self):
        source = SERVICE.read_text()
        funcs = "\n".join(qml_function(source, name) for name in
                           ("setLimit", "parse", "parseList", "validList", "acceptList", "actionError"))
        process = qml_block(source, "Process {\n    id: actionProc")
        start_functions = "\n".join(
            qml_function(source, name).replace(
                'Paths.scriptsDir + "/clipboard.sh"', json.dumps("/fake/clipboard.sh"))
            for name in ("enqueueAction", "startNextAction", "finishAction"))
        with tempfile.TemporaryDirectory(prefix="shell-clipboard-limit-") as tmp:
            root = Path(tmp)
            fake = root / "clipboard.sh"
            fake.write_text("#!/bin/sh\nprintf '{\"ok\":false,\"error\":\"limit rejected\"}\\n'\nexit 1\n")
            fake.chmod(0o700)
            start_functions = start_functions.replace(json.dumps("/fake/clipboard.sh"), json.dumps(str(fake)))
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property var entries: [{id:"old", kind:"text", preview:"old", path:"/old", time:1}]
  property int limit: 100
  property var actionQueue: []
  property var activeAction: null
  property var actionReply: null
  property string error: ""
  property bool actionFailed: false
  function refresh() {}
''' + funcs + '\n' + start_functions + '\n' + process + '''
  Timer { interval: 20; running: true; repeat: true; property int ticks: 0
    onTriggered: {
      ticks++;
      if (ticks === 1) root.setLimit(250);
      if (root.error === "limit rejected") {
        const before = root.entries;
        const accepted = root.acceptList([{id:"new",kind:"text",preview:"x",path:"/x",time:2}]);
        const afterValid = {accepted, error:root.error, actionFailed:root.actionFailed};
        const invalid = root.acceptList([{id:"broken",kind:"bad",preview:"x",path:"/x",time:2}]);
        console.warn("CLIPBOARD_LIMIT:" + JSON.stringify({limit:root.limit,
          before, entries:root.entries, afterValid, invalid, finalError:root.error}));
        Qt.quit();
      }
      if (ticks > 200) { console.warn("CLIPBOARD_LIMIT_TIMEOUT:" + root.error); Qt.quit(); }
    }
  }
}
''')
            self.assertEqual(self.result(output, "CLIPBOARD_LIMIT:"), {
                "limit": 100,
                "before": [{"id": "old", "kind": "text", "preview": "old", "path": "/old", "time": 1}],
                "entries": [{"id": "new", "kind": "text", "preview": "x", "path": "/x", "time": 2}],
                "afterValid": {"accepted": True, "error": "limit rejected", "actionFailed": True},
                "invalid": False, "finalError": "limit rejected",
            })


if __name__ == "__main__":
    unittest.main()
