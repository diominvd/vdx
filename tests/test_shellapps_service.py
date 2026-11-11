"""Shell apps replies are validated atomically and process failures can recover."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


SERVICE = SHELL / "apps/shellmanager/ShellAppsService.qml"


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class ShellAppsService(unittest.TestCase):
    def run_fixture(self, root, source):
        (root / "kit").mkdir(exist_ok=True)
        shutil.copy(SHELL / "kit/reply.js", root / "kit/reply.js")
        (root / "shell.qml").write_text(source)
        return run_quickshell(root)

    def result(self, output, marker):
        results = [line.split(marker, 1)[1] for line in output.splitlines() if marker in line]
        self.assertEqual(len(results), 1, output)
        return json.loads(results[0])

    def test_list_schema_is_validated_before_any_snapshot_assignment(self):
        source = SERVICE.read_text()
        handlers = "\n".join(qml_function(source, name) for name in
                               ("finite", "object", "pairs", "validSettings", "acceptListReply"))
        with tempfile.TemporaryDirectory(prefix="shellapps-schema-") as tmp:
            root = Path(tmp)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
Scope {
  id: root
  property var windows: [{id: "kept", title: "Kept", icon: "old", ipc: "old",
    width: 800, height: 600, settings: {}}]
  property var presets: ({small: [0.4, 0.4]})
  property int minWidth: 480
  property int minHeight: 360
  property var spots: ({center: [0.5, 0.5]})
  property int gap: 12
  property int top: 46
  property string error: ""
  property string errorApp: ""
''' + handlers + '''
  Timer { interval: 0; running: true; onTriggered: {
    const row = {id: "new", title: "New", icon: "icon", ipc: "target", width: 900, height: 700,
      settings: {mode: "floating", size: "default", preset: "medium", position: "center",
        width: 900, height: 700, x: 0, y: 0}};
    const valid = {ok: true, apps: [row], presets: {small: [0.5, 0.5], medium: [0.65, 0.7]},
      minWidth: 480, minHeight: 360, spots: {center: [0.5, 0.5]}, gap: 12, top: 46};
    const accepted = acceptListReply(valid);
    const afterValid = {accepted, windows, presets, minWidth, minHeight, spots, gap, top, error};
    const invalid = JSON.parse(JSON.stringify(valid));
    invalid.apps[0].height = 0;
    invalid.presets.large = [0.8, null];
    const rejected = acceptListReply(invalid);
    const afterInvalid = {rejected, windows, presets, minWidth, minHeight, spots, gap, top, error};
    const malformed = JSON.parse(JSON.stringify(valid));
    malformed.apps[0].settings.mode = "strange";
    const malformedSettings = acceptListReply(malformed);
    const malformedError = acceptListReply({ok: false, error: 7});
    const backendFailure = acceptListReply({ok: false, error: "backend failed"});
    const afterBackendFailure = {backendFailure, windows, presets, minWidth, minHeight, spots, gap, top};
    const strictOk = acceptListReply({ok: 1});
    console.warn("SHELLAPPS_SCHEMA_RESULT:" + JSON.stringify({afterValid, afterInvalid,
      malformedSettings, malformedError, afterBackendFailure, strictOk, error}));
    Qt.quit();
  } }
}
''')
            self.assertEqual(self.result(output, "SHELLAPPS_SCHEMA_RESULT:"), {
                "afterValid": {
                    "accepted": True,
                    "windows": [{"id": "new", "title": "New", "icon": "icon", "ipc": "target",
                                 "width": 900, "height": 700,
                                 "settings": {"mode": "floating", "size": "default", "preset": "medium",
                                              "position": "center", "width": 900, "height": 700, "x": 0, "y": 0}}],
                    "presets": {"small": [0.5, 0.5], "medium": [0.65, 0.7]},
                    "minWidth": 480, "minHeight": 360, "spots": {"center": [0.5, 0.5]},
                    "gap": 12, "top": 46, "error": "",
                },
                "afterInvalid": {
                    "rejected": False,
                    "windows": [{"id": "new", "title": "New", "icon": "icon", "ipc": "target",
                                 "width": 900, "height": 700,
                                 "settings": {"mode": "floating", "size": "default", "preset": "medium",
                                              "position": "center", "width": 900, "height": 700, "x": 0, "y": 0}}],
                    "presets": {"small": [0.5, 0.5], "medium": [0.65, 0.7]},
                    "minWidth": 480, "minHeight": 360, "spots": {"center": [0.5, 0.5]},
                    "gap": 12, "top": 46, "error": "bad shell apps list reply",
                },
                "malformedSettings": False, "malformedError": False, "strictOk": False,
                "afterBackendFailure": {
                    "backendFailure": False,
                    "windows": [{"id": "new", "title": "New", "icon": "icon", "ipc": "target",
                                 "width": 900, "height": 700,
                                 "settings": {"mode": "floating", "size": "default", "preset": "medium",
                                              "position": "center", "width": 900, "height": 700, "x": 0, "y": 0}}],
                    "presets": {"small": [0.5, 0.5], "medium": [0.65, 0.7]},
                    "minWidth": 480, "minHeight": 360, "spots": {"center": [0.5, 0.5]},
                    "gap": 12, "top": 46,
                },
                "error": "could not read shell apps",
            })

    def test_list_failed_start_preserves_snapshot_then_retries(self):
        source = SERVICE.read_text()
        process = qml_block(source, "Process {\n    id: listProc").replace(
            'command: ["python3", root.script, "list"]', "command: root.command")
        refresh = qml_function(source, "refresh")
        handlers = "\n".join(qml_function(source, name) for name in
                               ("finite", "object", "pairs", "validSettings", "acceptListReply"))
        valid = {"ok": True, "apps": [{"id": "retry", "title": "Retry", "icon": "i", "ipc": "i",
                  "width": 800, "height": 600,
                  "settings": {"mode": "floating", "size": "default", "preset": "medium",
                               "position": "center", "width": 800, "height": 600, "x": 0, "y": 0}}],
                 "presets": {"small": [0.5, 0.5], "medium": [0.65, 0.7], "large": [0.8, 0.85]},
                 "minWidth": 480, "minHeight": 360, "spots": {"center": [0.5, 0.5]}, "gap": 12, "top": 46}
        command = json.dumps(["python3", "-c", "print(" + json.dumps(json.dumps(valid)) + ")"])
        with tempfile.TemporaryDirectory(prefix="shellapps-list-retry-") as tmp:
            root = Path(tmp)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property var windows: [{id: "kept", title: "Kept", icon: "old", ipc: "old", width: 800, height: 600, settings: {}}]
  property var presets: ({})
  property int minWidth: 480
  property int minHeight: 360
  property var spots: ({})
  property int gap: 12
  property int top: 46
  property string error: ""
  property string errorApp: ""
  property var command: ["/no/such/shellapps-backend"]
  property string launchError: ""
  property var preserved: null
  property int phase: 0
  function parse(text) { return Reply.parse(text, "shellapps.py"); }
''' + refresh + '\n' + handlers + '\n' + process + '''
  Connections { target: root
    function onErrorChanged() {
      if (root.error === "could not start shell apps list query" && root.phase === 0) {
        root.phase = 1;
        root.launchError = root.error;
        root.preserved = root.windows;
        Qt.callLater(function() { root.command = ''' + command + '''; root.error = ""; root.refresh(); });
      }
    }
    function onWindowsChanged() {
      if (root.phase === 1 && root.windows.length === 1 && root.windows[0].id === "retry") {
        console.warn("SHELLAPPS_LIST_RETRY_RESULT:" + JSON.stringify({windows: root.windows,
          error: root.error, launchError: root.launchError, preserved: root.preserved}));
        Qt.quit();
      }
    }
  }
  Component.onCompleted: refresh()
}
''')
            result = self.result(output, "SHELLAPPS_LIST_RETRY_RESULT:")
            self.assertEqual(result["preserved"][0]["id"], "kept")
            self.assertEqual(result["launchError"], "could not start shell apps list query")
            self.assertEqual(result["windows"][0]["id"], "retry")
            self.assertEqual(result["error"], "")

    def test_failed_action_keeps_error_through_failed_refresh_then_success_clears_it(self):
        source = SERVICE.read_text()
        process_list = qml_block(source, "Process {\n    id: listProc").replace(
            'command: ["python3", root.script, "list"]', "command: root.listCommand")
        process_set = qml_block(source, "Process {\n    id: setProc")
        process_set = process_set.replace(
            'setProc.command = ["python3", root.script, "set", app.id, JSON.stringify(change)];',
            "setProc.command = root.actionCommand;")
        refresh = qml_function(source, "refresh")
        set_fn = qml_function(source, "set").replace(
            'setProc.command = ["python3", script, "set", app.id, JSON.stringify(change)];',
            "setProc.command = root.actionCommand;")
        handlers = "\n".join(qml_function(source, name) for name in
                               ("finite", "object", "pairs", "validSettings", "acceptListReply", "failSet"))
        list_failure = json.dumps(["python3", "-c", "print('{\"ok\":false,\"error\":\"refresh failed\"}')"])
        action_success = json.dumps(["python3", "-c", "print('{\"ok\":true}')"])
        list_success = {"ok": True, "apps": [], "presets": {"small": [0.5, 0.5]}, "minWidth": 480,
                        "minHeight": 360, "spots": {"center": [0.5, 0.5]}, "gap": 12, "top": 46}
        list_success_cmd = json.dumps(["python3", "-c", "print(" + json.dumps(json.dumps(list_success)) + ")"])
        with tempfile.TemporaryDirectory(prefix="shellapps-action-retry-") as tmp:
            root = Path(tmp)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property string script: "unused"
  property var windows: []
  property var presets: ({})
  property int minWidth: 480
  property int minHeight: 360
  property var spots: ({})
  property int gap: 12
  property int top: 46
  property bool busy: false
  property string busyApp: ""
  property string error: ""
  property string errorApp: ""
  property var actionCommand: ["/no/such/shellapps-action"]
  property var listCommand: ''' + list_failure + '''
  property bool listDone: false
  property var failure: null
  property int phase: 0
  function parse(text) { return Reply.parse(text, "shellapps.py"); }
''' + refresh + '\n' + set_fn + '\n' + handlers + '\n' + process_list.replace(
            'root.acceptListReply(root.parse(text));', 'root.acceptListReply(root.parse(text)); root.listDone = true;') + '\n' + process_set + '''
  Connections { target: root
    function onListDoneChanged() {
      if (!root.listDone) return;
      if (root.phase === 0) {
        root.failure = {busy: root.busy, busyApp: root.busyApp, error: root.error, errorApp: root.errorApp};
        root.phase = 1;
        Qt.callLater(function() {
          root.listDone = false;
          root.error = "";
          root.actionCommand = ''' + action_success + ''';
          root.listCommand = ''' + list_success_cmd + ''';
          root.set({id: "fixture"}, {});
        });
      } else if (root.phase === 1 && !root.busy && root.error === "" && root.errorApp === "") {
        console.warn("SHELLAPPS_ACTION_RESULT:" + JSON.stringify({failure: root.failure,
          busy: root.busy, busyApp: root.busyApp, error: root.error, errorApp: root.errorApp}));
        Qt.quit();
      }
    }
  }
  Component.onCompleted: set({id: "fixture"}, {})
}
''')
            self.assertEqual(self.result(output, "SHELLAPPS_ACTION_RESULT:"), {
                "failure": {"busy": False, "busyApp": "", "error": "could not start shell app action",
                            "errorApp": "fixture"},
                "busy": False, "busyApp": "", "error": "", "errorApp": "",
            })


if __name__ == "__main__":
    unittest.main()
