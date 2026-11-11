"""The floating launcher view exists only for the scrim and remembers navigation."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class LauncherLifecycle(unittest.TestCase):
    def test_panel_is_lazy_through_fade_and_restores_navigation_once(self):
        source = (SHELL / "apps/launcher/Launcher.qml").read_text()
        controller = qml_block(source, "  QtObject {\n    id: app")
        loader = qml_block(source, "    Loader {\n      id: panelLoader")
        loader = loader.replace("        LauncherPanel {", '''        Item {
          signal back()
          signal finished()
          property string tab: "apps"
          property string query: ""
          property int current: 0
          function reset(state) { resets++; if (state) { tab = state.tab; query = state.query; current = state.current; } }
          function saveState() { return {tab, query, current}; }
          function closePanel() { closes++; }
          Component.onCompleted: created++
          Component.onDestruction: destroyed++''', 1)
        with tempfile.TemporaryDirectory(prefix="launcher-life-") as tmp:
            root = Path(tmp)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
Scope {
  id: root
  property bool open: false
  property bool fade: false
  readonly property bool visible: open || fade
  property bool fromIsland: false
  property int panelWidth: 640
  property string position: "center"
  property int created: 0
  property int destroyed: 0
  property int resets: 0
  property int closes: 0
  function close() { open = false; }
  onOpenChanged: if (open) app.opened(); else { app.closed(); root.fade = true; }
''' + controller + '\n' + loader + '''
  Timer { interval: 0; running: true; onTriggered: {
    const initial = {created, loaded: panelLoader.item !== null};
    root.open = true;
    first.start();
  } }
  Timer { id: first; interval: 80; onTriggered: {
    panelLoader.item.tab = "files";
    panelLoader.item.query = "meeting notes";
    panelLoader.item.current = 3;
    root.open = false;
    root.fade = true;
    const fading = {loaded: panelLoader.item !== null, closes, navigation: app.navigation};
    root.fade = false;
    closed.start();
    root.fadingState = fading;
  } }
  Timer { id: closed; interval: 50; onTriggered: {
    const closedState = {loaded: panelLoader.item !== null, created, destroyed, closes};
    root.open = true;
    reopened.start();
    root.closedState = closedState;
  } }
  Timer { id: reopened; interval: 80; onTriggered: {
    const restored = panelLoader.item ? {tab: panelLoader.item.tab, query: panelLoader.item.query,
      current: panelLoader.item.current} : null;
    const result = {initial: root.initialState, fading: root.fadingState, closed: root.closedState,
      restored, created, destroyed, resets, closes, loaded: panelLoader.item !== null};
    console.warn("LAUNCHER_LIFETIME:" + JSON.stringify(result));
    Qt.quit();
  } }
  property var initialState: ({created: 0, loaded: false})
  property var fadingState: ({})
  property var closedState: ({})
  Component.onCompleted: initialState = {created, loaded: panelLoader.item !== null}
}
''')
            output = run_quickshell(root)
            rows = [line.split("LAUNCHER_LIFETIME:", 1)[1]
                    for line in output.splitlines() if "LAUNCHER_LIFETIME:" in line]
            self.assertEqual(len(rows), 1, output)
            self.assertEqual(json.loads(rows[0]), {
                "initial": {"created": 0, "loaded": False},
                "fading": {"loaded": True, "closes": 1, "navigation": {
                    "tab": "files", "query": "meeting notes", "current": 3}},
                "closed": {"loaded": False, "created": 1, "destroyed": 1, "closes": 1},
                "restored": {"tab": "files", "query": "meeting notes", "current": 3},
                "created": 2, "destroyed": 1, "resets": 2, "closes": 1, "loaded": True,
            })

    def test_clear_on_close_policy_controls_restored_query_and_tab(self):
        source = (SHELL / "apps/launcher/LauncherPanel.qml").read_text()
        reset = qml_function(source, "reset").replace("Hypr.englishLayout()", "root.layoutChanges++")
        reset = reset.replace("field.input.forceActiveFocus()", "root.focusCount++")
        save = qml_function(source, "saveState")
        with tempfile.TemporaryDirectory(prefix="launcher-panel-state-") as tmp:
            root = Path(tmp)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
Scope {
  id: root
  property bool clearOnClose: false
  property bool english: false
  property string opens: "apps"
  property string tab: "apps"
  property int current: 0
  property bool closed: true
  property int layoutChanges: 0
  property int focusCount: 0
  property var tabs: [{value:"apps"}, {value:"files"}]
  QtObject { id: field; property string text: "" }
  Timer { id: filesTimer; interval: 200 }
  property string query: field.text.trim().toLowerCase()
''' + reset + '\n' + save + '''
  Timer { interval: 0; running: true; onTriggered: {
    reset(null);
    tab = "files";
    field.text = "Project X";
    current = 2;
    const saved = saveState();
    reset(saved);
    const preserved = {tab, text: field.text, current};
    clearOnClose = true;
    reset(saved);
    console.warn("LAUNCHER_PANEL_STATE:" + JSON.stringify({preserved,
      cleared: {tab, text: field.text, current}}));
    Qt.quit();
  } }
}
''')
            try:
                output = run_quickshell(root)
            except subprocess.TimeoutExpired as exc:
                self.fail(f"launcher panel fixture timed out: {exc.stdout!r} {exc.stderr!r}")
            rows = [line.split("LAUNCHER_PANEL_STATE:", 1)[1]
                    for line in output.splitlines() if "LAUNCHER_PANEL_STATE:" in line]
            self.assertEqual(len(rows), 1, output)
            self.assertEqual(json.loads(rows[0]), {
                "preserved": {"tab": "files", "text": "Project X", "current": 2},
                "cleared": {"tab": "apps", "text": "", "current": 0},
            })


if __name__ == "__main__":
    unittest.main()
