"""Production LocalSend lifecycle with fake JSONL children and isolated state."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

from tests.qml_runtime import SHELL, run_quickshell


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class LocalSendService(unittest.TestCase):
    def fixture(self, body, *, crash=False, missing=False, failure_action=""):
        with tempfile.TemporaryDirectory(prefix="shell-localsend-service-") as tmp:
            root = Path(tmp)
            helper = root / "helper"
            starts = root / "starts"
            helper.write_text(f'''#!{sys.executable}
import json, os, sys, time
with open({str(starts)!r}, "a") as log: log.write("start\\n")
def emit(event, **fields):
    print(json.dumps(dict(v=1, event=event, **fields)), flush=True)
emit("ready")
for line in sys.stdin:
    cmd = json.loads(line)
    if {crash!r} and cmd["cmd"] == "status" and open({str(starts)!r}).read().count("\\n") == 1: os._exit(7)
    if cmd["cmd"] == "shutdown":
        emit("stopped")
        break
    if cmd["cmd"] == "discover":
        emit("command_result", id=cmd["id"], ok=True)
        time.sleep(0.1)
        emit("discovery_complete", id=cmd["id"], devices=[])
    else:
        emit("command_result", id=cmd["id"], ok=True, devices=[])
''')
            helper.chmod(0o700)
            config = root / "config"
            config.mkdir()
            (config / "qmldir").write_text("singleton ModuleSettings 1.0 ModuleSettings.qml\n")
            (config / "ModuleSettings.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
  property bool background: false
  function get(module, key, fallback) { return key === "background" ? background : fallback; }
  function set(module, key, value) { background = value; }
}
''')
            source = (SHELL / "apps/localsend/LocalSendService.qml").read_text()
            source = source.replace("pragma Singleton", "").replace("Singleton {", "Scope {", 1)
            source = source.replace("import qs.config", 'import "config"')
            source = source.replace('readonly property string helperPath: Quickshell.env("HOME") + "/.config/localsend/vdx-localsend"',
                                    "property string helperPath: " + json.dumps(str(root / "missing" if missing else helper)))
            source = source.replace('Quickshell.env("HOME") + "/Downloads/LocalSend"', json.dumps(str(root / "downloads")))
            (root / "LocalSendService.qml").write_text(source)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
Scope {
  id: fixture
  LocalSendService { id: svc }
  property int phase: 0
  property int ticks: 0
  property var failures: []
  Connections {
    target: svc
    function onCommandFailed(id, code, message) { fixture.failures = fixture.failures.concat([{id, code}]); FAILURE_ACTION }
  }
  Timer { interval: 20; repeat: true; running: true; onTriggered: {
    fixture.ticks++;
''' + body + '''
    if (fixture.ticks > 250) {
      console.warn("LOCALSEND_RESULT:" + JSON.stringify({timeout:true, processStatus:svc.processStatus,
        pending:Object.keys(svc.pendingCommands).length}));
      Qt.quit();
    }
  } }
}
''')
            shell = root / "shell.qml"
            shell.write_text(shell.read_text().replace("FAILURE_ACTION", failure_action))
            output = run_quickshell(root)
            results = [line.split("LOCALSEND_RESULT:", 1)[1] for line in output.splitlines() if "LOCALSEND_RESULT:" in line]
            self.assertEqual(len(results), 1, output)
            result = json.loads(results[0])
            self.assertNotIn("timeout", result, output)
            result["starts"] = len(starts.read_text().splitlines()) if starts.exists() else 0
            return result

    def test_crash_completes_sent_requests_and_does_not_restart_without_consumer(self):
        result = self.fixture('''
    if (fixture.phase === 0) { fixture.phase = 1; svc.getStatus(); }
    if (fixture.ticks === 65) {
      console.warn("LOCALSEND_RESULT:" + JSON.stringify({pending:Object.keys(svc.pendingCommands).length,
        queued:svc.commandQueue.length, needed:svc.shouldRun(), failures:fixture.failures.length,
        processStatus:svc.processStatus}));
      Qt.quit();
    }
''', crash=True)
        self.assertEqual(result, {"pending": 0, "queued": 0, "needed": False, "failures": 1,
                                  "processStatus": "error", "starts": 1})

    def test_missing_helper_clears_requests_and_can_retry_then_stop(self):
        result = self.fixture('''
    if (fixture.phase === 0) { fixture.phase = 1; svc.getStatus(); }
    else if (fixture.phase === 1 && svc.processStatus === "error") {
      if (Object.keys(svc.pendingCommands).length !== 0) return;
      svc.helperPath = svc.helperPath.replace("missing", "helper");
      fixture.phase = 2;
      svc.setWindowOpen(true);
    } else if (fixture.phase === 2 && svc.serviceAvailable) {
      fixture.phase = 3;
      svc.getStatus();
      svc.discover();
      svc.setWindowOpen(false);
    } else if (fixture.phase === 3 && svc.processStatus === "stopped") {
      console.warn("LOCALSEND_RESULT:" + JSON.stringify({pending:Object.keys(svc.pendingCommands).length,
        needed:svc.shouldRun(), failures:fixture.failures.length, discovery:svc.discoveryActive}));
      Qt.quit();
    }
''', missing=True)
        self.assertEqual(result, {"pending": 0, "needed": False, "failures": 1, "discovery": False, "starts": 1})

    def test_failure_listener_can_submit_a_new_request_without_losing_it(self):
        result = self.fixture('''
    if (fixture.phase === 0) { fixture.phase = 1; svc.getStatus(); }
    else if (fixture.phase === 2 && svc.processStatus === "stopped") {
      console.warn("LOCALSEND_RESULT:" + JSON.stringify({pending:Object.keys(svc.pendingCommands).length,
        needed:svc.shouldRun(), failures:fixture.failures.length}));
      Qt.quit();
    }
''', crash=True, failure_action="if (fixture.phase === 1) { fixture.phase = 2; svc.getStatus(); }")
        self.assertEqual(result, {"pending": 0, "needed": False, "failures": 1, "starts": 2})

    def test_discovery_acknowledgement_keeps_scan_active_until_snapshot(self):
        result = self.fixture('''
    if (fixture.phase === 0) { fixture.phase = 1; svc.setWindowOpen(true); }
    else if (fixture.phase === 1 && svc.serviceAvailable) {
      fixture.phase = 2;
      svc.discover();
    } else if (fixture.phase === 2) {
      fixture.phase = 3;
      fixture.ticks = 0;
    } else if (fixture.phase === 3 && fixture.ticks === 2) {
      console.warn("LOCALSEND_RESULT:" + JSON.stringify({active:svc.discoveryActive,
        pending:Object.keys(svc.pendingCommands).length}));
      Qt.quit();
    }
''')
        self.assertEqual(result, {"active": True, "pending": 1, "starts": 1})

    def test_expired_unsent_command_is_never_flushed_to_helper(self):
        result = self.fixture('''
    if (fixture.phase === 0) {
      fixture.phase = 1;
      svc.pendingCommands = {old: {kind:"discover", at:Date.now()-121000}};
      svc.commandQueue = [{id:"old", line:"must not be sent"}];
      svc.discoveryActive = true;
      svc.expireCommands();
      console.warn("LOCALSEND_RESULT:" + JSON.stringify({pending:Object.keys(svc.pendingCommands).length,
        queued:svc.commandQueue.length, active:svc.discoveryActive, needed:svc.shouldRun(), failures:fixture.failures.length}));
      Qt.quit();
    }
''')
        self.assertEqual(result, {"pending": 0, "queued": 0, "active": False,
                                  "needed": False, "failures": 1, "starts": 0})

    def test_crash_clears_incoming_requests_and_marks_devices_unavailable(self):
        result = self.fixture('''
    if (fixture.phase === 0) { fixture.phase = 1; svc.setWindowOpen(true); }
    else if (fixture.phase === 1 && svc.serviceAvailable) {
      fixture.phase = 2;
      svc.upsertDevice({fingerprint:"phone", alias:"Phone", host:"127.0.0.1", port:53317});
      svc.handleIncoming({sessionId:"offer", transferId:"receive", alias:"Phone", fingerprint:"phone",
        files:[{fileId:"one", fileName:"one.txt", size:1}], confirmTimeoutSeconds:60});
      svc.getStatus();
    } else if (fixture.phase === 2 && svc.processStatus === "error") {
      const revision = svc.deviceRevision;
      svc.setWindowOpen(false);
      console.warn("LOCALSEND_RESULT:" + JSON.stringify({incoming:svc.incomingRequests.count,
        pending:Object.keys(svc.pendingCommands).length, available:svc.devices.get(0).available,
        revision, failures:fixture.failures.length}));
      Qt.quit();
    }
''', crash=True)
        self.assertEqual(result, {"incoming": 0, "pending": 0, "available": False, "revision": 2,
                                  "failures": 1, "starts": 1})


if __name__ == "__main__":
    unittest.main()
