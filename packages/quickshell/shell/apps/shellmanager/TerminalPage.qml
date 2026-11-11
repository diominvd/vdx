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
  readonly property string description: "Opening and spacing in new kitty windows."
  readonly property var jumps: []
  readonly property string script: Paths.scriptsDir + "/terminal.py"
  property var info: ({})
  property string error: ""
  property bool settingsLoaded: false
  readonly property bool busy: proc.running
  readonly property bool changed: settingsLoaded && (info.selected !== info.default || info.padding.horizontal !== 6 || info.padding.vertical !== 6 || info.zenChanged === true)
  readonly property var paddingSnaps: Array.from({ length: 41 }, (_, i) => i / 40)
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
  // Keep the selector in the layout while the row and its gap collapse together.
  Column {
    id: openingRows
    width: parent.width
    readonly property bool zenShown: root.info.selected === "zellij" || root.info.selected === "tmux"
    property real reveal: zenShown ? 1 : 0
    spacing: root.spacing * reveal
    Behavior on reveal {
      enabled: Motion.controls && root.settingsLoaded
      NumberAnimation { duration: Motion.normal; easing.type: Motion.easing }
    }
    KitRow {
      label: "Multiplexer"
      hint: "Applies to new terminal windows"
      wide: true
      KitSegments {
        id: multiplexer
        model: [{ label: "Shell", value: "none" }, { label: "tmux", value: "tmux" }, { label: "Zellij", value: "zellij" }]
        current: root.info.selected ?? "none"
        disabled: root.busy || root.info.selected === undefined
        onPicked: value => root.run(["set", value])
      }
    }
    Item {
      width: parent.width
      height: zenRow.implicitHeight * openingRows.reveal
      clip: true
      opacity: openingRows.reveal
      enabled: openingRows.zenShown
      KitRow {
        id: zenRow
        height: implicitHeight
        label: "Zen mode"
        hint: "Open and new sessions · Alt + Z toggles"
        needs: root.info.zenAvailable ? "" : "Multiplexer is not installed or configured"
        KitSwitch {
          checked: root.info.zen === true
          enabled: !root.busy
          onToggled: {
            // A mouse click must not restore the selector's focus after the write.
            if (!activeFocus) root.forceActiveFocus(Qt.MouseFocusReason);
            root.run(["zen", checked ? "off" : "on"]);
          }
        }
      }
    }
  }
  KitLine {}
  KitLabel { text: "PADDING"; about: "Applies to new terminal windows, in points" }
  KitSliderRow {
    label: "Horizontal padding"
    value: (root.info.padding?.horizontal ?? 6) / 40
    text: Math.round((pressed ? dragValue * 40 : root.info.padding?.horizontal ?? 6)) + " pt"
    snaps: root.paddingSnaps
    enabled: !root.busy && root.info.padding !== undefined
    onReleased: value => root.run(["padding", "horizontal", String(Math.round(value * 40))])
  }
  KitSliderRow {
    label: "Vertical padding"
    value: (root.info.padding?.vertical ?? 6) / 40
    text: Math.round((pressed ? dragValue * 40 : root.info.padding?.vertical ?? 6)) + " pt"
    snaps: root.paddingSnaps
    enabled: !root.busy && root.info.padding !== undefined
    onReleased: value => root.run(["padding", "vertical", String(Math.round(value * 40))])
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
      const valid = ["none", "tmux", "zellij"].includes(reply.selected)
        && ["none", "tmux", "zellij"].includes(reply.default)
        && Number.isInteger(reply.padding?.horizontal) && reply.padding.horizontal >= 0 && reply.padding.horizontal <= 40
        && Number.isInteger(reply.padding?.vertical) && reply.padding.vertical >= 0 && reply.padding.vertical <= 40;
      if (valid) {
        root.info = reply;
        if (!root.settingsLoaded) Qt.callLater(() => root.settingsLoaded = true);
      }
      if (reply.ok && valid) root.error = "";
      else if (reply.ok) root.error = "Invalid terminal settings reply";
      else root.error = reply.error ?? "Could not change the terminal";
    }
  }
}
