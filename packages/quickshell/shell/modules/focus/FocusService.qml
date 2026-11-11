pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Focus: mako's do-not-disturb mode. The bar module and the hub's tile read `on`
// and call `toggle()`; the island's toasts keep quiet while it is on (critical
// ones still come).
Singleton {
  id: root

  property bool on: false
  property bool busy: false
  property bool toggleBefore: false
  property bool confirming: false
  property bool readQueued: false
  property string error: ""

  function toggle() {
    if (busy || set.running) return;
    toggleBefore = on;
    busy = true;
    error = "";
    on = !on;
    set.exitCode = -1;
    set.command = ["makoctl", "mode", toggleBefore ? "-r" : "-a", "do-not-disturb"];
    set.running = true;
  }

  function refresh() {
    if (read.running) { readQueued = true; return; }
    read.forConfirm = confirming;
    read.running = true;
  }

  function finishSet(success, startFailure) {
    if (!success) {
      on = toggleBefore;
      confirming = false;
      error = startFailure ? "could not start focus mode change" : "could not change focus mode";
      busy = false;
      return;
    }
    confirming = true;
    refresh();
  }

  function finishRead(text, success, forConfirm) {
    const lines = typeof text === "string" ? text.split("\n").map(s => s.trim()).filter(s => s !== "") : [];
    // `makoctl mode` exits successfully with an empty list when no modes are
    // active. Only a failed process means that the current state is unknown.
    const valid = success;
    if (forConfirm && confirming) {
      if (valid) { on = lines.includes("do-not-disturb"); error = ""; }
      else { on = toggleBefore; error = "could not confirm focus mode"; }
      confirming = false;
    } else if (!confirming) {
      if (valid) on = lines.includes("do-not-disturb");
      else error = "could not read focus mode";
    }
    if (readQueued) { readQueued = false; refresh(); }
    if (forConfirm) busy = false;
  }

  Process {
    id: read
    command: ["makoctl", "mode"]
    property bool started: false
    property bool forConfirm: false
    property int exitCode: -1
    property string reply: ""
    onStarted: { started = true; exitCode = -1; reply = ""; }
    onExited: code => exitCode = code
    onRunningChanged: {
      if (running) return;
      const wasStarted = started;
      started = false;
      root.finishRead(reply, wasStarted && exitCode === 0, forConfirm);
    }
    stdout: StdioCollector { onStreamFinished: read.reply = text }
  }

  Process {
    id: set
    property bool started: false
    property int exitCode: -1
    onStarted: { started = true; exitCode = -1; }
    onExited: code => exitCode = code
    onRunningChanged: {
      if (running) return;
      const wasStarted = started;
      started = false;
      root.finishSet(wasStarted && exitCode === 0, !wasStarted);
    }
  }

  // another tool may flip the mode: look again now and then
  Component.onCompleted: refresh()
  Timer { interval: 15000; running: true; repeat: true; onTriggered: root.refresh() }
}
