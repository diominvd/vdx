"""Reject broken metric snapshots before replacing the previous baseline."""
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.check_shell_ui import qml_function
from tests.qml_runtime import SHELL, run_quickshell


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class SysmonService(unittest.TestCase):
    def test_atomic_samples_and_bounded_percent(self):
        source = (SHELL / "modules/sysmon/SysmonService.qml").read_text()
        functions = "\n".join(qml_function(source, n) for n in ("percent", "validSnapshot", "take"))
        with tempfile.TemporaryDirectory(prefix="shell-sysmon-") as tmp:
            root = Path(tmp)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
Scope {
  property var last: null
  property int cpu: 0
  property var cores: []
  property int uptime: 0
''' + functions + '''
  Timer { interval: 10; running: true; onTriggered: {
    const first = take({cpu:[[100,40],[100,40]],uptime:10});
    const full = {cpu:[[100,40]],uptime:10,freq:2400,load:[0,0,0],
      mem:{total:100,available:60,swapTotal:0,swapFree:0},igpu:null,dgpu:{state:"none"},
      temps:{cpu:null,nvme:[],wifi:null},fans:[],disks:[],net:null,io:{read:0,write:0}};
    const fullAccepted = validSnapshot(full);
    delete full.io;
    const partialRejected = !validSnapshot(full);
    const old = last;
    const invalid = [null, {}, {cpu:[null],uptime:12}, {cpu:[[101,41]],uptime:12,mem:{}},
      {cpu:[[102,42]],uptime:12,mem:{total:1,available:2,swapTotal:0,swapFree:0}}];
    const rejected = invalid.every(s => take(s) === false);
    const retained = last === old;
    const second = take({cpu:[[120,45],[120,45]],uptime:11});
    console.warn("SYSMON_RESULT:" + JSON.stringify({first,fullAccepted,partialRejected,rejected,retained,second,cpu,cores,
      reset:percent([10,5],[20,10]), bound:percent([30,4],[20,10])}));
    Qt.quit();
  } }
}
''')
            output = run_quickshell(root)
            rows = [line.split("SYSMON_RESULT:", 1)[1] for line in output.splitlines() if "SYSMON_RESULT:" in line]
            self.assertEqual(len(rows), 1, output)
            self.assertEqual(json.loads(rows[0]), {"first": True, "fullAccepted": True, "partialRejected": True, "rejected": True, "retained": True,
                "second": True, "cpu": 75, "cores": [75], "reset": 0, "bound": 100})
