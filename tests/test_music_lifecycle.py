"""The Music window creates its view on demand and keeps only navigation closed."""
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.check_shell_ui import qml_block
from tests.qml_runtime import SHELL, run_quickshell


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class MusicLifecycle(unittest.TestCase):
    def test_lazy_creation_teardown_navigation_and_deferred_go(self):
        source = (SHELL / "apps/music/MusicWindow.qml").read_text()
        controller = qml_block(source, "QtObject {\n    id: app")
        loader = qml_block(source, "Loader {\n    id: content")
        loader = loader.replace("Music {", '''Item {
        property string tab: "yandex"
        property string page: "likes"
        property string playlistKind: ""
        property string folder: ""
        property string radioPage: "all"
        signal closeRequested()
        function shown() { root.shows++; }
        function hidden() { root.hides++; }
        function go(page) { tab = page; }
        function cancel() { root.cancels++; }
        Component.onCompleted: root.created++
        Component.onDestruction: root.destroyed++''', 1)
        with tempfile.TemporaryDirectory(prefix="shell-music-life-") as tmp:
            root = Path(tmp)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
Scope {
  id: root
  property bool visible: false
  property int created: 0
  property int destroyed: 0
  property int shows: 0
  property int hides: 0
  property int cancels: 0
''' + controller + '\n' + loader + '''
  Timer { interval: 0; running: true; onTriggered: {
    const initial = {created, loaded: content.item !== null};
    app.shown();
    app.go("files");
    content.item.folder = "/music/album";
    content.item.page = "playlist";
    content.item.playlistKind = "liked";
    app.cancel();
    app.hidden();
    const closed = {created, loaded: content.item !== null, navigation: app.navigation};
    app.shown();
    const restored = {tab: content.item.tab, folder: content.item.folder,
      page: content.item.page, playlistKind: content.item.playlistKind};
    app.hidden();
    app.go("radio");
    app.shown();
    const deferred = content.item.tab;
    app.hidden();
    console.warn("MUSIC_LIFETIME:" + JSON.stringify({initial, closed, restored, deferred,
      created, destroyed, shows, hides, cancels, loaded: content.item !== null}));
    Qt.quit();
  } }
}
''')
            output = run_quickshell(root)
            rows = [line.split("MUSIC_LIFETIME:", 1)[1] for line in output.splitlines() if "MUSIC_LIFETIME:" in line]
            self.assertEqual(len(rows), 1, output)
            self.assertEqual(json.loads(rows[0]), {
                "initial": {"created": 0, "loaded": False},
                "closed": {"created": 1, "loaded": False, "navigation": {
                    "tab": "files", "page": "playlist", "playlistKind": "liked",
                    "folder": "/music/album", "radioPage": "all"}},
                "restored": {"tab": "files", "folder": "/music/album", "page": "playlist", "playlistKind": "liked"},
                "deferred": "radio", "created": 3, "destroyed": 3, "shows": 3, "hides": 3, "cancels": 1, "loaded": False,
            })


if __name__ == "__main__":
    unittest.main()
