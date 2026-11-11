"""Exercise Shell Manager theme and wallpaper process recovery in isolation."""
from __future__ import annotations

import json
from pathlib import Path
import shlex
import shutil
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


MANAGER = SHELL / "apps/shellmanager"


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class AppearanceProcessStart(unittest.TestCase):
    def run_fixture(self, root, source):
        (root / "shell.qml").write_text(source)
        return run_quickshell(root, timeout=12)

    def result(self, output, marker):
        results = [line.split(marker, 1)[1] for line in output.splitlines() if marker in line]
        self.assertEqual(len(results), 1, output)
        return json.loads(results[0])

    def test_theme_list_start_retry_and_malformed_snapshot(self):
        source = (MANAGER / "ThemeService.qml").read_text()
        accept = qml_function(source, "acceptList").replace("Theme.live =", "root.live =")
        refresh = qml_function(source, "refresh")
        process = qml_block(source, "Process {\n    id: listProc").replace(
            'command: ["bash", Paths.scriptsDir + "/themes.sh"]',
            "command: root.listCommand")
        roles = [
            "background0", "background1", "background2", "background3", "foreground0",
            "foreground1", "foreground2", "red", "orange", "yellow", "green", "aqua",
            "blue", "purple", "gray", "muted", "frame", "dim",
        ]
        values = " ".join(["#123456"] * len(roles))
        valid_output = f"__proto__ {values}\nzeta {values}\ndefault {values}\ngruvbox {values}\n---\ngruvbox\n"
        malformed_output = "zeta #123456\n---\nzeta\n"
        with tempfile.TemporaryDirectory(prefix="shell-theme-list-") as tmp:
            root = Path(tmp)
            good = root / "good.sh"
            bad = root / "bad.sh"
            good.write_text("printf '%s' " + shlex.quote(valid_output) + "\n")
            bad.write_text("printf '%s' " + shlex.quote(malformed_output) + "\n")
            good.chmod(0o700)
            bad.chmod(0o700)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property var roles: ''' + json.dumps(roles) + '''
  property var themes: ["kept"]
  property var colors: ({kept: {background0: "#abcdef"}})
  property string current: "kept"
  property var live: ({background0: "#abcdef"})
  property string listError: ""
  property string applyError: ""
  readonly property string error: applyError || listError
  property bool busy: false
  property var listCommand: ["/no/such/theme-list"]
  property int phase: 0
  property int ticks: 0
''' + accept + '\n' + refresh + '\n' + process + '''
  Timer { id: uncover; interval: 1; onTriggered: {} }
  Timer { interval: 20; repeat: true; running: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) { root.refresh(); root.phase = 1; }
    else if (root.phase === 1 && root.error === "could not start theme list query") {
      root.listCommand = ["bash", ''' + json.dumps(str(good)) + '''];
      root.refresh(); root.phase = 2;
    } else if (root.phase === 2 && root.current === "gruvbox") {
      root.listCommand = ["bash", ''' + json.dumps(str(bad)) + '''];
      root.refresh(); root.phase = 3;
    } else if (root.phase === 3 && root.error === "bad theme list reply") {
      console.warn("THEME_LIST_RECOVERY:" + JSON.stringify({
        themes: root.themes, colors: root.colors, current: root.current,
        live: root.live, error: root.error
      }));
      Qt.quit();
    }
    if (root.ticks > 300) { console.warn("THEME_LIST_TIMEOUT:" + root.error); Qt.quit(); }
  } }
}
''')
            result = self.result(output, "THEME_LIST_RECOVERY:")
            self.assertEqual(result["themes"], ["default", "__proto__", "zeta", "gruvbox"])
            self.assertEqual(result["current"], "gruvbox")
            self.assertEqual(result["live"], {role: "#123456" for role in roles})
            self.assertEqual(result["colors"], {
                name: {role: "#123456" for role in roles}
                for name in ("__proto__", "zeta", "default", "gruvbox")
            })
            self.assertEqual(result["error"], "bad theme list reply")

    def test_theme_apply_start_failure_releases_cover_and_retry_completes(self):
        source = (MANAGER / "ThemeService.qml").read_text()
        refresh = qml_function(source, "refresh")
        apply = qml_function(source, "apply").replace(
            'setProc.command = ["python3", dotfiles + "/install.py", "theme", "set", name];',
            "setProc.command = root.setCommand;").replace("Theme.background0", "root.background0")
        list_proc = qml_block(source, "Process {\n    id: listProc").replace(
            'command: ["bash", Paths.scriptsDir + "/themes.sh"]',
            "command: root.listCommand")
        set_proc = qml_block(source, "Process {\n    id: setProc")
        accept = qml_function(source, "acceptList").replace("Theme.live =", "root.live =")
        # Keep only one copy of acceptList while retaining both production process blocks.
        functions = "\n".join(qml_function(source, name) for name in ("failApply", "finishApply")) + "\n" + accept
        with tempfile.TemporaryDirectory(prefix="shell-theme-apply-") as tmp:
            root = Path(tmp)
            good_list = root / "themes.sh"
            good_list.write_text("printf '%s\\n' 'gruvbox " + " ".join(["#123456"] * 18)
                                 + "' '---' 'gruvbox'\n")
            good_list.chmod(0o700)
            set_script = root / "set.sh"
            set_script.write_text("#!/bin/sh\nexit 0\n")
            set_script.chmod(0o700)
            failed_set = root / "failed-set.sh"
            failed_set.write_text("#!/bin/sh\necho 'mutation denied' >&2\nexit 7\n")
            failed_set.chmod(0o700)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property string dotfiles: "/unused"
  property var roles: ["background0", "background1", "background2", "background3", "foreground0", "foreground1", "foreground2", "red", "orange", "yellow", "green", "aqua", "blue", "purple", "gray", "muted", "frame", "dim"]
  property var themes: ["old"]
  property var colors: ({old: {background0: "#000000"}})
  property string current: "old"
  property bool busy: false
  property string applying: ""
  property string listError: ""
  property string applyError: ""
  readonly property string error: applyError || listError
  property bool covering: false
  property color coverColor: "#000000"
  property color background0: "#000000"
  property var live: ({})
  property var listCommand: ["bash", ''' + json.dumps(str(good_list)) + ''']
  property var setCommand: ["/no/such/theme-set"]
  property var failed: null
  property int phase: 0
  property int ticks: 0
  Timer { id: uncover; interval: 1; onTriggered: root.covering = false }
  Timer { id: coverSafety; interval: 15000; onTriggered: root.covering = false }
''' + refresh + '\n' + apply + '\n' + functions + '\n' + list_proc + '\n' + set_proc + '''
  Timer { interval: 20; repeat: true; running: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) { root.apply("new"); root.phase = 1; }
    else if (root.phase === 1 && root.error === "could not start theme change") {
      const failed = {busy: root.busy, applying: root.applying,
                      covering: root.covering, safety: coverSafety.running};
      root.setCommand = ["bash", ''' + json.dumps(str(set_script)) + '''];
      root.apply("new"); root.phase = 2;
      root.failed = failed;
    } else if (root.phase === 2 && !root.busy && root.current === "gruvbox") {
      root.setCommand = ["bash", ''' + json.dumps(str(failed_set)) + '''];
      root.apply("another"); root.phase = 3;
    } else if (root.phase === 3 && !root.busy && root.applyError === "mutation denied" && root.listError === "") {
      console.warn("THEME_APPLY_RECOVERY:" + JSON.stringify({
        failed: root.failed, busy: root.busy, applying: root.applying,
        error: root.error, applyError: root.applyError, current: root.current
      }));
      Qt.quit();
    }
    if (root.ticks > 300) { console.warn("THEME_APPLY_TIMEOUT:" + root.error); Qt.quit(); }
  } }
}
''')
            self.assertEqual(self.result(output, "THEME_APPLY_RECOVERY:"), {
                "failed": {"busy": False, "applying": "", "covering": False, "safety": False},
                "busy": False, "applying": "", "error": "mutation denied",
                "applyError": "mutation denied", "current": "gruvbox",
            })

    def test_wallpaper_start_failure_retry_and_reentrant_request_snapshot(self):
        source = (MANAGER / "WallpaperService.qml").read_text()
        add = qml_function(source, "add").replace('Quickshell.env("HOME")', "root.home").replace(
            'copyProc.command = ["bash", "-c", \'mkdir -p "$2" && cp -- "$1" "$2/"\', "_", src, userDir];',
            "copyProc.command = root.copyCommand;")
        fail_add = qml_function(source, "failAdd")
        process = qml_block(source, "Process {\n    id: copyProc")
        with tempfile.TemporaryDirectory(prefix="shell-wallpaper-add-") as tmp:
            root = Path(tmp)
            home = root / "home"
            home.mkdir()
            image_a = root / "first.png"
            image_b = root / "second.png"
            image_a.write_bytes(b"first")
            image_b.write_bytes(b"second")
            good_copy = root / "copy.sh"
            good_copy.write_text("#!/bin/sh\nexit 0\n")
            good_copy.chmod(0o700)
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
Scope {
  id: root
  property string home: ''' + json.dumps(str(home)) + '''
  property string userDir: ''' + json.dumps(str(root / "user-wallpapers")) + '''
  property bool busy: false
  property string error: ""
  property string adding: ""
  property string addingTheme: ""
  property string addingOutput: ""
  property var copyCommand: ["/no/such/wallpaper-copy"]
  property var choices: []
  property bool failedFieldsCleared: false
  property bool idleFieldsCleared: true
  property bool reentered: false
  property int phase: 0
  property int ticks: 0
  signal added()
  function choose(theme, rel, output) { choices = choices.concat([[theme, rel, output]]); }
  onBusyChanged: {
    if (!busy) idleFieldsCleared = adding === "" && addingTheme === "" && addingOutput === "";
    if (!busy && phase === 2 && choices.length === 1 && !reentered) {
      reentered = true;
      copyCommand = ["bash", ''' + json.dumps(str(good_copy)) + '''];
      add(''' + json.dumps(str(image_b)) + ''', "new-theme", "OUT-2");
    }
  }
''' + fail_add + '\n' + add + '\n' + process + '''
  Timer { interval: 20; repeat: true; running: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) { root.add(''' + json.dumps(str(image_a)) + ''', "old-theme", "OUT-1"); root.phase = 1; }
    else if (root.phase === 1 && root.error === "could not start wallpaper copy") {
      root.failedFieldsCleared = root.adding === "" && root.addingTheme === "" && root.addingOutput === "" && !root.busy;
      root.copyCommand = ["bash", ''' + json.dumps(str(good_copy)) + '''];
      root.add(''' + json.dumps(str(image_a)) + ''', "old-theme", "OUT-1");
      root.phase = 2;
    } else if (root.phase === 2 && root.reentered && root.choices.length === 2 && !root.busy) {
      console.warn("WALLPAPER_ADD_RECOVERY:" + JSON.stringify({
        failedFieldsCleared: root.failedFieldsCleared,
        idleFieldsCleared: root.idleFieldsCleared,
        choices: root.choices, error: root.error, busy: root.busy
      }));
      Qt.quit();
    }
    if (root.ticks > 300) { console.warn("WALLPAPER_ADD_TIMEOUT:" + root.error); Qt.quit(); }
  } }
}
''')
            self.assertEqual(self.result(output, "WALLPAPER_ADD_RECOVERY:"), {
                "failedFieldsCleared": True,
                "idleFieldsCleared": True,
                "choices": [["old-theme", "user/first.png", "OUT-1"],
                            ["new-theme", "user/second.png", "OUT-2"]],
                "error": "", "busy": False,
            })


if __name__ == "__main__":
    unittest.main()
