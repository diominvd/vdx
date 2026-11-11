"""Verify cursor replies, preview coalescing and process-start recovery."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


SERVICE = SHELL / "apps/shellmanager/CursorService.qml"


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class CursorService(unittest.TestCase):
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

    def test_list_and_preview_schemas_preserve_last_good_data(self):
        source = SERVICE.read_text()
        funcs = "\n".join(qml_function(source, name) for name in
                           ("replyError", "acceptListReply", "acceptPreviewReply"))
        with tempfile.TemporaryDirectory(prefix="shell-cursor-schema-") as tmp:
            root = Path(tmp)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
Scope {
  id: root
  property var cursors: [{id: "old", name: "Old", installed: true}]
  property string base: "Old"
  property int size: 24
  property string mode: "original"
  property string fill: ""
  property string outline: ""
  property string error: ""
  property var shapes: [{name: "old", path: "/old.png", width: 24, height: 24}]
  property string shapesKey: JSON.stringify(["Old", "", ""])
  property string wantedKey: JSON.stringify(["New", "", ""])
  Timer { id: follow; interval: 400 }
''' + funcs + '''
  Timer { interval: 0; running: true; onTriggered: {
    const listOk = acceptListReply({ok: true, base: "New", size: 32, mode: "theme",
      fill: "abcdef", outline: "123456", cursors: [{id: "new", name: "New", installed: false}]});
    const loaded = {listOk, base, size, mode, fill, outline, cursors, error};
    const badSize = acceptListReply({ok: true, base: "Bad", size: 12.5, mode: "original",
      fill: "", outline: "", cursors: []});
    const afterBadSize = {badSize, base, size, cursors, error};
    const badRow = acceptListReply({ok: true, base: "Bad", size: 12, mode: "other",
      fill: "", outline: "", cursors: [{id: "x", name: "X", installed: 1}]});
    const afterBadRow = {badRow, base, size, cursors, error};
    const missingOk = acceptListReply({base: "Bad"});
    const missingError = error;
    const previewOk = acceptPreviewReply(wantedKey, {ok: true, shapes: [
      {name: "new", path: "/new.png", width: 32, height: 48}]});
    const afterPreview = {previewOk, shapes, shapesKey, error};
    const invalidPreview = acceptPreviewReply(wantedKey, {ok: true, shapes: [
      {name: "bad", path: "/bad.png", width: Infinity, height: 20}]});
    const afterInvalidPreview = {invalidPreview, shapes, shapesKey, error};
    const missingPreviewError = acceptPreviewReply(wantedKey, {ok: false});
    console.warn("CURSOR_SCHEMA_RESULT:" + JSON.stringify({loaded, afterBadSize, afterBadRow,
      missingOk, missingError, afterPreview, afterInvalidPreview, missingPreviewError,
      previewError: error}));
    Qt.quit();
  } }
}
''')
            self.assertEqual(self.result(output, "CURSOR_SCHEMA_RESULT:"), {
                "loaded": {"listOk": True, "base": "New", "size": 32, "mode": "theme",
                           "fill": "abcdef", "outline": "123456",
                           "cursors": [{"id": "new", "name": "New", "installed": False}],
                           "error": ""},
                "afterBadSize": {"badSize": False, "base": "New", "size": 32,
                                 "cursors": [{"id": "new", "name": "New", "installed": False}],
                                 "error": "bad cursor list reply"},
                "afterBadRow": {"badRow": False, "base": "New", "size": 32,
                                "cursors": [{"id": "new", "name": "New", "installed": False}],
                                "error": "bad cursor list reply"},
                "missingOk": False, "missingError": "could not read cursor list",
                "afterPreview": {"previewOk": True,
                                 "shapes": [{"name": "new", "path": "/new.png", "width": 32, "height": 48}],
                                 "shapesKey": '["New","",""]', "error": ""},
                "afterInvalidPreview": {"invalidPreview": False,
                                        "shapes": [{"name": "new", "path": "/new.png", "width": 32, "height": 48}],
                                        "shapesKey": '["New","",""]', "error": "bad cursor preview reply"},
                "missingPreviewError": False, "previewError": "could not read cursor preview",
            })

    def test_list_start_failure_preserves_state_and_retry_loads_valid_reply(self):
        source = SERVICE.read_text()
        process = qml_block(source, "Process {\n    id: listProc")
        process = process.replace('command: ["python3", root.script, "list"]',
                                  "command: root.command")
        funcs = "\n".join(qml_function(source, name) for name in
                           ("replyError", "acceptListReply", "refresh"))
        with tempfile.TemporaryDirectory(prefix="shell-cursor-list-retry-") as tmp:
            root = Path(tmp)
            command = json.dumps(["python3", "-c", "import json; print(json.dumps(" +
                                 "{'ok': True, 'base': 'Retry', 'size': 28, 'mode': 'custom', " +
                                 "'fill': 'abcdef', 'outline': '654321', 'cursors': " +
                                 "[{'id': 'retry', 'name': 'Retry', 'installed': True}]}))"])
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property var cursors: [{id: "kept", name: "Kept", installed: true}]
  property string base: "Kept"
  property int size: 24
  property string mode: "original"
  property string fill: ""
  property string outline: ""
  property string error: ""
  property var command: ["/no/such/cursor-backend"]
  property var preserved: null
  function parse(text) { return Reply.parse(text, "cursors.py"); }
''' + funcs + '\n' + process + '''
  property string launchError: ""
  property int phase: 0
  property int ticks: 0
  Timer { interval: 20; running: true; repeat: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) { root.refresh(); root.phase = 1; }
    else if (root.phase === 1 && root.error !== "") {
      root.launchError = root.error;
      root.preserved = {base: root.base, size: root.size, cursors: root.cursors};
      root.error = ""; root.command = ''' + command + ''';
      root.refresh(); root.phase = 2;
    } else if (root.phase === 2 && root.base === "Retry") {
      console.warn("CURSOR_LIST_RESULT:" + JSON.stringify({base: root.base, size: root.size,
        mode: root.mode, fill: root.fill, outline: root.outline, cursors: root.cursors,
        error: root.error, launchError: root.launchError, preserved: root.preserved}));
      Qt.quit();
    }
    if (root.ticks > 150) { console.warn("CURSOR_LIST_TIMEOUT:" + root.error); Qt.quit(); }
  } }
}
''')
            result = self.result(output, "CURSOR_LIST_RESULT:")
            self.assertEqual(result.pop("preserved"), {
                "base": "Kept", "size": 24,
                "cursors": [{"id": "kept", "name": "Kept", "installed": True}],
            })
            self.assertEqual(result, {
                "base": "Retry", "size": 28, "mode": "custom", "fill": "abcdef",
                "outline": "654321", "cursors": [{"id": "retry", "name": "Retry", "installed": True}],
                "error": "", "launchError": "could not start cursor list query",
            })

    def test_preview_start_retry_stale_reply_and_failed_key_retry(self):
        source = SERVICE.read_text()
        process = qml_block(source, "Process {\n    id: previewProc")
        funcs = "\n".join(qml_function(source, name) for name in
                           ("replyError", "acceptPreviewReply", "startWantedPreview", "colours", "preview"))
        funcs = funcs.replace(
            'previewProc.command = ["python3", script, "preview", base].concat(fill ? [fill, outline] : []);',
            'previewProc.command = failStart ? ["/no/such/cursor-preview"] : ["python3", script, "preview", base].concat(fill ? [fill, outline] : []);')
        script_body = '''import json, pathlib, sys, time
base = sys.argv[2]
with open(%r, "a") as log:
    log.write(base + "\\n")
if base == "Slow Theme":
    time.sleep(0.25)
if base == "Broken":
    marker = pathlib.Path(%r)
    count = int(marker.read_text()) if marker.exists() else 0
    marker.write_text(str(count + 1))
    if count == 0:
        print(json.dumps({"ok": False, "error": "preview rejected"}))
        raise SystemExit
print(json.dumps({"ok": True, "shapes": [{"name": base, "path": "/" + base + ".png", "width": 32, "height": 32}]}))
'''
        with tempfile.TemporaryDirectory(prefix="shell-cursor-preview-") as tmp:
            root = Path(tmp)
            script = root / "preview.py"
            log = root / "preview.log"
            count = root / "broken-count"
            script.write_text(script_body % (str(log), str(count)))
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property string script: "/no/such/preview.py"
  property string error: ""
  property var shapes: [{name: "Old", path: "/Old.png", width: 20, height: 20}]
  property string shapesKey: "Old  "
  property string wantedKey: ""
  property bool failStart: true
  function parse(text) { return Reply.parse(text, "cursors.py"); }
''' + funcs + '\n' + process + '''
  property int phase: 0
  property int ticks: 0
  property var newestShape: null
  property var failedState: null
  Timer { interval: 20; running: true; repeat: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) {
      root.preview("LaunchFail", "original", ""); root.phase = 1;
    } else if (root.phase === 1 && root.error === "could not start cursor preview") {
      root.failStart = false;
      root.script = ''' + json.dumps(str(script)) + ''';
      root.error = ""; root.preview("LaunchFail", "original", ""); root.phase = 2;
    } else if (root.phase === 2 && root.shapesKey === JSON.stringify(["LaunchFail", "", ""])) {
      root.preview("Slow Theme", "original", ""); root.phase = 3;
    } else if (root.phase === 3 && previewProc.running) {
      root.preview("Newest Theme", "original", ""); root.phase = 4;
    } else if (root.phase === 4 && root.shapesKey === JSON.stringify(["Newest Theme", "", ""])) {
      root.newestShape = root.shapes[0];
      root.preview("Broken", "original", ""); root.phase = 5;
    } else if (root.phase === 5 && root.error === "preview rejected") {
      root.failedState = {shapes: root.shapes, shapesKey: root.shapesKey};
      root.error = ""; root.preview("Broken", "original", ""); root.phase = 6;
    } else if (root.phase === 6 && root.shapesKey === JSON.stringify(["Broken", "", ""])) {
      console.warn("CURSOR_PREVIEW_RESULT:" + JSON.stringify({shapes: root.shapes,
        shapesKey: root.shapesKey, wantedKey: root.wantedKey, error: root.error,
        newestShape: root.newestShape, failedState: root.failedState}));
      Qt.quit();
    }
    if (root.ticks > 250) { console.warn("CURSOR_PREVIEW_TIMEOUT:" + root.error); Qt.quit(); }
  } }
}
''')
            self.assertEqual(self.result(output, "CURSOR_PREVIEW_RESULT:"), {
                "shapes": [{"name": "Broken", "path": "/Broken.png", "width": 32, "height": 32}],
                "shapesKey": '["Broken","",""]', "wantedKey": '["Broken","",""]', "error": "",
                "newestShape": {"name": "Newest Theme", "path": "/Newest Theme.png", "width": 32, "height": 32},
                "failedState": {"shapes": [{"name": "Newest Theme", "path": "/Newest Theme.png", "width": 32, "height": 32}],
                                "shapesKey": '["Newest Theme","",""]'},
            })
            self.assertEqual(log.read_text().splitlines(),
                             ["LaunchFail", "Slow Theme", "Newest Theme", "Broken", "Broken"])

    def test_action_start_failure_retry_install_set_and_mismatch_rejection(self):
        source = SERVICE.read_text()
        process = qml_block(source, "Process {\n    id: actProc")
        funcs = "\n".join(qml_function(source, name) for name in
                           ("replyError", "failAction", "acceptActionReply", "run", "set", "apply"))
        script_body = '''import json, sys
action = sys.argv[1]
name = "Wrong" if action == "install" and sys.argv[2] == "Other" else "Fixture"
with open(%r, "a") as log:
    log.write(" ".join(sys.argv[1:]) + "\\n")
print(json.dumps({"ok": True, "name": name}))
'''
        with tempfile.TemporaryDirectory(prefix="shell-cursor-action-") as tmp:
            root = Path(tmp)
            script = root / "action.py"
            log = root / "actions.log"
            script.write_text(script_body % str(log))
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property string script: ''' + json.dumps(str(script)) + '''
  property string error: ""
  property bool busy: false
  property string working: ""
  property var pending: null
  property string base: ""
  property int size: 24
  property string mode: "original"
  property string fill: ""
  property string outline: ""
  property int refreshes: 0
  property int phase: 0
  property int ticks: 0
  property string launchError: ""
  function parse(text) { return Reply.parse(text, "cursors.py"); }
  function colours(mode, custom) { return ["", ""]; }
  function refresh() { refreshes++; }
''' + funcs + '\n' + process + '''
  Timer { interval: 20; running: true; repeat: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) {
      root.busy = true; root.working = "Fixture";
      root.pending = {base: "Fixture", size: 24, mode: "original", custom: ""};
      actProc.command = ["/no/such/cursor-backend"]; actProc.running = true;
      root.phase = 1;
    } else if (root.phase === 1 && root.error === "could not start cursor action") {
      root.launchError = root.error; root.error = "";
      root.apply({name: "Fixture", installed: false}, 24, "original", "");
      root.phase = 2;
    } else if (root.phase === 2 && !root.busy && root.base === "") {
      root.apply({name: "Other", installed: false}, 24, "original", "");
      root.phase = 3;
    } else if (root.phase === 3 && !root.busy && root.error === "bad cursor install reply") {
      const mismatch = {busy: root.busy, working: root.working, pending: root.pending, error: root.error};
      root.busy = true; root.working = "Fixture";
      root.pending = {base: "Fixture", size: 24, mode: "original", custom: ""};
      const malformedOk = root.acceptActionReply({ok: 1}, "set");
      const malformed = {malformedOk, busy: root.busy, working: root.working,
        pending: root.pending, error: root.error};
      console.warn("CURSOR_ACTION_RESULT:" + JSON.stringify({mismatch, malformed,
        launchError: root.launchError, refreshes: root.refreshes}));
      Qt.quit();
    }
    if (root.ticks > 200) { console.warn("CURSOR_ACTION_TIMEOUT:" + root.error); Qt.quit(); }
  } }
}
''')
            self.assertEqual(self.result(output, "CURSOR_ACTION_RESULT:"), {
                "mismatch": {"busy": False, "working": "", "pending": None,
                             "error": "bad cursor install reply"},
                "malformed": {"malformedOk": False, "busy": False, "working": "",
                              "pending": None, "error": "cursor action failed"},
                "launchError": "could not start cursor action", "refreshes": 1,
            })
            self.assertEqual(log.read_text().splitlines(),
                             ["install Fixture", "set Fixture 24 original", "install Other"])


if __name__ == "__main__":
    unittest.main()
