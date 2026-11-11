"""Verify VirusTotal reply validation and child-process recovery in isolation."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


SERVICE = SHELL / "apps/virustotal/VirusTotalService.qml"


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class VirusTotalService(unittest.TestCase):
    def run_fixture(self, root, source):
        (root / "kit").mkdir(exist_ok=True)
        shutil.copy(SHELL / "kit/reply.js", root / "kit/reply.js")
        (root / "shell.qml").write_text(source)
        return run_quickshell(root)

    def result(self, output, marker):
        results = [line.split(marker, 1)[1] for line in output.splitlines()
                   if marker in line]
        self.assertEqual(len(results), 1, output)
        return json.loads(results[0])

    def test_production_validation_verdict_and_history_helpers(self):
        source = SERVICE.read_text()
        funcs = "\n".join(qml_function(source, name) for name in (
            "validStats", "validResult", "replyError", "finishLookup", "acceptResult",
            "verdictOf", "historyLimit", "validHistory", "loadHistory", "remember"))
        with tempfile.TemporaryDirectory(prefix="shell-virustotal-schema-") as tmp:
            root = Path(tmp)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
Scope {
  id: root
  property var result: ({ok: true, known: true, kind: "file", target: "old",
    name: "Old", link: "https://example.test/old", stats: {malicious: 0, suspicious: 0,
    undetected: 1, harmless: 2, timeout: 0}, detections: []})
  property string error: ""
  property bool busy: true
  property bool uploading: true
  property var history: [{target: "old", verdict: "clean"}]
  property bool keepHistory: true
  property int historyKeep: 500
  property int writes: 0
  function persist() { writes++; }
''' + funcs + '''
  Timer { interval: 0; running: true; onTriggered: {
    const oldResult = root.result;
    const oldHistory = root.history;
    const malformed = root.acceptResult({ok: true, known: true, kind: "file", target: "bad",
      name: "Bad", link: "link", stats: {malicious: NaN}, detections: []});
    const malformedState = {accepted: malformed, resultUnchanged: root.result === oldResult,
      historyUnchanged: root.history === oldHistory, error: root.error, busy: root.busy,
      uploading: root.uploading, writes: root.writes};
    root.busy = true; root.uploading = false;
    const nonBoolean = root.acceptResult({ok: 1});
    const nonBooleanState = {accepted: nonBoolean, error: root.error, busy: root.busy};
    const valid = {ok: true, known: true, kind: "url", target: "https://example.test",
      name: "Example", link: "https://vt.test/report",
      stats: {malicious: 1, suspicious: 0, undetected: 2, harmless: 3, timeout: 0},
      detections: [{engine: "Engine", category: "malicious", result: "bad"}]};
    const accepted = root.acceptResult(valid);
    const validState = {accepted, verdict: root.verdictOf(root.result), result: root.result,
      history: root.history, error: root.error, busy: root.busy, uploading: root.uploading,
      writes: root.writes};
    const unknown = {ok: true, known: false, kind: "file", target: "/tmp/sample",
      sha256: "abc", size: null};
    const unknownValid = root.validResult(unknown);
    const badUnknown = root.validResult({ok: true, known: false, kind: "file", target: "/tmp/sample",
      sha256: "abc", size: Infinity});
    const oldMalformedVerdict = root.verdictOf({known: true});
    root.historyKeep = 2;
    root.loadHistory([{target: "a", verdict: "clean"}, {target: 1, verdict: "clean"},
      {target: "b", verdict: "wrong"}, {target: "c", verdict: "unknown"}]);
    const loadedHistory = root.history;
    root.historyKeep = 500;
    const clamped = root.historyLimit();
    console.warn("VT_SCHEMA_RESULT:" + JSON.stringify({malformedState, nonBooleanState,
      validState, unknownValid, badUnknown, oldMalformedVerdict, loadedHistory, clamped}));
    Qt.quit();
  } }
}
''')
            self.assertEqual(self.result(output, "VT_SCHEMA_RESULT:"), {
                "malformedState": {"accepted": False, "resultUnchanged": True,
                                   "historyUnchanged": True, "error": "bad VirusTotal reply",
                                   "busy": False, "uploading": False, "writes": 0},
                "nonBooleanState": {"accepted": False, "error": "VirusTotal lookup failed", "busy": False},
                "validState": {"accepted": True, "verdict": "malicious",
                               "result": {"ok": True, "known": True, "kind": "url",
                                          "target": "https://example.test", "name": "Example",
                                          "link": "https://vt.test/report",
                                          "stats": {"malicious": 1, "suspicious": 0,
                                                    "undetected": 2, "harmless": 3, "timeout": 0},
                                          "detections": [{"engine": "Engine", "category": "malicious", "result": "bad"}]},
                               "history": [{"target": "https://example.test", "verdict": "malicious"},
                                           {"target": "old", "verdict": "clean"}],
                               "error": "", "busy": False, "uploading": False, "writes": 1},
                "unknownValid": True, "badUnknown": False, "oldMalformedVerdict": "",
                "loadedHistory": [{"target": "a", "verdict": "clean"},
                                  {"target": "c", "verdict": "unknown"}],
                "clamped": 50,
            })

    def test_lookup_process_start_failure_clears_state_and_retry_validates_reply(self):
        source = SERVICE.read_text()
        process = qml_block(source, "Process {\n    id: proc")
        funcs = "\n".join(qml_function(source, name) for name in (
            "validStats", "validResult", "replyError", "finishLookup", "acceptResult", "verdictOf",
            "historyLimit", "validHistory", "remember"))
        scan = qml_function(source, "scan").replace(
            'proc.command = ["python3", script, "scan", t, String(waitSeconds)];',
            'proc.command = failStart ? ["/no/such/virustotal"] : ["python3", script, "scan", t, String(waitSeconds)];')
        upload = qml_function(source, "upload").replace(
            'proc.command = ["python3", script, "upload", result.target, String(waitSeconds)];',
            'proc.command = failStart ? ["/no/such/virustotal"] : ["python3", script, "upload", result.target, String(waitSeconds)];')
        script_body = '''import json
print(json.dumps({"ok": True, "known": False, "kind": "file", "target": "fixture",
  "sha256": "a" * 64, "size": 12}))
'''
        with tempfile.TemporaryDirectory(prefix="shell-virustotal-retry-") as tmp:
            root = Path(tmp)
            script = root / "vt.py"
            script.write_text(script_body)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property string script: ''' + json.dumps(str(script)) + '''
  property int waitSeconds: 10
  property bool busy: false
  property bool uploading: false
  property string error: ""
  property string target: ""
  property var result: ({ok: true, known: false, kind: "file", target: "fixture", sha256: "abc", size: null})
  property bool canUpload: true
  property var history: []
  property bool keepHistory: true
  property int historyKeep: 20
  property bool failStart: true
  property int phase: 0
  property int ticks: 0
  property var failedState: null
  function parse(text) { return Reply.parse(text, "virustotal.py"); }
  function persist() {}
''' + funcs + '\n' + scan + '\n' + upload + '\n' + process + '''
  Timer { interval: 20; running: true; repeat: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) { root.upload(); root.phase = 1; }
    else if (root.phase === 1 && root.error === "could not start VirusTotal lookup") {
      root.failedState = {busy: root.busy, uploading: root.uploading, error: root.error};
      root.failStart = false; root.error = ""; root.scan("fixture"); root.phase = 2;
    } else if (root.phase === 2 && root.result?.known === false && !root.busy) {
      console.warn("VT_LOOKUP_RESULT:" + JSON.stringify({failedState: root.failedState,
        busy: root.busy, uploading: root.uploading, error: root.error, result: root.result,
        history: root.history}));
      Qt.quit();
    }
    if (root.ticks > 150) { console.warn("VT_LOOKUP_TIMEOUT:" + root.error); Qt.quit(); }
  } }
}
''')
            self.assertEqual(self.result(output, "VT_LOOKUP_RESULT:"), {
                "failedState": {"busy": False, "uploading": False,
                                "error": "could not start VirusTotal lookup"},
                "busy": False, "uploading": False, "error": "",
                "result": {"ok": True, "known": False, "kind": "file", "target": "fixture",
                           "sha256": "a" * 64, "size": 12},
                "history": [{"target": "fixture", "verdict": "unknown"}],
            })

    def test_clipboard_start_failure_and_overlap_keep_the_original_owner(self):
        source = SERVICE.read_text()
        process = qml_block(source, "Process {\n    id: clipProc")
        process = process.replace('command: ["wl-paste", "--no-newline"]', "command: root.command")
        read_clipboard = qml_function(source, "readClipboard")
        with tempfile.TemporaryDirectory(prefix="shell-virustotal-clipboard-") as tmp:
            root = Path(tmp)
            script = root / "paste.py"
            script.write_text('import time\ntime.sleep(0.15)\nprint("' + "a" * 64 + '")\n')
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property var command: ["/no/such/wl-paste"]
  property var into: null
  property bool clipPending: false
  property string error: ""
  property int phase: 0
  property int ticks: 0
  property bool retryCleared: false
  property bool overlapRejected: false
  QtObject { id: ownerA; property string value: ""; function prefill(text) { value = text; } }
  QtObject { id: ownerB; property string value: ""; function prefill(text) { value = text; } }
''' + read_clipboard + '\n' + process + '''
  Timer { interval: 20; running: true; repeat: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) { root.readClipboard(ownerA); root.phase = 1; }
    else if (root.phase === 1 && root.error === "could not start clipboard read") {
      root.retryCleared = root.into === null && !root.clipPending;
      root.error = ""; root.command = ["python3", ''' + json.dumps(str(script)) + '''];
      root.readClipboard(ownerA); root.phase = 2;
    } else if (root.phase === 2 && clipProc.running) {
      root.overlapRejected = !root.readClipboard(ownerB); root.phase = 3;
    } else if (root.phase === 3 && ownerA.value !== "") {
      console.warn("VT_CLIPBOARD_RESULT:" + JSON.stringify({retryCleared: root.retryCleared,
        overlapRejected: root.overlapRejected, ownerA: ownerA.value, ownerB: ownerB.value,
        into: root.into, clipPending: root.clipPending}));
      Qt.quit();
    }
    if (root.ticks > 150) { console.warn("VT_CLIPBOARD_TIMEOUT:" + root.error); Qt.quit(); }
  } }
}
''')
            self.assertEqual(self.result(output, "VT_CLIPBOARD_RESULT:"), {
                "retryCleared": True, "overlapRejected": True, "ownerA": "a" * 64,
                "ownerB": "", "into": None, "clipPending": False,
            })


if __name__ == "__main__":
    unittest.main()
