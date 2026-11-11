"""Verify font replies preserve state and process failures can be retried."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


SERVICE = SHELL / "apps/shellmanager/FontService.qml"


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class FontService(unittest.TestCase):
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

    def test_list_schema_preserves_previous_data_and_clears_error_on_success(self):
        source = SERVICE.read_text()
        handler = qml_function(source, "acceptListReply")
        with tempfile.TemporaryDirectory(prefix="shell-font-schema-") as tmp:
            root = Path(tmp)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
Scope {
  id: root
  property string current: "Old Font"
  property var fonts: [{id: "old", family: "Old Font", installed: true}]
  property string error: "old error"
''' + handler + '''
  Timer { interval: 0; running: true; onTriggered: {
    const valid = acceptListReply({ok: true, current: "New Font", fonts: [
      {id: "new", family: "New Font", installed: false}]});
    const afterValid = {valid, current, fonts, error};
    const invalid = acceptListReply({ok: true, current: 7, fonts: []});
    const afterInvalid = {invalid, current, fonts, error};
    const malformedRow = acceptListReply({ok: true, current: "Bad", fonts: [
      {id: "bad", family: "Bad", installed: "yes"}]});
    const afterMalformed = {malformedRow, current, fonts, error};
    const malformedId = acceptListReply({ok: true, current: "Bad", fonts: [
      {id: 9, family: "Bad", installed: true}]});
    const malformedFamily = acceptListReply({ok: true, current: "Bad", fonts: [
      {id: "bad", family: null, installed: true}]});
    const failed = acceptListReply({ok: false, error: "backend failed"});
    const failedError = error;
    const truthyOk = acceptListReply({ok: 1});
    const missingError = {truthyOk, error};
    console.warn("FONT_SCHEMA_RESULT:" + JSON.stringify({afterValid, afterInvalid, afterMalformed, malformedId, malformedFamily, failed, failedError, current, fonts, error, missingError}));
    Qt.quit();
  } }
}
''')
            self.assertEqual(self.result(output, "FONT_SCHEMA_RESULT:"), {
                "afterValid": {"valid": True, "current": "New Font",
                               "fonts": [{"id": "new", "family": "New Font", "installed": False}],
                               "error": ""},
                "afterInvalid": {"invalid": False, "current": "New Font",
                                 "fonts": [{"id": "new", "family": "New Font", "installed": False}],
                                 "error": "bad font list reply"},
                "afterMalformed": {"malformedRow": False, "current": "New Font",
                                   "fonts": [{"id": "new", "family": "New Font", "installed": False}],
                                   "error": "bad font list reply"},
                "malformedId": False, "malformedFamily": False,
                "failed": False, "failedError": "backend failed", "current": "New Font",
                "fonts": [{"id": "new", "family": "New Font", "installed": False}],
                "error": "could not read fonts",
                "missingError": {"truthyOk": False, "error": "could not read fonts"},
            })

    def test_list_start_failure_preserves_state_and_retry_loads_data(self):
        source = SERVICE.read_text()
        process = qml_block(source, "Process {\n    id: listProc")
        process = process.replace('command: ["python3", root.script, "list"]',
                                  "command: root.command")
        handler = qml_function(source, "acceptListReply")
        refresh = qml_function(source, "refresh")
        with tempfile.TemporaryDirectory(prefix="shell-font-list-retry-") as tmp:
            root = Path(tmp)
            command = json.dumps(["python3", "-c",
                                  "print('{\"ok\":true,\"current\":\"Retry Font\",\"fonts\":[{\"id\":\"retry\",\"family\":\"Retry Font\",\"installed\":true}]}')"])
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property string current: "Kept Font"
  property var fonts: [{id: "kept", family: "Kept Font", installed: true}]
  property string error: ""
  property var command: ["/no/such/font-backend"]
  property var preserved: null
  function parse(text) { return Reply.parse(text, "fonts.py"); }
''' + refresh + '\n' + handler + '\n' + process + '''
  property string launchError: ""
  property int phase: 0
  property int ticks: 0
  Timer { interval: 20; running: true; repeat: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) { root.refresh(); root.phase = 1; }
    else if (root.phase === 1 && root.error !== "") {
      root.launchError = root.error;
      root.preserved = {current: root.current, fonts: root.fonts};
      root.error = "";
      root.command = ''' + command + ''';
      root.refresh();
      root.phase = 2;
    } else if (root.phase === 2 && root.current === "Retry Font") {
      console.warn("FONT_LIST_RETRY_RESULT:" + JSON.stringify({
        current: root.current, fonts: root.fonts, error: root.error,
        launchError: root.launchError,
        preserved: root.preserved
      }));
      Qt.quit();
    }
    if (root.ticks > 150) { console.warn("FONT_LIST_RETRY_TIMEOUT:" + root.error); Qt.quit(); }
  } }
}
''')
            result = self.result(output, "FONT_LIST_RETRY_RESULT:")
            self.assertEqual(result["preserved"], {
                "current": "Kept Font",
                "fonts": [{"id": "kept", "family": "Kept Font", "installed": True}],
            })
            del result["preserved"]
            self.assertEqual(result, {
                "current": "Retry Font",
                "fonts": [{"id": "retry", "family": "Retry Font", "installed": True}],
                "error": "", "launchError": "could not start font list query",
            })

    def test_install_then_set_uses_real_process_and_mismatched_family_stops_chain(self):
        source = SERVICE.read_text()
        process = qml_block(source, "Process {\n    id: actProc")
        run = qml_function(source, "run")
        script_body = '''import json, sys
action = sys.argv[1]
family = "Different Font" if len(sys.argv) > 2 and sys.argv[2] == "wrong" else "Fixture Font"
with open(%r, "a") as log:
    log.write(action + "\\n")
print(json.dumps({"ok": True, "family": family}))
'''
        with tempfile.TemporaryDirectory(prefix="shell-font-action-") as tmp:
            root = Path(tmp)
            script = root / "font_backend.py"
            log = root / "actions.log"
            script.write_text(script_body % str(log))
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property string script: ''' + json.dumps(str(script)) + '''
  property string working: "Fixture Font"
  property string error: ""
  property bool busy: true
  property string saved: ""
  property int reloads: 0
  property int phase: 0
  property int ticks: 0
  function parse(text) { return Reply.parse(text, "fonts.py"); }
''' + run + '''
''' + qml_function(source, "failAction") + '''
  function refresh() { reloads++; }
  function restartShell() { reloads += 100; }
''' + process.replace("ShellSettings.set(\"font\", family)", "root.saved = family") \
                .replace("!Qt.fontFamilies().includes(family)", "false") + '''
  property string launchError: ""
  Timer { interval: 20; running: true; repeat: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) {
      root.busy = true; root.working = "Fixture Font";
      actProc.command = ["/no/such/font-backend"]; actProc.running = true;
      root.phase = 1;
    } else if (root.phase === 1 && root.error === "could not start font action") {
      root.launchError = root.error;
      root.error = ""; root.busy = true; root.working = "Fixture Font";
      root.run(["install", "fixture"]);
      root.phase = 2;
    } else if (root.phase === 2 && root.saved === "Fixture Font" && !root.busy) {
      root.error = ""; root.busy = true; root.working = "Fixture Font";
      root.run(["install", "wrong"]);
      root.phase = 3;
    } else if (root.phase === 3 && !root.busy && root.error === "bad font install reply") {
      console.warn("FONT_ACTION_RESULT:" + JSON.stringify({busy: root.busy,
        working: root.working, error: root.error, saved: root.saved, reloads: root.reloads,
        launchError: root.launchError}));
      Qt.quit();
    }
    if (root.ticks > 150) { console.warn("FONT_ACTION_TIMEOUT:" + root.error); Qt.quit(); }
  } }
}
''')
            self.assertEqual(self.result(output, "FONT_ACTION_RESULT:"), {
                "busy": False, "working": "", "error": "bad font install reply",
                "saved": "Fixture Font", "reloads": 1,
                "launchError": "could not start font action",
            })
            self.assertEqual(log.read_text().splitlines(), ["install", "set", "install"])


if __name__ == "__main__":
    unittest.main()
