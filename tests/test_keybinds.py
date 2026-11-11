"""Keybinding descriptions and keys must not collide with object prototypes."""
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.check_shell_ui import qml_function
from tests.qml_runtime import SHELL, run_quickshell


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class Keybinds(unittest.TestCase):
    def test_prototype_names_remain_regular_groups_and_keys(self):
        source = (SHELL / "apps/keybinds/KeybindsService.qml").read_text()
        functions = "\n".join(qml_function(source, name) for name in ("keysOf", "build", "fold"))
        with tempfile.TemporaryDirectory(prefix="shell-keys-") as tmp:
            root = Path(tmp)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
Scope {
  property var places: ({})
  property var modeGroups: []
  property var mods: []
  property var keyNames: ({})
  function modeHints() { return []; }
''' + functions + '''
  Timer { interval: 0; running: true; onTriggered: {
    const names = ["__proto__", "constructor", "toString"];
    const rows = names.map(name => ({has_description: true,
      description: name + " · Action", key: name, modmask: 0}));
    try { console.warn("KEYS_RESULT:" + JSON.stringify(build(rows))); }
    catch (error) { console.warn("KEYS_ERROR:" + error); }
    Qt.quit();
  } }
}
''')
            output = run_quickshell(root)
            result = [line.split("KEYS_RESULT:", 1)[1] for line in output.splitlines() if "KEYS_RESULT:" in line]
            self.assertEqual(len(result), 1, output)
            self.assertEqual(json.loads(result[0]), [
                {"tab": "desktop", "section": name, "what": "Action", "keys": [name]}
                for name in ("__proto__", "constructor", "toString")
            ])


if __name__ == "__main__":
    unittest.main()
