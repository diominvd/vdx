"""Settings forms stay centred and readable across window sizes."""
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.qml_runtime import SHELL, run_quickshell
from tests.check_shell_ui import qml_block


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class SettingsWorkspace(unittest.TestCase):
    def fixture(self, root):
        (root / "config").mkdir()
        (root / "kit").mkdir()
        # Use the production width token, with no settings files or services.
        theme = (SHELL / "config/Theme.qml").read_text()
        width = next(line for line in theme.splitlines() if "property int settingsMaxWidth:" in line)
        (root / "config/Theme.qml").write_text(
            'pragma Singleton\nimport QtQuick\nQtObject {\n' + width +
            '\nreadonly property int windowPadding: 24\n}\n')
        (root / "config/Motion.qml").write_text(
            'pragma Singleton\nimport QtQuick\nQtObject { property bool tabs: false; '
            'property int easing: 0; function ms(value) { return value; } }\n')
        shutil.copy(SHELL / "kit/KitSettingsWorkspace.qml", root / "kit")
        (root / "kit/KitScrollBar.qml").write_text(
            'import QtQuick.Controls\nScrollBar {}\n')

    def test_form_resizes_and_preserves_scroll_extent(self):
        with tempfile.TemporaryDirectory(prefix="settings-workspace-") as tmp:
            root = Path(tmp)
            self.fixture(root)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import qs.kit
Scope {
  id: root
  property int phase: 0
  function check(ok, message) { if (!ok) throw new Error(message); }
  KitSettingsWorkspace {
    id: workspace
    width: 1100; height: 180
    settings: Component {
      Item { implicitHeight: 600 }
    }
  }
  Timer { interval: 50; running: true; repeat: true; onTriggered: {
    const loader = workspace.viewport.contentItem.children.find(c => c.item !== undefined);
    root.check(loader !== undefined && loader.item !== null, "settings were not loaded");
    if (root.phase === 0) {
      root.check(loader.width === 720 && loader.x === 190, "wide form is not centred");
      root.check(loader.item.width === 720, "loaded settings did not get the bounded width");
      root.check(workspace.viewport.contentHeight === 600 && workspace.viewport.interactive, "scroll extent was lost");
      workspace.width = 480;
    } else if (root.phase === 1) {
      root.check(loader.width === 480 && loader.x === 0 && loader.item.width === 480, "narrow form is clipped");
      workspace.viewport.contentY = 200;
      workspace.current = "other";
    } else {
      root.check(workspace.viewport.contentY === 0, "section change did not reset scroll");
      console.warn("WORKSPACE_OK"); Qt.quit();
    }
    root.phase++;
  } }
}
''')
            self.assertIn("WORKSPACE_OK", run_quickshell(root))

    def test_manager_bounds_settings_and_keeps_theme_gallery_wide(self):
        source = (SHELL / "apps/shellmanager/ShellManager.qml").read_text()
        host = qml_block(source, "Item {\n      id: pages")
        # Exercise the real host geometry without constructing system services.
        host = host.split("      Loader {", 1)[0] + "}\n"
        with tempfile.TemporaryDirectory(prefix="settings-host-") as tmp:
            root = Path(tmp)
            self.fixture(root)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import qs.config
Scope {
  id: root
  property string tab: "appearance"
  property int contentGap: 12
  property int phase: 0
  function check(ok, message) { if (!ok) throw new Error(message); }
  QtObject { id: pageIn; property real shown: 1 }
  QtObject { id: pageContent; property QtObject item: QtObject { property real implicitHeight: 900 } }
  Item { id: page; width: 1100; height: 700
    ''' + host + '''
  }
  Timer { interval: 50; running: true; repeat: true; onTriggered: {
    if (root.phase === 0) {
      root.check(pages.width === 720 && pages.x === 190, "settings host is not centred");
      root.check(pages.height === 900, "page scroll height was lost");
      root.tab = "modules";
    } else if (root.phase === 1) {
      root.check(pages.width === 720, "module settings are not bounded");
      root.tab = "themes";
    } else if (root.phase === 2) {
      root.check(pages.width === 1052 && pages.x === 24, "theme gallery was squeezed");
      page.width = 480; root.tab = "network";
    } else {
      root.check(pages.width === 432 && pages.x === 24, "narrow page lost its margins");
      console.warn("SETTINGS_HOST_OK"); Qt.quit();
    }
    root.phase++;
  } }
}
''')
            self.assertIn("SETTINGS_HOST_OK", run_quickshell(root))
