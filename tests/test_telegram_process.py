"""Production Telegram worker with fake stdin helpers; no API calls or secrets."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.qml_runtime import SHELL, run_quickshell


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class TelegramProcess(unittest.TestCase):
    def fixture(self, body):
        with tempfile.TemporaryDirectory(prefix="shell-telegram-worker-") as tmp:
            root = Path(tmp)
            helper = root / "telegram.py"
            helper.write_text('''import json, sys
payload = json.load(sys.stdin)
if sys.argv[1] == "send":
    print(json.dumps({"ok":False, "error":"Rate limited", "retryAfter":30}))
else:
    print(json.dumps({"ok":True, "configured":True, "connected":True,
        "username":"fixture_bot", "pairUrl":""}))
''')
            for name in ("reply.js", "markup.js"):
                shutil.copy(SHELL / "kit" / name, root / name)
            shutil.copy(SHELL / "modules/notifications/telegram_rules.js", root / "telegram_rules.js")
            config = root / "config"
            config.mkdir()
            (config / "qmldir").write_text("singleton ModuleSettings 1.0 ModuleSettings.qml\n")
            (config / "ModuleSettings.qml").write_text('''pragma Singleton
import QtQuick
QtObject {
  property bool enabled: true
  function get(module, key, fallback) { return key === "enabled" ? enabled : fallback; }
  function set(module, key, value) { if (key === "enabled") enabled = value; }
}
''')
            source = (SHELL / "modules/notifications/TelegramService.qml").read_text()
            source = source.replace("pragma Singleton", "").replace("Singleton {", "Scope {", 1)
            source = source.replace("import qs.config", 'import "config"')
            source = source.replace("../../kit/", "")
            source = source.replace('Paths.scriptsDir + "/telegram.py"', json.dumps(str(helper)))
            source = source.replace('  id: root', '  id: root\n  property bool failStart: false\n  readonly property string pendingPayload: proc.payload', 1)
            source = source.replace('proc.command = ["python3", root.script, action];',
                                    'proc.command = root.failStart ? ["/no/such/telegram-worker"] : ["python3", root.script, action];')
            (root / "TelegramWorker.qml").write_text(source)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
Scope {
  id: fixture
  TelegramWorker { id: svc }
  property int phase: 0
  property int ticks: 0
  property var result: ({})
  Timer { interval: 20; repeat: true; running: true; onTriggered: {
    fixture.ticks++;
''' + body + '''
    if (fixture.ticks > 150) { console.warn("TELEGRAM_RESULT:" + JSON.stringify({timeout:true})); Qt.quit(); }
  } }
}
''')
            output = run_quickshell(root)
            rows = [line.split("TELEGRAM_RESULT:", 1)[1] for line in output.splitlines() if "TELEGRAM_RESULT:" in line]
            self.assertEqual(len(rows), 1, output)
            return json.loads(rows[0])

    def test_failed_start_clears_secret_and_can_run_connect_then_test(self):
        result = self.fixture('''
    if (fixture.phase === 0) {
      fixture.phase = 1;
      svc.failStart = true;
      svc.run("connect", {token:"fake-token"});
    } else if (fixture.phase === 1 && !svc.busy) {
      fixture.result = {failed:svc.error !== "", cleared:svc.pendingPayload === ""};
      fixture.phase = 2;
      svc.failStart = false;
      svc.run("connect", {token:"fake-token"});
    } else if (fixture.phase === 2 && !svc.busy) {
      fixture.result.connected = svc.connected;
      fixture.phase = 3;
      svc.run("test", {});
    } else if (fixture.phase === 3 && !svc.busy) {
      fixture.result.status = svc.status;
      fixture.result.error = svc.error;
      fixture.result.clearedAfterSuccess = svc.pendingPayload === "";
      console.warn("TELEGRAM_RESULT:" + JSON.stringify(fixture.result));
      Qt.quit();
    }
''')
        self.assertEqual(result, {"failed": True, "cleared": True, "connected": True,
                                  "status": "Test sent", "error": "", "clearedAfterSuccess": True})

    def test_rate_limit_drops_queue_and_page_refresh_preserves_error(self):
        result = self.fixture('''
    if (fixture.phase === 0) {
      fixture.phase = 1;
      svc.queue = [{key:"pending", text:"fake notice", at:Date.now()}];
      svc.run("send", {text:"fake notice"});
    } else if (fixture.phase === 1 && !svc.busy) {
      fixture.result = {queued:svc.queue.length, cooldown:svc.nextSendAt > Date.now()+29000};
      fixture.phase = 2;
      svc.refresh();
    } else if (fixture.phase === 2 && !svc.busy) {
      fixture.result.error = svc.error;
      fixture.result.cleared = svc.pendingPayload === "";
      console.warn("TELEGRAM_RESULT:" + JSON.stringify(fixture.result));
      Qt.quit();
    }
''')
        self.assertEqual(result, {"queued": 0, "cooldown": True, "error": "Rate limited", "cleared": True})


if __name__ == "__main__":
    unittest.main()
