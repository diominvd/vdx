"""Backup ownership, browse cancellation and clipboard with isolated children."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.qml_runtime import SHELL, run_quickshell


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class BackupService(unittest.TestCase):
    def fixture(self, backend, body, extra=""):
        with tempfile.TemporaryDirectory(prefix="shell-backup-service-") as tmp:
            root = Path(tmp)
            (root / "reply.js").write_text((SHELL / "kit/reply.js").read_text())
            script = root / "backend.py"
            script.write_text(backend)
            source = (SHELL / "apps/backup/BackupService.qml").read_text()
            source = source.replace("pragma Singleton", "").replace("import qs.apps.auth", "").replace("import qs.config", "")
            source = source.replace('"../../kit/reply.js"', '"reply.js"').replace("Singleton {", "Scope {", 1)
            source = source.replace('Paths.scriptsDir + "/backup.py"', json.dumps(str(script)))
            source = source.replace("RootService", "rootAuth").replace("Component.onCompleted: loadGuide()", "")
            source = source.replace("  id: root", '''  id: root
  QtObject { id: rootAuth; signal finished(string tag, bool ok, string error)
    function request() { return false; }
  }
''' + extra + "\n" + body, 1)
            (root / "shell.qml").write_text(source)
            output = run_quickshell(root)
            rows = [line.split("BACKUP_RESULT:", 1)[1] for line in output.splitlines() if "BACKUP_RESULT:" in line]
            self.assertEqual(len(rows), 1, output)
            return json.loads(rows[0])

    def test_chained_job_preserves_ownership_and_failed_config_retains_suggestions(self):
        result = self.fixture('''import json, sys
args = sys.argv[1:]
cmd = args[1]
if cmd == "pick": print(json.dumps({"ok": True, "path": "/repository"}))
elif cmd == "init": print(json.dumps({"ok": True, "message": "initialized"}))
else: print(json.dumps({"ok": False, "error": "config rejected"}))
''', '''
  property int phase: 0
  property bool droppedOwnership: false
  onBusyChanged: if (!busy && phase === 1 && message !== "initialized") droppedOwnership = true
  Timer { interval: 20; repeat: true; running: true; property int ticks: 0
    onTriggered: {
      ticks++;
      if (root.phase === 0) { root.phase = 1; root.pick(); }
      else if (root.phase === 1 && !root.busy) {
        root.aiSuggestions = [{path:"/keep", risk:"low"}]; root.aiPicked = ({"/keep":true});
        root.phase = 2; root.aiApply();
      } else if (root.phase === 2 && !root.busy) {
        console.warn("BACKUP_RESULT:" + JSON.stringify({dropped:root.droppedOwnership,
          suggestions:root.aiSuggestions, picked:root.aiPicked, message:root.message})); Qt.quit();
      }
      if (ticks > 100) Qt.quit();
    }
  }
''')
        self.assertEqual(result, {"dropped": False, "suggestions": [{"path": "/keep", "risk": "low"}],
                                  "picked": {"/keep": True}, "message": "config rejected"})

    def test_latest_snapshot_and_leave_discard_old_folder(self):
        result = self.fixture('''import json, sys, time
args = sys.argv[1:]
if args[1] == "ls":
    time.sleep(0.1)
    print(json.dumps({"ok":True, "path":args[3], "entries":[{"name":args[2],"path":"/"+args[2],"dir":False,"size":0,"ts":0}]}))
else: print('{"ok":true,"sizes":{}}')
''', '''
  property int phase: 0
  property var seen: []
  onEntriesChanged: if (entries.length) seen = seen.concat([entries[0].name])
  Timer { interval: 20; repeat: true; running: true; property int ticks: 0
    onTriggered: {
      ticks++;
      if (ticks === 1) { root.browse("old", "/"); root.browse("new", "/"); }
      if (root.phase === 0 && root.entries.length && !root.browsing) {
        root.phase = 1; root.browse("left", "/"); root.browse("queued", "/"); root.leave();
      }
      if (root.phase === 1 && !root.browsing) {
        console.warn("BACKUP_RESULT:" + JSON.stringify({seen:root.seen, entries:root.entries,
          snapshot:root.snapshot, next:root.browseNext})); Qt.quit();
      }
      if (ticks > 100) Qt.quit();
    }
  }
''')
        self.assertEqual(result, {"seen": ["new"], "entries": [], "snapshot": "", "next": None})

    def test_start_failures_release_flags_and_malformed_plan_is_rejected(self):
        result = self.fixture("", '''
  Component.onCompleted: {
    snapsProc.command = ["/no/such/backup-snapshots"];
    root.loadSnapshots();
    lsProc.command = ["/no/such/backup-list"];
    root.browsing = true; lsProc.running = true;
    root.busy = true; root.jobKind = "config";
    jobProc.command = ["/no/such/backup-job"]; jobProc.running = true;
  }
  Timer { interval: 100; running: true; onTriggered: {
    const released = !root.busy && !root.browsing && !root.listing;
    root.finish("rootplan", {ok:true, steps:[null], script:"bad"});
    console.warn("BACKUP_RESULT:" + JSON.stringify({released, message:root.message})); Qt.quit();
  } }
''')
        self.assertEqual(result, {"released": True, "message": "bad backup rootplan reply"})

    def test_read_schemas_preserve_last_good_state(self):
        result = self.fixture("", '''
  Timer { interval: 10; running: true; onTriggered: {
    const goodConfig = {repo:"/repository",sources:{home:true,etc:false,packages:true,root:false},
      extra:[],excludes:[],keep:{on:true,daily:7,weekly:4,monthly:6},
      schedule:{mode:"off",time:"03:00"},notify:true};
    const good = root.acceptStatus({ok:true,config:goodConfig,last:null,configured:true,restic:true,claude:false});
    const saved = root.config;
    const bad = root.acceptStatus({ok:true,config:{repo:3},last:null,configured:true,restic:true,claude:false});
    const entries = root.validEntries([{name:"file",path:"/file",dir:false,size:0,ts:0}]);
    const brokenEntries = root.validEntries([{name:"file",path:"/file",dir:false,size:-1,ts:0}]);
    const snapshots = root.validSnapshots([{id:"abc",short:"abc",ts:0,size:0,tags:[],paths:["/home"]}]);
    const brokenSnapshots = root.validSnapshots([{id:"abc",tags:null}]);
    console.warn("BACKUP_RESULT:" + JSON.stringify({good,bad,retained:root.config === saved,
      configured:root.configured,entries,brokenEntries,snapshots,brokenSnapshots,error:root.loadError})); Qt.quit();
  } }
''')
        self.assertEqual(result, {"good": True, "bad": False, "retained": True, "configured": True,
            "entries": True, "brokenEntries": False, "snapshots": True, "brokenSnapshots": False,
            "error": "bad backup status reply"})

    def test_copy_uses_stdin_and_clears_secret(self):
        result = self.fixture("", '''
  Component.onCompleted: {
    copyProc.command = ["python3", "-c", "import sys; assert sys.stdin.read() == 'secret\\\\nvalue'"];
    root.revealed = "secret\\nvalue"; root.copyPassword();
  }
  Timer { interval: 20; repeat: true; running: true; property int ticks: 0
    onTriggered: {
      ticks++;
      if (root.copied || ticks > 100) {
        console.warn("BACKUP_RESULT:" + JSON.stringify({copied:root.copied, secret:copyProc.secret,
          command:copyProc.command, message:root.message})); Qt.quit();
      }
    }
  }
''')
        self.assertTrue(result["copied"], result)
        self.assertEqual(result["secret"], "")
        self.assertNotIn("secret\nvalue", result["command"])


if __name__ == "__main__":
    unittest.main()
