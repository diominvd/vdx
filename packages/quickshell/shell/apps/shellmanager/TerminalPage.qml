import QtQuick
import Quickshell.Io
import qs.config
import qs.kit
import "../../kit/reply.js" as Reply

// Page-local processes: one read on opening, one write per selection.
Column {
  id: root
  readonly property string icon: "terminal"
  readonly property string title: "Terminal"
  readonly property string description: "What opens in new kitty windows."
  readonly property var jumps: []
  readonly property string script: Paths.scriptsDir + "/terminal.py"
  property var info: ({})
  property string error: ""
  readonly property bool busy: proc.running
  readonly property bool changed: info.selected !== undefined && info.selected !== info.default
  function reset() { run(["reset"]); }
  function run(args) {
    if (busy) return;
    error = "";
    proc.command = ["python3", script].concat(args);
    proc.running = true;
  }
  Component.onCompleted: run(["status"])
  spacing: Theme.sectionGap

  KitLabel { text: "OPENING" }
  KitRow {
    label: "Multiplexer"
    hint: "Applies to new terminal windows"
    wide: true
    KitSegments {
      model: [{ label: "Shell", value: "none" }, { label: "tmux", value: "tmux" }, { label: "Zellij", value: "zellij" }]
      current: root.info.selected ?? "none"
      disabled: root.busy || root.info.selected === undefined
      onPicked: value => root.run(["set", value])
    }
  }
  KitText {
    width: parent.width
    visible: root.error !== ""
    text: root.error
    color: Theme.red
    wrapMode: Text.Wrap
    font.pixelSize: Theme.fontSize - 1
  }
  KitGrouper {}

  Process {
    id: proc
    property string output: ""
    onStarted: output = ""
    stdout: StdioCollector { onStreamFinished: proc.output = text }
    onExited: {
      const reply = Reply.parse(output, "terminal.py");
      if (reply.ok) { root.info = reply; root.error = ""; }
      else root.error = reply.error ?? "Could not change the terminal";
    }
  }
}
