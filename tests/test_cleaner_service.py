"""Cleaner service validates replies and recovers without invoking real cleaners or root actions."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import sys
import subprocess
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


SERVICE = SHELL / "apps/cleaner/CleanerService.qml"


def process_command(root, name, value, args=()):
    script = root / (name + ".py")
    script.write_text("print(" + json.dumps(json.dumps(value)) + ")\n")
    return json.dumps([sys.executable, str(script), *args])


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class CleanerService(unittest.TestCase):
    def run_fixture(self, root, source):
        (root / "kit").mkdir(exist_ok=True)
        shutil.copy(SHELL / "kit/reply.js", root / "kit/reply.js")
        (root / "shell.qml").write_text(source)
        try:
            return run_quickshell(root, timeout=12)
        except subprocess.TimeoutExpired as error:
            output = error.stdout or b""
            detail = output.decode(errors="replace") if isinstance(output, bytes) else output
            raise AssertionError(f"Quickshell fixture timed out:\n{detail}") from error

    def result(self, output, marker):
        results = [line.split(marker, 1)[1] for line in output.splitlines() if marker in line]
        self.assertEqual(len(results), 1, output)
        return json.loads(results[0])

    def helpers(self, source, names):
        return "\n".join(qml_function(source, name) for name in names)

    def test_schemas_preserve_snapshots_and_malformed_plan_never_reaches_root(self):
        source = SERVICE.read_text()
        funcs = self.helpers(source, ("finite", "record", "replyError", "failScan", "acceptScan",
                                      "failPlan", "acceptPlan", "failAction", "acceptAction",
                                      "failAi", "acceptAi"))
        funcs = funcs.replace("RootService.request", "root.requestRoot").replace("Format.shortSize", "String")
        with tempfile.TemporaryDirectory(prefix="cleaner-schema-") as tmp:
            root = Path(tmp)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
Scope {
  id: root
  property var categories: [{id: "kept", label: "Kept", hint: "old", size: 4, root: false, safe: true}]
  property real total: 4
  property var picked: ({kept: true})
  property bool scanning: false
  property real scannedAt: 1
  property var suggestions: [{path: "~/kept", size: 5, days: 10, kind: "file", why: "kept", risk: "low"}]
  property var aiPicked: ({"~/kept": true})
  property bool analyzing: false
  property bool busy: false
  property string status: ""
  property string message: ""
  property var pendingRoot: ["old-root"]
  property var planIds: ["old-root"]
  property real planSize: 8
  property bool afterSystem: false
  property bool systemScanPending: false
  property int rootRequests: 0
  property int scans: 0
  function done(ok, text) { status = ok ? "ok" : "error"; message = text; }
  function requestRoot() { rootRequests++; return true; }
  function scan() { scans++; }
''' + funcs + '''
  Timer { interval: 0; running: true; onTriggered: {
    const oldCategory = categories;
    const badScan = acceptScan({ok: true, total: 99, categories: [
      {id: "bad", label: "Bad", hint: "bad", size: Infinity, root: false, safe: true}]});
    const preservedScan = categories === oldCategory && total === 4;
    const validScan = acceptScan({ok: true, total: 12, categories: [
      {id: "user", label: "User", hint: "cache", size: 12, root: false, safe: true},
      {id: "journal", label: "Journal", hint: "old logs", size: 0, root: true, safe: true, command: "journalctl"}]});
    const afterScan = {validScan, total, ids: categories.map(c => c.id), error: message};
    const oldSuggestions = suggestions;
    const badAi = acceptAi({ok: true, suggestions: [{path: "~/bad", size: "large", days: 1,
      kind: "file", why: "bad", risk: "low"}]});
    const preservedAi = suggestions === oldSuggestions;
    const validAi = acceptAi({ok: true, suggestions: [{path: "~/new", size: 7, days: 3,
      kind: "file", why: "old cache", risk: "low"}]});
    const afterAi = {validAi, suggestions, aiPicked};
    const futureAi = acceptAi({ok: true, suggestions: [{path: "~/future", size: 2, days: -1,
      kind: "file", why: "recent", risk: "low"}]});
    suggestions = [{path: "~/sent", size: 5, days: 1, kind: "file", why: "sent", risk: "low"},
      {path: "~/newer", size: 6, days: 1, kind: "file", why: "new", risk: "low"}];
    aiPicked = ({"~/sent": true, "~/newer": true, "~/unrelated": true});
    const trashSnapshot = acceptAction("trash", {ok: true, freed: 2}, ["~/sent"]);
    const afterTrash = {trashSnapshot, suggestions, aiPicked};
    const badPlan = acceptPlan({ok: true, steps: [{label: "Oops", what: "x", command: 4}],
      script: "echo bad", size: 10});
    const noRootForBadPlan = rootRequests === 0 && !busy;
    const validPlan = acceptPlan({ok: true, steps: [{label: "Journal", what: "vacuum", command: "journalctl"}],
      script: "journalctl --vacuum-time=2weeks", size: 10});
    const rootCalledForGoodPlan = validPlan && rootRequests === 1 && planSize === 10;
    pendingRoot = ["journal"];
    busy = true;
    const badAction = acceptAction("clean", {ok: true, freed: NaN});
    const actionFailure = {badAction, busy, pendingRoot, status, message};
    afterSystem = true; busy = true; planIds = ["journal"]; planSize = 10;
    const failedAfterSystemScan = acceptScan({ok: true, total: 12, categories: [{id: 9}]}, true);
    const clearedAfterSystem = !afterSystem && !busy && planIds.length === 0 && planSize === 0;
    console.warn("CLEANER_SCHEMA_RESULT:" + JSON.stringify({preservedScan, afterScan, preservedAi,
      afterAi, futureAi, afterTrash, badPlan, noRootForBadPlan, rootCalledForGoodPlan, actionFailure,
      failedAfterSystemScan, clearedAfterSystem, categories, suggestions}));
    Qt.quit();
  } }
}
''')
            result = self.result(output, "CLEANER_SCHEMA_RESULT:")
            self.assertTrue(result["preservedScan"])
            self.assertEqual(result["afterScan"], {"validScan": True, "total": 12,
                             "ids": ["user", "journal"], "error": "bad cleanup category reply"})
            self.assertTrue(result["preservedAi"])
            self.assertEqual(result["afterAi"], {"validAi": True,
                "suggestions": [{"path": "~/new", "size": 7, "days": 3, "kind": "file",
                                 "why": "old cache", "risk": "low"}], "aiPicked": {"~/new": True}})
            self.assertTrue(result["futureAi"])
            self.assertEqual(result["afterTrash"], {"trashSnapshot": True,
                "suggestions": [{"path": "~/newer", "size": 6, "days": 1, "kind": "file",
                                 "why": "new", "risk": "low"}],
                "aiPicked": {"~/newer": True, "~/unrelated": True}})
            self.assertFalse(result["badPlan"])
            self.assertTrue(result["noRootForBadPlan"])
            self.assertTrue(result["rootCalledForGoodPlan"])
            self.assertEqual(result["actionFailure"], {"badAction": False, "busy": False,
                "pendingRoot": [], "status": "error", "message": "bad cleanup action reply"})
            self.assertFalse(result["failedAfterSystemScan"])
            self.assertTrue(result["clearedAfterSystem"])

    def test_all_four_process_start_failures_release_state_and_retry(self):
        source = SERVICE.read_text()
        names = ("scanStopped", "finite", "record", "replyError", "failScan", "acceptScan", "failPlan", "acceptPlan",
                 "consumePlanReply", "finishRoot", "failAction", "acceptAction", "consumeActionReply",
                 "failAi", "acceptAi", "consumeAiReply")
        funcs = self.helpers(source, names).replace("RootService.request", "root.requestRoot").replace(
            "Format.shortSize", "String")
        scan_fn = qml_function(source, "scan")
        run_fn = qml_function(source, "run").replace(
            'actProc.command = ["python3", script].concat(args);', "actProc.command = root.actCommand;")
        plan_fn = qml_function(source, "plan").replace(
            'planProc.command = ["python3", script, "plan"].concat(ids);', "planProc.command = root.planCommand;")
        ai_fn = qml_function(source, "analyze").replace(
            'aiProc.command = ["python3", script, "ai", model];', "aiProc.command = root.aiCommand;")
        processes = [
            qml_block(source, "Process {\n    id: scanProc").replace(
                'command: ["python3", root.script, "scan"]', "command: root.scanCommand"),
            qml_block(source, "Process {\n    id: planProc"),
            qml_block(source, "Process {\n    id: actProc"),
            qml_block(source, "Process {\n    id: aiProc"),
        ]
        categories = {"ok": True, "total": 10, "categories": [{"id": "user", "label": "User",
                      "hint": "cache", "size": 10, "root": False, "safe": True}]}
        ai_reply = {"ok": True, "suggestions": [{"path": "~/old", "size": 9, "days": 90,
                     "kind": "dir", "why": "old", "risk": "low"}]}
        plan_reply = {"ok": True, "steps": [{"label": "Journal", "what": "vacuum", "command": "journalctl"}],
                      "script": "journalctl --vacuum-time=2weeks", "size": 10}
        action_reply = {"ok": True, "freed": 5}
        with tempfile.TemporaryDirectory(prefix="cleaner-start-retry-") as tmp:
            root = Path(tmp)
            commands = [process_command(root, "scan", categories), process_command(root, "ai", ai_reply),
                        process_command(root, "plan", plan_reply, ("plan", "journal")),
                        process_command(root, "action", action_reply, ("clean", "user"))]
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property string script: "unused"
  property var categories: [{id: "kept", label: "Kept", hint: "old", size: 3, root: false, safe: true}]
  property real total: 3
  property var picked: ({})
  property bool scanning: false
  property real scannedAt: 0
  property var suggestions: [{path: "~/kept", size: 2, days: 1, kind: "file", why: "keep", risk: "low"}]
  property var aiPicked: ({})
  property bool analyzing: false
  property bool aiOn: true
  property string model: "haiku"
  property bool busy: false
  property string status: ""
  property string message: ""
  property var pendingRoot: []
  property var planIds: []
  property real planSize: 0
  property bool afterSystem: false
  property bool systemScanPending: false
  property int rootRequests: 0
  property var scanCommand: ["/no/such/cleaner-scan"]
  property var planCommand: ["/no/such/cleaner-plan"]
  property var actCommand: ["/no/such/cleaner-action"]
  property var aiCommand: ["/no/such/cleaner-ai"]
  property int phase: 0
  property int ticks: 0
  function done(ok, text) { status = ok ? "ok" : "error"; message = text; }
  function parse(text) { return Reply.parse(text, "cleaner.py"); }
  function requestRoot() { rootRequests++; return true; }
''' + scan_fn + '\n' + run_fn + '\n' + plan_fn + '\n' + ai_fn + '\n' + funcs + '\n'
            + '\n'.join(processes) + '''
  Timer { interval: 20; repeat: true; running: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) { root.scan(); root.phase = 1; }
    else if (root.phase === 1 && root.message === "could not start cleanup scan") {
      root.scanCommand = ''' + commands[0] + '''; root.message = ""; root.scan(); root.phase = 2;
    } else if (root.phase === 2 && root.categories[0].id === "user") {
      root.analyze(); root.phase = 3;
    } else if (root.phase === 3 && root.message === "could not start cleanup analysis") {
      root.aiCommand = ''' + commands[1] + '''; root.message = ""; root.analyze(); root.phase = 4;
    } else if (root.phase === 4 && root.suggestions[0].path === "~/old") {
      root.plan(["journal"]); root.phase = 5;
    } else if (root.phase === 5 && root.message === "could not start cleanup plan" && !root.busy) {
      root.planCommand = ''' + commands[2] + '''; root.message = ""; root.plan(["journal"]); root.phase = 6;
    } else if (root.phase === 6 && root.rootRequests === 1 && root.busy) {
      root.finishRoot("cleaner", false, "cancelled"); root.phase = 7;
    } else if (root.phase === 7 && root.message === "System part cancelled" && !root.scanning) {
      root.status = ""; root.message = ""; root.run(["clean", "user"]); root.phase = 8;
    } else if (root.phase === 8 && root.message === "could not start cleanup action" && !root.busy) {
      root.actCommand = ''' + commands[3] + '''; root.message = ""; root.run(["clean", "user"]); root.phase = 9;
    } else if (root.phase === 9 && root.status === "ok" && !root.busy && !root.scanning) {
      console.warn("CLEANER_START_RETRY_RESULT:" + JSON.stringify({phase: root.phase,
        scanning: root.scanning, analyzing: root.analyzing, busy: root.busy, status: root.status,
        message: root.message, categories: root.categories, suggestions: root.suggestions,
        rootRequests: root.rootRequests}));
      Qt.quit();
    }
    if (root.ticks > 400) { console.warn("CLEANER_START_RETRY_TIMEOUT:" + root.phase + ":" + root.message); Qt.quit(); }
  } }
}
''')
            result = self.result(output, "CLEANER_START_RETRY_RESULT:")
            self.assertEqual(result["phase"], 9)
            self.assertFalse(result["scanning"])
            self.assertFalse(result["analyzing"])
            self.assertFalse(result["busy"])
            self.assertEqual(result["status"], "ok")
            self.assertEqual(result["rootRequests"], 1)
            self.assertEqual(result["categories"][0]["id"], "user")
            self.assertEqual(result["suggestions"][0]["path"], "~/old")

    def test_user_then_system_request_and_root_error_releases_busy(self):
        source = SERVICE.read_text()
        funcs = self.helpers(source, ("scanStopped", "finite", "record", "replyError", "failScan", "acceptScan",
                                      "failPlan", "acceptPlan", "consumePlanReply", "finishRoot", "failAction",
                                      "acceptAction", "consumeActionReply"))
        funcs = funcs.replace("RootService.request", "root.requestRoot").replace("Format.shortSize", "String")
        clean_fn = qml_function(source, "clean")
        run_fn = qml_function(source, "run").replace(
            'actProc.command = ["python3", script].concat(args);', "actProc.command = root.actCommand;")
        scan_fn = qml_function(source, "scan")
        action_proc = qml_block(source, "Process {\n    id: actProc")
        plan_proc = qml_block(source, "Process {\n    id: planProc")
        plan_fn = qml_function(source, "plan").replace(
            'planProc.command = ["python3", script, "plan"].concat(ids);',
            "planProc.command = root.planCommand;")
        scan_proc = qml_block(source, "Process {\n    id: scanProc").replace(
            'command: ["python3", root.script, "scan"]', "command: root.scanCommand")
        scan_reply = {"ok": True, "total": 3, "categories": [
            {"id": "user", "label": "User", "hint": "cache", "size": 3, "root": False, "safe": True},
            {"id": "journal", "label": "Journal", "hint": "logs", "size": 0, "root": True, "safe": True,
             "command": "journalctl"}]}
        with tempfile.TemporaryDirectory(prefix="cleaner-user-system-") as tmp:
            root = Path(tmp)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property string script: "unused"
  property var categories: ''' + json.dumps(scan_reply["categories"]) + '''
  property real total: 3
  property var picked: ({})
  property bool scanning: false
  property real scannedAt: 0
  property var suggestions: []
  property var aiPicked: ({})
  property bool analyzing: false
  property bool busy: false
  property string status: ""
  property string message: ""
  property var pendingRoot: []
  property var planIds: []
  property real planSize: 0
  property bool afterSystem: false
  property bool systemScanPending: false
  property var requested: null
  property var actCommand: ''' + process_command(root, "user-action", {"ok": True, "freed": 3}, ("clean", "user")) + '''
  property var planCommand: ''' + process_command(root, "system-plan", {"ok": True, "steps": [
    {"label": "Journal", "what": "vacuum", "command": "journalctl"}],
    "script": "journalctl --vacuum-time=2weeks", "size": 12}, ("plan", "journal")) + '''
  property var scanCommand: ''' + process_command(root, "scan", scan_reply) + '''
  property int phase: 0
  property int ticks: 0
  function done(ok, text) { status = ok ? "ok" : "error"; message = text; }
  function parse(text) { return Reply.parse(text, "cleaner.py"); }
  function requestRoot(title, summary, steps, script, tag) {
    requested = {title, summary, steps, script, tag}; return true;
  }
''' + scan_fn + '\n' + run_fn + '\n' + clean_fn + '\n' + plan_fn + '\n' + funcs + '\n'
            + scan_proc + '\n' + action_proc + '\n' + plan_proc + '''
  Timer { interval: 20; repeat: true; running: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) { root.clean(["user", "journal"]); root.phase = 1; }
    else if (root.phase === 1 && root.requested !== null) {
      const requested = root.requested;
      const chained = {busy: root.busy, pendingRoot: root.pendingRoot,
        planIds: root.planIds, planSize: root.planSize, status: root.status, message: root.message};
      root.finishRoot("cleaner", false, "cancelled");
      root.phase = 2;
      root.requested = {request: requested, chained};
    } else if (root.phase === 2 && !root.busy && !root.scanning && root.message === "System part cancelled") {
      console.warn("CLEANER_USER_SYSTEM_RESULT:" + JSON.stringify({requested: root.requested.request,
        chained: root.requested.chained, busy: root.busy, status: root.status,
        message: root.message, pendingRoot: root.pendingRoot, planIds: root.planIds,
        afterSystem: root.afterSystem}));
      Qt.quit();
    }
    if (root.ticks > 300) { console.warn("CLEANER_USER_SYSTEM_TIMEOUT:" + root.phase + ":" + root.message); Qt.quit(); }
  } }
}
''')
            self.assertEqual(self.result(output, "CLEANER_USER_SYSTEM_RESULT:"), {
                "requested": {"title": "Cleaner", "summary": "Clean the system", "steps": [
                    {"label": "Journal", "what": "vacuum", "command": "journalctl"}],
                    "script": "journalctl --vacuum-time=2weeks", "tag": "cleaner"},
                "chained": {"busy": True, "pendingRoot": [], "planIds": ["journal"], "planSize": 12,
                            "status": "ok", "message": "Freed 3 · now the system part"},
                "busy": False, "status": "error", "message": "System part cancelled",
                "pendingRoot": [], "planIds": [], "afterSystem": False,
            })

    def test_root_refresh_waits_for_a_dedicated_scan_when_old_scan_is_running(self):
        source = SERVICE.read_text()
        funcs = self.helpers(source, ("scan", "scanStopped", "finite", "record", "replyError", "failScan",
                                      "acceptScan", "finishRoot"))
        funcs = funcs.replace("Format.shortSize", "String")
        scan_proc = qml_block(source, "Process {\n    id: scanProc").replace(
            'command: ["python3", root.script, "scan"]', "command: root.scanCommand")
        with tempfile.TemporaryDirectory(prefix="cleaner-refresh-queue-") as tmp:
            root = Path(tmp)
            counter = root / "calls"
            script = root / "changing_scan.py"
            script.write_text(
                "import json, pathlib, time\n"
                f"counter = pathlib.Path({str(counter)!r})\n"
                "count = int(counter.read_text()) if counter.exists() else 0\n"
                "counter.write_text(str(count + 1))\n"
                "if count == 0: time.sleep(0.2)\n"
                "size = 10 if count == 0 else 3\n"
                "print(json.dumps({'ok': True, 'total': size, 'categories': ["
                "{'id': 'journal', 'label': 'Journal', 'hint': 'logs', 'size': size, "
                "'root': True, 'safe': True}]}))\n"
            )
            command = json.dumps([sys.executable, str(script)])
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property string script: "unused"
  property var scanCommand: ''' + command + '''
  property var categories: []
  property real total: 0
  property var picked: ({})
  property bool scanning: false
  property real scannedAt: 0
  property bool busy: true
  property string status: ""
  property string message: ""
  property var pendingRoot: []
  property var planIds: ["journal"]
  property real planSize: 10
  property bool afterSystem: false
  property bool systemScanPending: false
  property int phase: 0
  property int ticks: 0
  function done(ok, text) { status = ok ? "ok" : "error"; message = text; }
  function parse(text) { return Reply.parse(text, "cleaner.py"); }
''' + funcs + '\n' + scan_proc + '''
  Timer { interval: 15; repeat: true; running: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) { root.scan(); root.phase = 1; }
    else if (root.phase === 1 && root.scanning) {
      root.finishRoot("cleaner", true, ""); root.phase = 2;
    } else if (root.phase === 2 && !root.busy && !root.scanning) {
      console.warn("CLEANER_REFRESH_QUEUE_RESULT:" + JSON.stringify({status: root.status, message: root.message,
        total: root.total, afterSystem: root.afterSystem, pending: root.systemScanPending}));
      Qt.quit();
    }
    if (root.ticks > 150) { console.warn("CLEANER_REFRESH_QUEUE_TIMEOUT:" + root.phase + ":" + root.message); Qt.quit(); }
  } }
}
''')
            result = self.result(output, "CLEANER_REFRESH_QUEUE_RESULT:")
            self.assertEqual(counter.read_text(), "2")
            self.assertEqual(result, {"status": "ok",
                "message": "Freed 7 from the system", "total": 3,
                "afterSystem": False, "pending": False})

    def test_trash_completion_uses_submitted_paths_after_selection_changes(self):
        source = SERVICE.read_text()
        funcs = self.helpers(source, ("finite", "replyError", "run", "failAction", "acceptAction",
                                      "consumeActionReply"))
        funcs = funcs.replace('actProc.command = ["python3", script].concat(args);',
                              "actProc.command = root.actCommand;").replace("Format.shortSize", "String")
        action_proc = qml_block(source, "Process {\n    id: actProc")
        with tempfile.TemporaryDirectory(prefix="cleaner-trash-snapshot-") as tmp:
            root = Path(tmp)
            script = root / "trash.py"
            script.write_text("import json, time\ntime.sleep(0.2)\nprint(json.dumps({'ok': True, 'freed': 2}))\n")
            command = json.dumps([sys.executable, str(script), "trash", "~/submitted"])
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property string script: "unused"
  property var categories: []
  property real total: 0
  property var suggestions: [
    {path: "~/submitted", size: 2, days: 3, kind: "file", why: "sent", risk: "low"},
    {path: "~/unrelated", size: 4, days: 4, kind: "file", why: "new", risk: "low"}]
  property var aiPicked: ({"~/submitted": true, "~/unrelated": false})
  readonly property var aiChosen: suggestions.filter(s => aiPicked[s.path])
  property bool busy: false
  property var pendingRoot: []
  property string status: ""
  property string message: ""
  property var actCommand: ''' + command + '''
  property int phase: 0
  property int ticks: 0
  function done(ok, text) { status = ok ? "ok" : "error"; message = text; }
  function parse(text) { return Reply.parse(text, "cleaner.py"); }
  function scan() {}
''' + funcs + '\n' + action_proc + '''
  Timer { interval: 15; repeat: true; running: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) {
      root.run(["trash", "~/submitted"]);
      root.aiPicked = ({"~/submitted": false, "~/unrelated": true});
      root.phase = 1;
    } else if (root.phase === 1 && root.status === "ok" && !root.busy) {
      console.warn("CLEANER_TRASH_SNAPSHOT_RESULT:" + JSON.stringify({suggestions: root.suggestions,
        aiPicked: root.aiPicked, message: root.message}));
      Qt.quit();
    }
    if (root.ticks > 150) { console.warn("CLEANER_TRASH_SNAPSHOT_TIMEOUT:" + root.message); Qt.quit(); }
  } }
}
''')
            result = self.result(output, "CLEANER_TRASH_SNAPSHOT_RESULT:")
            self.assertEqual(result, {"suggestions": [{"path": "~/unrelated", "size": 4, "days": 4,
                "kind": "file", "why": "new", "risk": "low"}],
                "aiPicked": {"~/unrelated": True}, "message": "Moved 2 to trash"})


if __name__ == "__main__":
    unittest.main()
