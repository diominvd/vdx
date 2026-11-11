"""Live face measurements must survive the compact bar being hidden by a popup."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from tests.qml_runtime import SHELL


class BarGeometry(unittest.TestCase):
    def test_live_face_keeps_width_and_padding_across_popup_cycles(self):
        runner = shutil.which("qmltestrunner") or "/usr/lib/qt6/bin/qmltestrunner"
        if not Path(runner).is_file():
            self.skipTest("Qt QML test runner unavailable")
        with tempfile.TemporaryDirectory(prefix="bar-geometry-") as directory:
            work = Path(directory)
            config = work / "qs/config"
            config.mkdir(parents=True)
            (config / "qmldir").write_text("module qs.config\nsingleton Theme 1.0 Theme.qml\n")
            (config / "Theme.qml").write_text(
                "pragma Singleton\nimport QtQuick\nQtObject { readonly property int fontSize: 14 }\n")
            source = (SHELL / "bar/island/IslandLiveFace.qml").read_text()
            for name in ("IslandLiveTask", "IslandLiveNoticeFace", "IslandLiveMedia", "IslandLiveStatus"):
                source = source.replace(name + " {", "FixtureFace {")
            (work / "IslandLiveFace.qml").write_text(source)
            (work / "FixtureFace.qml").write_text('''import QtQuick
Row {
 property string kind: ""
 property var notice: null
 property bool inputEnabled: true
 property int coverSize: 18
 property int badgeRadius: 0
 property bool showCover: true
 height: coverSize
 spacing: 8
 Rectangle { readonly property string liveEnd: "badge"; width: 18; height: 18 }
 Text { text: "A live activity"; font.pixelSize: 14 }
}
''')
            (work / "tst_geometry.qml").write_text('''import QtQuick
import QtTest
Item {
 width: 400; height: 100
 Item {
  id: host; width: 300; height: 50
  IslandLiveFace { id: face; kind: "music"; coverSize: 18; chipHeight: 24; inset: 3 }
 }
 TestCase {
  name: "LiveFaceGeometry"
  when: windowShown
  function test_popup_cycles_preserve_measurements() {
   wait(30);
   const width = face.implicitWidth, lead = face.leadPad, trail = face.trailPad;
   verify(width > 18); compare(lead, 3); verify(trail > 0);
   for (let i = 0; i < 5; ++i) {
    host.visible = false; wait(20);
    compare(face.implicitWidth, width); compare(face.leadPad, lead); compare(face.trailPad, trail);
    host.visible = true; wait(20);
    compare(face.implicitWidth, width); compare(face.leadPad, lead); compare(face.trailPad, trail);
   }
  }
 }
}
''')
            env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software")
            result = subprocess.run([runner, "-input", str(work), "-import", str(work)],
                                    env=env, capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
