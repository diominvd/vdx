"""Launcher file queries are serialized and saved tab options are shape-safe."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class LauncherService(unittest.TestCase):
    def _search_fixture(self, root: Path, fd_path: str, actions: str) -> str:
        source = (SHELL / "apps/launcher/LauncherService.qml").read_text()
        functions = "\n".join(qml_function(source, name) for name in (
            "searchFiles", "startFileSearch", "finishFileStartFailure",
            "finishFileSearch", "acceptFiles", "cancelFileSearch",
        ))
        functions = functions.replace(
            '["fd", "--max-results"', '[root.fdPath, "--max-results"', 1)
        process = qml_block(source, "  Process {\n    id: filesProc")
        home = json.dumps(str(root / "home"))
        (root / "home").mkdir()
        return '''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property string fdPath: ''' + json.dumps(fd_path) + '''
  property string home: ''' + home + '''
  property string fileQuery: ""
  property string pendingFileQuery: ""
  property int fileGeneration: 0
  property string fileError: ""
  property bool searching: false
  property var files: []
''' + functions + '\n' + process + '\n' + actions + '''
}
'''

    def _run_search(self, root: Path, fd_path: str, actions: str) -> dict:
        fixture = self._search_fixture(root, fd_path, actions)
        (root / "shell.qml").write_text(fixture)
        output = run_quickshell(root, timeout=8)
        rows = [line.split("LAUNCHER_SEARCH:", 1)[1]
                for line in output.splitlines() if "LAUNCHER_SEARCH:" in line]
        self.assertEqual(len(rows), 1, output)
        return json.loads(rows[0])

    def test_latest_query_wins_and_empty_or_short_query_cancels(self):
        with tempfile.TemporaryDirectory(prefix="launcher-fd-") as tmp:
            root = Path(tmp)
            fd = root / "fd"
            fd.write_text(f'''#!{sys.executable}
import sys, time
args = sys.argv[1:]
query = args[args.index("--") + 1]
home = args[-1]
time.sleep(0.7 if query == "old" else 0.05)
sys.stdout.buffer.write((home + "/" + query + "\\0").encode())
''')
            fd.chmod(0o755)
            result = self._run_search(root, str(fd), '''
  Timer { interval: 0; running: true; onTriggered: {
    root.searchFiles("old");
    replace.start();
  } }
  Timer { id: replace; interval: 40; onTriggered: root.searchFiles("newest") }
  Timer { interval: 450; running: true; onTriggered: {
    const latest = {files, fileQuery, searching, fileError};
    root.files = ["kept result"];
    root.acceptFiles("newest", root.fileGeneration - 1, "stale\\u0000");
    const sameQueryStale = files;
    root.searchFiles("x");
    const short = {files, fileQuery, searching};
    root.searchFiles("cancel-me");
    root.cancelFileSearch();
    later.start();
    root.shortState = short;
    root.latestState = latest;
    root.sameQueryStale = sameQueryStale;
  } }
  Timer { id: later; interval: 150; onTriggered: {
    console.warn("LAUNCHER_SEARCH:" + JSON.stringify({latest: root.latestState,
      sameQueryStale: root.sameQueryStale,
      short: root.shortState, cancelled: {files, searching, fileQuery, fileError}}));
    Qt.quit();
  } }
  property var latestState: ({})
  property var sameQueryStale: []
  property var shortState: ({})
''')
            self.assertEqual(result, {
                "latest": {"files": [str(root / "home") + "/newest"], "fileQuery": "newest",
                           "searching": False, "fileError": ""},
                "sameQueryStale": ["kept result"],
                "short": {"files": [], "fileQuery": "x", "searching": False},
                "cancelled": {"files": [], "searching": False, "fileQuery": "", "fileError": ""},
            })

    def test_literal_query_and_failed_start_recover(self):
        with tempfile.TemporaryDirectory(prefix="launcher-literal-") as tmp:
            root = Path(tmp)
            fd = root / "fd"
            fd.write_text(f'''#!{sys.executable}
import sys
args = sys.argv[1:]
query = args[args.index("--") + 1]
sys.stdout.buffer.write(("literal:" + query + "\\0").encode())
''')
            fd.chmod(0o755)
            result = self._run_search(root, str(fd), '''
  Timer { interval: 0; running: true; onTriggered: { root.searchFiles("a[b"); poll.start(); } }
  Timer { id: poll; interval: 120; onTriggered: {
    const accepted = {files, searching, fileError};
    root.fdPath = "/no/such/fd";
    root.searchFiles("missing");
    failed.start();
    root.acceptedState = accepted;
  } }
  Timer { id: failed; interval: 160; onTriggered: {
    console.warn("LAUNCHER_SEARCH:" + JSON.stringify({accepted: root.acceptedState,
      failed: {files, searching, fileQuery, fileError}}));
    Qt.quit();
  } }
  property var acceptedState: ({})
''')
            self.assertEqual(result, {
                "accepted": {"files": ["literal:a[b"], "searching": False, "fileError": ""},
                "failed": {"files": [], "searching": False, "fileQuery": "missing",
                           "fileError": "could not start file search"},
            })

    def test_saved_tabs_are_filtered_known_and_deduplicated(self):
        source = (SHELL / "apps/launcher/LauncherService.qml").read_text()
        valid = qml_function(source, "validTabList").replace(
            'ModuleSettings.strings("launcher", value, [])', 'root.strings(value)', 1)
        with tempfile.TemporaryDirectory(prefix="launcher-tabs-") as tmp:
            root = Path(tmp)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
Scope {
  id: root
  property var settings: ({order: ["files", "files", "unknown", 12, "apps"], hidden: ["apps", "constructor"]})
  function strings(key) { return Array.isArray(settings[key]) ? settings[key].filter(v => typeof v === "string") : []; }
  readonly property var defaultOrder: ["apps", "files", "shell", "power"]
  readonly property var orderAll: {
    const o = validTabList("order");
    return o.concat(defaultOrder.filter(v => !o.includes(v)));
  }
  readonly property var hiddenTabs: validTabList("hidden")
  readonly property var tabs: orderAll.filter(v => !hiddenTabs.includes(v))
''' + valid + '''
  Timer { interval: 0; running: true; onTriggered: {
    console.warn("LAUNCHER_TABS:" + JSON.stringify({orderAll, hiddenTabs, tabs}));
    Qt.quit();
  } }
}
''')
            output = run_quickshell(root)
            rows = [line.split("LAUNCHER_TABS:", 1)[1]
                    for line in output.splitlines() if "LAUNCHER_TABS:" in line]
            self.assertEqual(len(rows), 1, output)
            self.assertEqual(json.loads(rows[0]), {
                "orderAll": ["files", "apps", "shell", "power"],
                "hiddenTabs": ["apps"], "tabs": ["files", "shell", "power"],
            })


if __name__ == "__main__":
    unittest.main()
