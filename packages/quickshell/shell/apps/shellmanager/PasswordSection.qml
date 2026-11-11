import QtQuick
import Quickshell.Io
import qs.config
import qs.kit
import "../../kit/reply.js" as Reply

// Profile › Password: the system password of your own account, changed through
// scripts/password.py (the system's `passwd`: PAM checks the old one and the new
// one's strength). The passwords go to the script by stdin and are cleared at once.
Column {
  id: root

  property bool busy: false
  property string message: ""
  property bool failed: false
  readonly property bool ready: current.text !== "" && fresh.text !== "" && fresh.text === again.text

  function submit() {
    if (!ready || busy) return;
    busy = true;
    message = "";
    proc.running = true;
  }

  width: parent.width

  KitLabel { text: "PASSWORD" }
  KitRow {
    wide: true
    label: "Current password"
    KitInput { id: current; echoMode: TextInput.Password; placeholder: "Current"; centerMasked: false; onAccepted: fresh.input.forceActiveFocus() }
  }
  KitRow {
    wide: true
    label: "New password"
    KitInput { id: fresh; echoMode: TextInput.Password; placeholder: "New"; centerMasked: false; onAccepted: again.input.forceActiveFocus() }
  }
  KitRow {
    wide: true
    label: "Repeat it"
    hint: again.text !== "" && again.text !== fresh.text ? "The two do not match" : ""
    hintLevel: "danger"
    KitInput { id: again; echoMode: TextInput.Password; placeholder: "Repeat"; centerMasked: false; onAccepted: root.submit() }
  }
  KitRow {
    label: "Change the password"
    hint: message
    hintLevel: failed ? "danger" : "info"
    KitButton { text: "Change"; busy: root.busy; disabled: !root.ready; onClicked: root.submit() }
  }
  KitGrouper {}

  Process {
    id: proc
    command: ["python3", Paths.scriptsDir + "/password.py", "change"]
    stdinEnabled: true
    stdout: StdioCollector {
      onStreamFinished: {
        const reply = Reply.parse(text, "password.py");
        root.busy = false;
        root.failed = !reply.ok;
        root.message = reply.ok ? "Password changed" : reply.error;
        if (reply.ok) { current.text = ""; fresh.text = ""; again.text = ""; }
      }
    }
    onStarted: {
      write(JSON.stringify({ current: current.text, new: fresh.text }) + "\n");
      flush();
    }
  }
}
