pragma Singleton
import QtQuick
import Quickshell

// Where the shell's files are. A service names its script as
// `Paths.scriptsDir + "/<name>"` (`install.py check shell` follows that form).
Singleton {
  readonly property string scriptsDir: Quickshell.shellDir + "/scripts"

  // the last segment of a path: "/home/me/Music/" is "Music"
  function nameOf(path) { return path.split("/").filter(s => s !== "").pop() ?? path; }
}
