"""Capture trash work survives the view and media probes publish only current results."""
from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import unittest
from unittest import mock

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


def capture_backend():
    script = SHELL / "scripts/capture.py"
    spec = importlib.util.spec_from_file_location("capture_library_backend", script)
    module = importlib.util.module_from_spec(spec)
    with mock.patch.object(sys, "path", [str(script.parent), *sys.path]):
        spec.loader.exec_module(module)
    return module


class CaptureTrashBackend(unittest.TestCase):
    def test_trash_reports_partial_success_for_paths_with_spaces(self):
        with tempfile.TemporaryDirectory(prefix="capture-trash-") as tmp:
            root = Path(tmp)
            bindir = root / "bin"
            bindir.mkdir()
            log = root / "gio.log"
            gio = bindir / "gio"
            gio.write_text(f'''#!{sys.executable}
import pathlib, sys
pathlib.Path({str(log)!r}).open("a").write(sys.argv[-1] + "\\n")
if "failed" in sys.argv[-1]:
    sys.stderr.write("fake trash failure")
    raise SystemExit(1)
''')
            gio.chmod(0o755)
            first = str(root / "capture one.png")
            second = str(root / "failed capture.mp4")
            with mock.patch.dict(os.environ, {"PATH": str(bindir)}):
                reply = capture_backend().trash([first, second])
            self.assertEqual(reply, {
                "ok": False,
                "moved": [first],
                "failed": [{"path": second, "error": "fake trash failure"}],
            })
            self.assertEqual(log.read_text().splitlines(), [first, second])


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class CaptureLibraryProcesses(unittest.TestCase):
    def test_list_start_failure_clears_loading(self):
        source = (SHELL / "apps/capture/CaptureLibrary.qml").read_text()
        refresh = qml_function(source, "refresh")
        listing = qml_block(source, "  Process {\n    id: list")
        listing = re.sub(r'command: \["sh", "-c",.*?CaptureService\.videoDir\]',
                         'command: ["/no/such/capture-list"]', listing, count=1, flags=re.S)
        with tempfile.TemporaryDirectory(prefix="capture-list-start-") as tmp:
            root = Path(tmp)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property bool loading: false
  property bool refreshPending: false
  property string error: ""
  property string selectedPath: ""
  property var items: []
''' + refresh + '\n' + listing + '''
  Timer { interval: 0; running: true; onTriggered: root.refresh() }
  Timer { interval: 160; running: true; onTriggered: {
    console.warn("CAPTURE_LIST_START:" + JSON.stringify({loading, error}));
    Qt.quit();
  } }
}
''')
            output = run_quickshell(root)
            rows = [line.split("CAPTURE_LIST_START:", 1)[1]
                    for line in output.splitlines() if "CAPTURE_LIST_START:" in line]
            self.assertEqual(len(rows), 1, output)
            self.assertEqual(json.loads(rows[0]), {
                "loading": False, "error": "Could not start capture library listing",
            })

    def test_service_fifo_continues_after_view_closes_and_reports_failures(self):
        source = (SHELL / "apps/capture/CaptureService.qml").read_text()
        functions = "\n".join(qml_function(source, name) for name in (
            "moveToTrash", "startTrash", "finishTrash", "failTrashStart",
        )).replace('["python3", saveScript, "trash"]', '[root.pythonCommand, saveScript, "trash"]')
        process = qml_block(source, "  Process {\n    id: trashProc")
        with tempfile.TemporaryDirectory(prefix="capture-trash-service-") as tmp:
            root = Path(tmp)
            log = root / "requests.log"
            script = root / "fake-trash.py"
            script.write_text(f'''#!{sys.executable}
import json, pathlib, sys, time
paths = sys.argv[2:]
with pathlib.Path({str(log)!r}).open("a") as stream:
    stream.write("\\n".join(paths) + "\\n")
time.sleep(0.18 if paths[0] == "first" else 0.02)
failed = ([{{"path": path, "error": "fake failure"}} for path in paths if path == "failed"])
moved = [path for path in paths if path != "failed"]
print(json.dumps({{"ok": not failed, "moved": moved, "failed": failed}}))
raise SystemExit(bool(failed))
''')
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property var trashQueue: []
  property var trashCurrent: []
  property bool trashBusy: false
  property string trashError: ""
  property var trashLastResult: ({ok:true, moved:[], failed:[]})
  readonly property bool trashPending: trashBusy || trashQueue.length > 0
  property string saveScript: ''' + json.dumps(str(script)) + '''
  property string pythonCommand: "python3"
  property bool viewLoaded: true
  property int finishedCount: 0
  signal trashFinished(var result)
  onTrashFinished: finishedCount++
''' + functions + '\n' + process + '''
  Timer { interval: 0; running: true; onTriggered: {
    root.moveToTrash(["first"]);
    root.moveToTrash(["failed"]);
    root.viewLoaded = false;
    poll.start();
  } }
  Timer { id: poll; interval: 20; repeat: true; onTriggered: if (!root.trashPending) {
    console.warn("CAPTURE_TRASH_FIFO:" + JSON.stringify({viewLoaded, trashBusy, trashQueue,
      trashError, trashLastResult, finishedCount}));
    Qt.quit();
  } }
}
''')
            output = run_quickshell(root)
            rows = [line.split("CAPTURE_TRASH_FIFO:", 1)[1]
                    for line in output.splitlines() if "CAPTURE_TRASH_FIFO:" in line]
            self.assertEqual(len(rows), 1, output)
            self.assertEqual(json.loads(rows[0]), {
                "viewLoaded": False, "trashBusy": False, "trashQueue": [],
                "trashError": "failed: fake failure",
                "trashLastResult": {"ok": False, "moved": [],
                                    "failed": [{"path": "failed", "error": "fake failure"}]},
                "finishedCount": 2,
            })
            self.assertEqual(log.read_text().splitlines(), ["first", "failed"])

    def test_failed_trash_process_start_recovers_busy_state(self):
        source = (SHELL / "apps/capture/CaptureService.qml").read_text()
        functions = "\n".join(qml_function(source, name) for name in (
            "moveToTrash", "startTrash", "finishTrash", "failTrashStart",
        )).replace('["python3", saveScript, "trash"]', '[root.pythonCommand, saveScript, "trash"]')
        process = qml_block(source, "  Process {\n    id: trashProc")
        with tempfile.TemporaryDirectory(prefix="capture-trash-start-") as tmp:
            root = Path(tmp)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property var trashQueue: []
  property var trashCurrent: []
  property bool trashBusy: false
  property string trashError: ""
  property var trashLastResult: ({ok:true, moved:[], failed:[]})
  readonly property bool trashPending: trashBusy || trashQueue.length > 0
  property string saveScript: "/unused"
  property string pythonCommand: "/no/such/capture-python"
  signal trashFinished(var result)
''' + functions + '\n' + process + '''
  Timer { interval: 0; running: true; onTriggered: root.moveToTrash(["path"]); }
  Timer { interval: 180; running: true; onTriggered: {
    console.warn("CAPTURE_TRASH_START:" + JSON.stringify({trashBusy, trashPending, trashError,
      trashLastResult}));
    Qt.quit();
  } }
}
''')
            output = run_quickshell(root)
            rows = [line.split("CAPTURE_TRASH_START:", 1)[1]
                    for line in output.splitlines() if "CAPTURE_TRASH_START:" in line]
            self.assertEqual(len(rows), 1, output)
            reply = json.loads(rows[0])
            self.assertFalse(reply["trashBusy"])
            self.assertFalse(reply["trashPending"])
            self.assertIn("could not start", reply["trashError"])

    def test_thumbnail_and_probe_results_follow_latest_selection(self):
        source = (SHELL / "apps/capture/CaptureLibrary.qml").read_text()
        thumbs = qml_block(source, "  Process {\n    id: thumbs")
        thumbs = re.sub(r'command = \["sh", "-c",.*?\];',
                        'command = ["python3", root.thumbScript, target, requestVideo];',
                        thumbs, count=1, flags=re.S)
        probe = qml_block(source, "  Process {\n    id: probe")
        probe = probe.replace(
            'command = ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", requestPath];',
            'command = ["python3", root.probeScript, requestPath];', 1)
        with tempfile.TemporaryDirectory(prefix="capture-media-probes-") as tmp:
            root = Path(tmp)
            thumb_log = root / "thumbs.log"
            (root / "thumb.py").write_text(f'''#!{sys.executable}
import pathlib, sys, time
png, video = sys.argv[1:]
with pathlib.Path({str(thumb_log)!r}).open("a") as stream: stream.write(video + "\\n")
time.sleep(0.20 if video.endswith("A.mp4") else 0.02)
''')
            (root / "probe.py").write_text(f'''#!{sys.executable}
import pathlib, sys, time
video = sys.argv[1]
time.sleep(0.20 if video.endswith("A.mp4") else 0.02)
print("10" if video.endswith("A.mp4") else "20")
''')
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property string thumbScript: ''' + json.dumps(str(root / "thumb.py")) + '''
  property string probeScript: ''' + json.dumps(str(root / "probe.py")) + '''
''' + thumbs + '\n' + probe + '''
  Timer { interval: 0; running: true; onTriggered: {
    thumbs.make("/media/A.mp4", "/cache/A.png");
    probe.path = "/media/A.mp4";
    change.start();
  } }
  Timer { id: change; interval: 40; onTriggered: {
    thumbs.make("/media/B.mp4", "/cache/B.png");
    probe.path = "/media/B.mp4";
  } }
  Timer { interval: 500; running: true; onTriggered: {
    console.warn("CAPTURE_MEDIA_LATEST:" + JSON.stringify({thumbTarget: thumbs.target,
      thumbNext: thumbs.next, thumbReady: thumbs.ready, thumbRunning: thumbs.running,
      probePath: probe.path, probeRequest: probe.requestPath, seconds: probe.seconds,
      probeRunning: probe.running}));
    Qt.quit();
  } }
}
''')
            output = run_quickshell(root)
            rows = [line.split("CAPTURE_MEDIA_LATEST:", 1)[1]
                    for line in output.splitlines() if "CAPTURE_MEDIA_LATEST:" in line]
            self.assertEqual(len(rows), 1, output)
            self.assertEqual(json.loads(rows[0]), {
                "thumbTarget": "/cache/B.png", "thumbNext": "/cache/B.png",
                "thumbReady": True, "thumbRunning": False,
                "probePath": "/media/B.mp4", "probeRequest": "/media/B.mp4",
                "seconds": 20, "probeRunning": False,
            })
            self.assertEqual(thumb_log.read_text().splitlines(), ["/media/A.mp4", "/media/B.mp4"])


if __name__ == "__main__":
    unittest.main()
