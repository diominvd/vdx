"""Validate package service replies without invoking package or root commands."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


SERVICE = SHELL / "apps/packages/PackagesService.qml"


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class PackagesService(unittest.TestCase):
    def run_fixture(self, root: Path, source: str) -> str:
        (root / "kit").mkdir(exist_ok=True)
        shutil.copy(SHELL / "kit/reply.js", root / "kit/reply.js")
        (root / "shell.qml").write_text(source)
        return run_quickshell(root)

    def result(self, output: str, marker: str):
        results = [line.split(marker, 1)[1] for line in output.splitlines() if marker in line]
        self.assertEqual(len(results), 1, output)
        return json.loads(results[0])

    def helpers(self, source: str, names: tuple[str, ...]) -> str:
        return "\n".join(qml_function(source, name) for name in names)

    def test_schemas_preserve_snapshots_and_bad_plan_never_reaches_root(self):
        source = SERVICE.read_text()
        names = ("replyError", "finiteNonnegative", "stringField", "validUpdates", "acceptCheck",
                 "validInstalled", "acceptInstalled", "validCache", "acceptCache", "validLast",
                 "acceptLast", "acceptProgress", "validPlan", "acceptPlan", "failPlan")
        helpers = self.helpers(source, names).replace("RootService.request", "root.requestRoot")
        pacman = [{"name": "foo", "from": "1", "to": "2", "desc": "foo", "repo": "extra", "size": 10}]
        aur = [{"name": "bar", "from": "1", "to": "2", "desc": "bar", "repo": "aur"}]
        installed = [{"name": "foo", "version": "2", "desc": "foo", "size": 20, "date": 30,
                      "aur": False, "repo": "extra", "explicit": True, "apps": ["Foo"]}]
        cache = [{"name": "foo", "installed": "2", "versions": [
            {"version": "2", "file": "/cache/foo", "size": 20, "date": 30}]}]
        last = {"ok": True, "date": "today", "packages": [
            {"name": "foo", "from": "1", "to": "2", "file": "/cache/foo-1"}], "missing": []}
        with tempfile.TemporaryDirectory(prefix="packages-schema-") as tmp:
            root = Path(tmp)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
Scope {
  id: root
  property var pacman: [{name:"kept", from:"1", to:"2", desc:"old", repo:"extra", size:1}]
  property var aur: []
  property string aurError: "old"
  property bool checking: true
  property real checkedAt: 7
  property var installed: [{name:"kept", version:"1", desc:"old", size:1, date:1,
    aur:false, repo:"extra", explicit:true, apps:[]}]
  property bool loading: true
  property var cache: [{name:"kept", installed:"1", versions:[]}]
  property var lastUpdate: ({date:"old", packages:[], missing:[]})
  property bool busy: true
  property string status: ""
  property string message: ""
  property string stage: ""
  property int rootRequests: 0
  property var planValue: null
  function done(ok, text) { status = ok ? "ok" : "error"; message = text; }
  function requestRoot() { rootRequests++; return true; }
  function skipPanel(tag) { return false; }
  function endStage(ok, text) { done(ok, text); stage = ""; busy = false; }
''' + helpers + '''
  Timer { interval: 0; running: true; onTriggered: {
    const beforeCheck = root.pacman;
    const goodCheck = root.acceptCheck({ok:true, pacman:''' + json.dumps(pacman) + ''',
      aur:''' + json.dumps(aur) + ''', aurError:""});
    const checkSnapshot = {goodCheck, pacman:root.pacman, aur:root.aur, checkedAt:root.checkedAt};
    const checkedAtAfterGood = root.checkedAt;
    const oldCheck = root.pacman;
    const badCheck = root.acceptCheck({ok:true, pacman:[{name:"bad",from:"1",to:"2",desc:"x",repo:"r",size:Infinity}],
      aur:[], aurError:""});
    const checkPreserved = !badCheck && root.pacman === oldCheck;
    const goodInstalled = root.acceptInstalled({ok:true, packages:''' + json.dumps(installed) + '''});
    const oldInstalled = root.installed;
    const badInstalled = root.acceptInstalled({ok:true, packages:[{name:"bad",size:NaN}]});
    const installedPreserved = !badInstalled && root.installed === oldInstalled;
    const goodCache = root.acceptCache({ok:true, packages:''' + json.dumps(cache) + '''});
    const oldCache = root.cache;
    const badCache = root.acceptCache({ok:true, packages:[{name:"bad",installed:"",versions:[{size:Infinity}]}]});
    const cachePreserved = !badCache && root.cache === oldCache;
    const goodLast = root.acceptLast(''' + json.dumps(last) + ''');
    const oldLast = root.lastUpdate;
    const badLast = root.acceptLast({ok:true,date:"",packages:[{name:4}],missing:[]});
    const lastPreserved = !badLast && root.lastUpdate === oldLast;
    root.stage = "downloading"; root.stageDone = 4;
    const badProgress = root.acceptProgress({ok:true,bytes:Infinity});
    const progressPreserved = !badProgress && root.stageDone === 4;
    root.busy = true;
    const badPlan = root.acceptPlan({ok:true,steps:[{label:"bad",what:"x",command:3}],script:"x"},
      {title:"Remove",tag:"packages-remove"});
    const badPlanWasIsolated = !badPlan && root.rootRequests === 0;
    root.busy = true;
    const goodPlan = root.acceptPlan({ok:true,steps:[{label:"Remove",what:"x",command:"echo"}],script:"echo"},
      {title:"Remove",tag:"packages-remove"});
    console.warn("PACKAGES_SCHEMA:" + JSON.stringify({checkSnapshot, checkPreserved,
      installedPreserved, goodInstalled, cachePreserved, goodCache, lastPreserved, goodLast,
      progressPreserved, badPlanWasIsolated, goodPlan, rootRequests:root.rootRequests,
      checking:root.checking, loading:root.loading, checkedAtAfterGood, checkedAt:root.checkedAt}));
    Qt.quit();
  } }
  property real stageDone: 0
}
''')
            result = self.result(output, "PACKAGES_SCHEMA:")
            self.assertEqual({k: v for k, v in result["checkSnapshot"].items() if k != "checkedAt"},
                             {"goodCheck": True, "pacman": pacman, "aur": aur})
            self.assertGreater(result["checkSnapshot"]["checkedAt"], 7)
            self.assertTrue(result["checkPreserved"])
            self.assertTrue(result["installedPreserved"] and result["goodInstalled"])
            self.assertTrue(result["cachePreserved"] and result["goodCache"])
            self.assertTrue(result["lastPreserved"] and result["goodLast"])
            self.assertTrue(result["progressPreserved"])
            self.assertTrue(result["badPlanWasIsolated"] and result["goodPlan"])
            self.assertEqual(result["rootRequests"], 1)
            self.assertFalse(result["checking"] or result["loading"])
            self.assertGreater(result["checkedAtAfterGood"], 7)
            self.assertEqual(result["checkedAt"], result["checkedAtAfterGood"])

    def test_update_process_commits_only_after_valid_reply_and_releases_checking_last(self):
        source = SERVICE.read_text()
        check = qml_block(source, "Process {\n    id: checkProc").replace(
            'command: ["python3", root.script, "updates"]', "command: root.checkCommand")
        funcs = self.helpers(source, ("replyError", "finiteNonnegative", "stringField",
                                     "validUpdates", "acceptCheck", "check"))
        with tempfile.TemporaryDirectory(prefix="packages-check-") as tmp:
            root = Path(tmp)
            script = root / "query.py"
            invalid = {"ok": True, "pacman": [{"name": "bad"}], "aur": [], "aurError": ""}
            script.write_text("print(" + repr(json.dumps(invalid)) + ")\n")
            command = json.dumps([sys.executable, str(script)])
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property string script: "unused"
  property var checkCommand: ["/no/such/packages"]
  property var pacman: [{name:"kept",from:"1",to:"2",desc:"old",repo:"extra",size:1}]
  property var aur: []
  property string aurError: "old"
  property bool checking: false
  property real checkedAt: 12
  property string status: ""
  property string message: ""
  function parse(text) { return Reply.parse(text, "packages.py"); }
  function done(ok, text) { status = ok ? "ok" : "error"; message = text; }
''' + funcs + '\n' + check + '''
  Timer { interval: 20; running: true; repeat: true; property int ticks: 0
    onTriggered: {
      ticks++;
      if (ticks === 1) { root.checkCommand = ''' + command + '''; root.check(); }
      if (!root.checking && root.message === "bad package update reply") {
        console.warn("PACKAGES_CHECK_PROCESS:" + JSON.stringify({checking:root.checking,
          pacman:root.pacman, aur:root.aur, aurError:root.aurError, checkedAt:root.checkedAt,
          status:root.status, message:root.message}));
        Qt.quit();
      }
      if (ticks > 200) { console.warn("PACKAGES_CHECK_TIMEOUT:" + root.message); Qt.quit(); }
    }
  }
}
''')
            result = self.result(output, "PACKAGES_CHECK_PROCESS:")
            self.assertEqual(result, {"checking": False, "pacman": [{"name":"kept", "from":"1", "to":"2",
                             "desc":"old", "repo":"extra", "size":1}], "aur": [], "aurError":"old",
                             "checkedAt":12, "status":"error", "message":"bad package update reply"})

    def test_plan_start_failure_releases_busy_after_meaningful_error(self):
        source = SERVICE.read_text()
        process = qml_block(source, "Process {\n    id: planProc").replace(
            "id: planProc", 'id: planProc\n    command: ["/no/such/package-plan"]\n    running: true', 1)
        helpers = self.helpers(source, ("failPlan",))
        with tempfile.TemporaryDirectory(prefix="packages-plan-start-") as tmp:
            root = Path(tmp)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property bool busy: true
  property string stage: ""
  property string status: ""
  property string message: ""
  property int resets: 0
  function done(ok, text) { status = ok ? "ok" : "error"; message = text; }
  function endStage(ok, text) { done(ok, text); stage = ""; busy = false; }
''' + helpers + '\n' + process + '''
  Timer { interval: 100; running: true; onTriggered: {
    console.warn("PACKAGES_PLAN_START:" + JSON.stringify({busy:root.busy,
      status:root.status, message:root.message}));
    Qt.quit();
  } }
}
''')
            self.assertEqual(self.result(output, "PACKAGES_PLAN_START:"), {
                "busy": False, "status": "error", "message": "could not start package action plan",
            })


if __name__ == "__main__":
    unittest.main()
