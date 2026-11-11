"""Verify task list validation and isolated process action recovery."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


SERVICE = SHELL / "apps/taskmanager/TaskManagerService.qml"


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class TaskManagerService(unittest.TestCase):
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

    def test_list_schema_is_atomic_and_bad_replies_do_not_extend_history(self):
        source = SERVICE.read_text()
        funcs = "\n".join(qml_function(source, name) for name in
                           ("replyError", "validListReply", "acceptListReply", "keep", "record"))
        with tempfile.TemporaryDirectory(prefix="shell-task-schema-") as tmp:
            root = Path(tmp)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
Scope {
  id: root
  property var procs: [{pid: 9, ppid: 1, name: "old", user: "u", cmd: "old",
    mine: true, kernel: false, cpu: 2, mem: 3, threads: 1}]
  property real cpu: 10
  property real memUsed: 20
  property real memTotal: 100
  property real gpu: 5
  property real rx: 2
  property real tx: 3
  property int historyLength: 60
  property var cpuHistory: [10]
  property var memHistory: [20]
  property var gpuHistory: [4]
  property var rxHistory: [1]
  property var txHistory: [2]
  property string queryError: ""
  property string actionError: ""
  readonly property string error: actionError || queryError
''' + funcs + '''
  Timer { interval: 0; running: true; onTriggered: {
    const valid = {ok: true, cpu: 25, memUsed: 40, memTotal: 200,
      procs: [{pid: 12, ppid: 1, name: "ok", user: "u", cmd: "ok --test",
        mine: true, kernel: false, cpu: 1, mem: 2, threads: 3}]};
    const accepted = root.acceptListReply(valid);
    const committed = {accepted, procs: root.procs, cpu: root.cpu,
      memUsed: root.memUsed, memTotal: root.memTotal, cpuHistory: root.cpuHistory};
    const malformed = root.acceptListReply({ok: true, cpu: 101, memUsed: 0,
      memTotal: 1, procs: valid.procs});
    const afterMalformed = {malformed, procs: root.procs, cpu: root.cpu,
      memUsed: root.memUsed, memTotal: root.memTotal, cpuHistory: root.cpuHistory, error: root.error};
    const missingError = root.acceptListReply({ok: false});
    console.warn("TASK_LIST_SCHEMA:" + JSON.stringify({committed, afterMalformed,
      missingError, fallbackError: root.error}));
    Qt.quit();
  } }
}
''')
            self.assertEqual(self.result(output, "TASK_LIST_SCHEMA:"), {
                "committed": {"accepted": True,
                              "procs": [{"pid": 12, "ppid": 1, "name": "ok", "user": "u",
                                         "cmd": "ok --test", "mine": True, "kernel": False,
                                         "cpu": 1, "mem": 2, "threads": 3}],
                              "cpu": 25, "memUsed": 40, "memTotal": 200,
                              "cpuHistory": [10, 25]},
                "afterMalformed": {"malformed": False,
                                   "procs": [{"pid": 12, "ppid": 1, "name": "ok", "user": "u",
                                              "cmd": "ok --test", "mine": True, "kernel": False,
                                              "cpu": 1, "mem": 2, "threads": 3}],
                                   "cpu": 25, "memUsed": 40, "memTotal": 200,
                                   "cpuHistory": [10, 25], "error": "bad task list reply"},
                "missingError": False, "fallbackError": "could not read task list",
            })

    def test_list_start_retry_then_malformed_reply_keeps_last_snapshot(self):
        source = SERVICE.read_text()
        process = qml_block(source, "Process {\n    id: listProc").replace(
            'command: ["python3", root.script, "list"]', "command: root.listCommand")
        funcs = "\n".join(qml_function(source, name) for name in
                           ("replyError", "validListReply", "acceptListReply", "keep", "record", "refresh"))
        row = {"pid": 21, "ppid": 1, "name": "fixture", "user": "u", "cmd": "fixture",
               "mine": True, "kernel": False, "cpu": 3, "mem": 4, "threads": 2}
        good_reply = json.dumps({"ok": True, "cpu": 30, "memUsed": 50, "memTotal": 200,
                                 "procs": [row]})
        bad_reply = json.dumps({"ok": True, "cpu": 105, "memUsed": 60, "memTotal": 200,
                                "procs": [row]})
        with tempfile.TemporaryDirectory(prefix="shell-task-list-retry-") as tmp:
            root = Path(tmp)
            good_command = json.dumps(["python3", "-c", "print(" + json.dumps(good_reply) + ")"])
            bad_command = json.dumps(["python3", "-c", "print(" + json.dumps(bad_reply) + ")"])
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property string script: "/unused"
  property var procs: [{pid: 9, ppid: 1, name: "old", user: "u", cmd: "old",
    mine: true, kernel: false, cpu: 1, mem: 2, threads: 1}]
  property real cpu: 10
  property real memUsed: 20
  property real memTotal: 100
  property real gpu: 0
  property real rx: 0
  property real tx: 0
  property int historyLength: 60
  property var cpuHistory: [10]
  property var memHistory: [20]
  property var gpuHistory: []
  property var rxHistory: []
  property var txHistory: []
  property string queryError: ""
  property string actionError: ""
  readonly property string error: actionError || queryError
  property var listCommand: ["/no/such/task-list"]
  property var preserved: null
  property int phase: 0
  property int ticks: 0
  function parse(text) { return Reply.parse(text, "tasks.py"); }
''' + funcs + '\n' + process + '''
  Timer { interval: 20; running: true; repeat: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) { root.refresh(); root.phase = 1; }
    else if (root.phase === 1 && root.error === "could not start task list query") {
      root.preserved = {procs: root.procs, cpu: root.cpu, cpuHistory: root.cpuHistory};
      root.listCommand = ''' + good_command + ''';
      root.refresh(); root.phase = 2;
    } else if (root.phase === 2 && root.procs.length === 1 && root.procs[0].pid === 21 && root.error === "") {
      root.listCommand = ''' + bad_command + ''';
      root.refresh(); root.phase = 3;
    } else if (root.phase === 3 && root.error === "bad task list reply") {
      console.warn("TASK_LIST_RECOVERY:" + JSON.stringify({preserved: root.preserved,
        procs: root.procs, cpu: root.cpu, memUsed: root.memUsed,
        memTotal: root.memTotal, cpuHistory: root.cpuHistory, error: root.error}));
      Qt.quit();
    }
    if (root.ticks > 200) { console.warn("TASK_LIST_TIMEOUT:" + root.error); Qt.quit(); }
  } }
}
''')
            result = self.result(output, "TASK_LIST_RECOVERY:")
            self.assertEqual(result["preserved"], {
                "procs": [{"pid": 9, "ppid": 1, "name": "old", "user": "u", "cmd": "old",
                           "mine": True, "kernel": False, "cpu": 1, "mem": 2, "threads": 1}],
                "cpu": 10, "cpuHistory": [10],
            })
            del result["preserved"]
            self.assertEqual(result, {
                "procs": [row], "cpu": 30, "memUsed": 50, "memTotal": 200,
                "cpuHistory": [10, 30], "error": "bad task list reply",
            })

    def test_kill_start_failure_clears_busy_and_retry_accepts_only_valid_count(self):
        source = SERVICE.read_text()
        process = qml_block(source, "Process {\n    id: killProc")
        end_row = qml_function(source, "endRow").replace(
            'killProc.command = ["python3", script, "kill", force ? "KILL" : "TERM"].concat(row.pids.map(String));',
            "killProc.command = root.killCommand;")
        funcs = "\n".join(qml_function(source, name) for name in
                           ("replyError", "finishKill", "acceptKillReply", "keep", "record"))
        reply = json.dumps({"ok": True, "killed": 1})
        good_command = json.dumps(["python3", "-c", "print(" + json.dumps(reply) + ")"])
        list_reply = json.dumps({"ok": True, "cpu": 1, "memUsed": 10, "memTotal": 100,
                                 "procs": []})
        with tempfile.TemporaryDirectory(prefix="shell-task-kill-") as tmp:
            root = Path(tmp)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property bool busy: false
  property string status: ""
  property string queryError: ""
  property string actionError: ""
  readonly property string error: actionError || queryError
  property string notice: ""
  property var killCommand: ["/no/such/task-kill"]
  property var selectedRow: ({pids: [21]})
  property int refreshes: 0
  property string errorAfterList: ""
  property var malformed: null
  property int phase: 0
  property int ticks: 0
  function refresh() { refreshes++; root.acceptListReply(''' + list_reply + '''); if (root.status === "error") errorAfterList = root.error; }
  function parse(text) { return JSON.parse(text); }
  Timer { id: statusReset; interval: 10000 }
  property var procs: []
  property real cpu: 0
  property real memUsed: 0
  property real memTotal: 1
  property real gpu: 0
  property real rx: 0
  property real tx: 0
  property int historyLength: 60
  property var cpuHistory: []
  property var memHistory: []
  property var gpuHistory: []
  property var rxHistory: []
  property var txHistory: []
''' + funcs + '\n' + qml_function(source, "validListReply") + '\n'
                + qml_function(source, "acceptListReply") + '\n' + end_row + '\n' + process + '''
  Timer { interval: 20; running: true; repeat: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) { root.endRow({pids: [21]}, false); root.phase = 1; }
    else if (root.phase === 1 && root.error === "could not start task action") {
      root.killCommand = ''' + good_command + ''';
      root.endRow({pids: [21]}, false); root.phase = 2;
    } else if (root.phase === 2 && !root.busy && root.status === "ok") {
      const success = {busy: root.busy, status: root.status, error: root.error,
        refreshes: root.refreshes, errorAfterList: root.errorAfterList};
      root.busy = true;
      const accepted = root.acceptKillReply({ok: true, killed: -1});
      root.malformed = {accepted, busy: root.busy, status: root.status, error: root.error};
      console.warn("TASK_KILL_RESULT:" + JSON.stringify({success, malformed: root.malformed}));
      Qt.quit();
    }
    if (root.ticks > 200) { console.warn("TASK_KILL_TIMEOUT:" + root.error); Qt.quit(); }
  } }
}
''')
            self.assertEqual(self.result(output, "TASK_KILL_RESULT:"), {
                "success": {"busy": False, "status": "ok", "error": "", "refreshes": 2,
                            "errorAfterList": "could not start task action"},
                "malformed": {"accepted": False, "busy": False, "status": "error",
                              "error": "bad task kill reply"},
            })

    def test_copy_notice_waits_for_process_success_and_failure_is_visible(self):
        source = SERVICE.read_text()
        process = qml_block(source, "Process {\n    id: copyProc")
        copy_pid = qml_function(source, "copyPid").replace(
            'copyProc.command = ["wl-copy", String(row.pids[0])];',
            'copyProc.command = [root.copyExecutable, String(row.pids[0])];')
        with tempfile.TemporaryDirectory(prefix="shell-task-copy-") as tmp:
            root = Path(tmp)
            denied = root / "denied-copy"
            denied.write_text("#!/bin/sh\necho clipboard denied >&2\nexit 7\n")
            denied.chmod(0o700)
            success = root / "good-copy"
            success.write_text("#!/bin/sh\nexit 0\n")
            success.chmod(0o700)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property bool grouped: false
  property var selectedRow: ({pids: [321]})
  property string status: ""
  property string queryError: ""
  property string actionError: ""
  readonly property string error: actionError || queryError
  property string notice: ""
  property string copyExecutable: "/no/such/wl-copy"
  property int phase: 0
  property int ticks: 0
  property string noticeWhileRunning: ""
  property string startError: ""
  property string failedNotice: ""
  Timer { id: statusReset; interval: 10000 }
''' + copy_pid + '\n' + process + '''
  Timer { interval: 20; running: true; repeat: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) { root.copyPid(); root.phase = 1; }
    else if (root.phase === 1 && root.error === "could not start PID copy") {
      root.startError = root.error;
      root.copyExecutable = ''' + json.dumps(str(denied)) + ''';
      root.copyPid(); root.phase = 2;
    } else if (root.phase === 2 && copyProc.running && root.noticeWhileRunning === "") {
      root.noticeWhileRunning = root.notice;
    } else if (root.phase === 2 && root.error === "clipboard denied") {
      root.failedNotice = root.notice;
      root.copyExecutable = ''' + json.dumps(str(success)) + ''';
      root.copyPid(); root.phase = 3;
    } else if (root.phase === 3 && copyProc.running && root.noticeWhileRunning === "") {
      root.noticeWhileRunning = root.notice;
    } else if (root.phase === 3 && root.status === "ok" && root.notice !== "") {
      console.warn("TASK_COPY_RESULT:" + JSON.stringify({startError: root.startError,
        noticeWhileRunning: root.noticeWhileRunning, failedNotice: root.failedNotice,
        status: root.status, error: root.error, notice: root.notice}));
      Qt.quit();
    }
    if (root.ticks > 250) { console.warn("TASK_COPY_TIMEOUT:" + root.error); Qt.quit(); }
  } }
}
''')
            self.assertEqual(self.result(output, "TASK_COPY_RESULT:"), {
                "startError": "could not start PID copy", "noticeWhileRunning": "",
                "failedNotice": "", "status": "ok", "error": "", "notice": "PID 321 copied",
            })


if __name__ == "__main__":
    unittest.main()
