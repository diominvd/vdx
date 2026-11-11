"""The capture window loads its library only while open and keeps navigation."""
import json
from pathlib import Path
import re
import shutil
import tempfile
import unittest

from tests.check_shell_ui import qml_block
from tests.qml_runtime import SHELL, run_quickshell


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class CaptureWindowLifecycle(unittest.TestCase):
    def test_restored_video_selection_starts_probe_after_rows_arrive(self):
        source = (SHELL / "apps/capture/CaptureLibrary.qml").read_text()
        handler = qml_block(source, "  onSelectedChanged: {")
        with tempfile.TemporaryDirectory(prefix="capture-select-") as tmp:
            root = Path(tmp)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
Scope {
  property var items: []
  property string selectedPath: "/video.mp4"
  readonly property var selected: items.find(item => item.path === selectedPath) ?? null
  property string thumbDir: "/unused"
  QtObject { id: probe; property string path: "" }
  QtObject {
    id: thumbs
    property bool ready: false
    property string target: ""
    function make(video, png) { target = png; }
  }
''' + handler + '''
  Timer { interval: 0; running: true; onTriggered: {
    const before = probe.path;
    items = [{path: "/video.mp4", name: "video.mp4", video: true}];
    const loaded = probe.path;
    selectedPath = "/image.png";
    console.warn("CAPTURE_SELECTION:" + JSON.stringify({before, loaded,
      after: probe.path, ready: thumbs.ready}));
    Qt.quit();
  } }
}
''')
            output = run_quickshell(root)
            rows = [line.split("CAPTURE_SELECTION:", 1)[1] for line in output.splitlines() if "CAPTURE_SELECTION:" in line]
            self.assertEqual(len(rows), 1, output)
            self.assertEqual(json.loads(rows[0]), {"before": "", "loaded": "/video.mp4", "after": "", "ready": False})

    def test_lazy_creation_teardown_and_navigation_restore(self):
        source = (SHELL / "apps/capture/CaptureWindow.qml").read_text()
        controller = qml_block(source, "QtObject {\n    id: app")
        loader = qml_block(source, "Loader {\n    id: library")
        loader = re.sub(r"    anchors \{.*?\n    \}\n", "    anchors.fill: parent\n", loader, count=1, flags=re.S)
        loader = loader.replace("CaptureLibrary { anchors.fill: parent }", '''Item {
        property string query: ""
        property string sortKey: "date"
        property bool sortDesc: true
        property string selectedPath: ""
        property var items: []
        function refresh() { root.refreshes++; }
        Component.onCompleted: root.created++
        Component.onDestruction: root.destroyed++
      }''')
        with tempfile.TemporaryDirectory(prefix="shell-capture-life-") as tmp:
            root = Path(tmp)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
Scope {
  id: root
  property bool visible: false
  property int created: 0
  property int destroyed: 0
  property int refreshes: 0
''' + controller + '\n' + loader + '''
  Timer { interval: 0; running: true; onTriggered: {
    const initial = {created, refreshes, loaded: library.item !== null};
    root.visible = true;
    app.shown();
    const firstOpen = {query: library.item.query, sortKey: library.item.sortKey,
      sortDesc: library.item.sortDesc, selectedPath: library.item.selectedPath, refreshes};
    library.item.query = "meeting";
    library.item.sortKey = "size";
    library.item.sortDesc = false;
    library.item.selectedPath = "/capture/meeting.png";
    app.hidden();
    root.visible = false;
    const closed = {created, destroyed, refreshes, loaded: library.item !== null,
      navigation: {query: app.query, sortKey: app.sortKey, sortDesc: app.sortDesc,
        selectedPath: app.selectedPath}};
    root.visible = true;
    app.shown();
    const restored = {query: library.item.query, sortKey: library.item.sortKey,
      sortDesc: library.item.sortDesc, selectedPath: library.item.selectedPath, refreshes};
    app.hidden();
    root.visible = false;
    console.warn("CAPTURE_LIFETIME:" + JSON.stringify({initial, firstOpen, closed, restored,
      created, destroyed, refreshes, loaded: library.item !== null}));
    Qt.quit();
  } }
}
''')
            output = run_quickshell(root)
            rows = [line.split("CAPTURE_LIFETIME:", 1)[1]
                    for line in output.splitlines() if "CAPTURE_LIFETIME:" in line]
            self.assertEqual(len(rows), 1, output)
            self.assertEqual(json.loads(rows[0]), {
                "initial": {"created": 0, "refreshes": 0, "loaded": False},
                "firstOpen": {"query": "", "sortKey": "date", "sortDesc": True,
                              "selectedPath": "", "refreshes": 1},
                "closed": {"created": 1, "destroyed": 1, "refreshes": 1,
                           "loaded": False, "navigation": {
                               "query": "meeting", "sortKey": "size", "sortDesc": False,
                               "selectedPath": "/capture/meeting.png"}},
                "restored": {"query": "meeting", "sortKey": "size", "sortDesc": False,
                             "selectedPath": "/capture/meeting.png", "refreshes": 2},
                "created": 2, "destroyed": 2, "refreshes": 2, "loaded": False,
            })


if __name__ == "__main__":
    unittest.main()
