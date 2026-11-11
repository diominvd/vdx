"""Feed a partial pacman download through the production QML progress process."""
from pathlib import Path
import json
import shutil
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class PackageProgress(unittest.TestCase):
    def test_partial_download_updates_fraction_and_late_reply_does_not_reset_install(self):
        source = (SHELL / "apps/packages/PackagesService.qml").read_text()
        process = qml_block(source, "Process {\n    id: progressProc")
        accept_progress = "\n".join(qml_function(source, name) for name in
                                        ("finiteNonnegative", "acceptProgress"))
        with tempfile.TemporaryDirectory(prefix="package-progress-") as tmp:
            root = Path(tmp)
            cache = root / "pkg"
            cache.mkdir()
            (cache / "foo-1.0-1-x86_64.pkg.tar.zst.part").write_bytes(b"x" * 40)
            backend = root / "progress.py"
            backend.write_text('import sys\nfrom pathlib import Path\nsys.path.insert(0, ' +
                repr(str(SHELL / "scripts")) + ')\nimport packages\npackages.CACHE = Path(' +
                repr(str(cache)) + ')\npackages.WATCH = Path(' + repr(str(root / "watch")) +
                ')\npackages.out(packages.progress(sys.argv[2:]))\n')
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property string script: ''' + json.dumps(str(backend)) + '''
  property string stage: "downloading"
  property var stageList: [{name: "foo", to: "1.0-1"}]
  property real stageDone: 0
  property real stageBytes: 100
  readonly property real stagePercent: stageBytes > 0 ? Math.min(1, stageDone / stageBytes) : 0
  property int replies: 0
  function parse(text) { replies++; return JSON.parse(text); }
''' + accept_progress + '''
  ''' + process + '''
  Component.onCompleted: progressProc.running = true
  Timer { interval: 10; repeat: true; running: true; onTriggered: {
    if (root.replies === 1 && !progressProc.running && root.stage === "downloading") {
      console.warn("DOWNLOAD_FRACTION:" + root.stagePercent);
      root.stage = "installing";
      root.stageDone = 100;
      progressProc.running = true;
    } else if (root.replies === 2 && !progressProc.running) {
      console.warn("INSTALL_FRACTION:" + root.stagePercent);
      Qt.quit();
    }
  } }
}
''')
            output = run_quickshell(root)
            self.assertIn("DOWNLOAD_FRACTION:0.4", output)
            self.assertIn("INSTALL_FRACTION:1", output)
