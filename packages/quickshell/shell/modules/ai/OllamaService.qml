pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../../kit/reply.js" as Reply

// Local Ollama on top of scripts/ollama.sh: server state, downloaded and
// loaded models, start / stop / pull / unload. Polled only while the AI
// popup shows its Ollama tab.
Singleton {
  id: root

  // ---- tuning ----
  readonly property int pollMs: 5000                   // status poll while the tab is open
  readonly property string coachModel: "qwen2.5:1.5b"  // the nvim habit coach's model
  readonly property string script: Paths.scriptsDir + "/ollama.sh"

  property var status: ({})                    // see `ollama.sh --status`
  property bool watching: false                // the Ollama tab is visible
  property var busy: null                      // "server" or a model name being worked on
  property string error: ""

  readonly property bool installed: status.installed ?? true
  readonly property bool running: status.running ?? false
  readonly property var models: status.models ?? []
  readonly property var loaded: status.loaded ?? []

  function finite(value) { return typeof value === "number" && isFinite(value); }
  function record(value) { return value !== null && typeof value === "object" && !Array.isArray(value); }

  function validStatus(o) {
    if (!record(o) || typeof o.installed !== "boolean" || typeof o.running !== "boolean") return false;
    if (o.version !== undefined && typeof o.version !== "string") return false;
    if (o.running && typeof o.version !== "string") return false;
    if (o.running && (!Array.isArray(o.models) || !Array.isArray(o.loaded))) return false;
    if (o.models !== undefined) {
      if (!Array.isArray(o.models)) return false;
      for (const m of o.models) {
        if (!record(m) || typeof m.name !== "string"
            || (m.size !== undefined && (!finite(m.size) || m.size < 0))) return false;
      }
    }
    if (o.loaded !== undefined) {
      if (!Array.isArray(o.loaded)) return false;
      for (const m of o.loaded) {
        if (!record(m) || typeof m.name !== "string"
            || (m.vram !== undefined && (!finite(m.vram) || m.vram < 0))) return false;
      }
    }
    return true;
  }

  function acceptStatus(o) {
    if (!validStatus(o)) return false;
    status = o;
    return true;
  }

  function vramOf(name) { return loaded.find(m => m.name === name)?.vram ?? 0; }
  function hasModel(name) { return models.some(m => m.name === name); }

  function refresh() { run(statusProc, ["--status"]); }

  function setRunning(on) { act("server", [on ? "--start" : "--stop"]); }
  function pull(name) { act(name, ["--pull", name]); }
  function unload(name) { act(name, ["--unload", name]); }

  function act(what, args) {
    if (busy !== null || actionProc.running) return;
    busy = what;
    error = "";
    actionProc.replyReady = false;
    run(actionProc, args);
  }

  function run(proc, args) {
    if (proc.running) return;
    proc.command = ["bash", root.script].concat(args);
    proc.running = true;
  }

  onWatchingChanged: if (watching) refresh()

  Timer {
    interval: root.pollMs
    running: root.watching
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      onStreamFinished: {
        const o = Reply.parse(text, "ollama.sh", null);
        if (o) root.acceptStatus(o);
      }
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector {
      onStreamFinished: {
        actionProc.pendingReply = Reply.parse(text, "ollama.sh");
        actionProc.replyReady = true;
        root.consumeActionReply();
      }
    }
    property bool started: false
    property bool processStopped: true
    property bool replyReady: false
    property var pendingReply: null
    onStarted: { started = true; processStopped = false; }
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; processStopped = true; root.consumeActionReply(); return; }
      root.error = "could not start Ollama action";
      root.refresh();
      root.busy = null;
    }
  }

  function consumeActionReply() {
    if (!actionProc.processStopped || !actionProc.replyReady) return;
    const o = actionProc.pendingReply;
    actionProc.replyReady = false;
    if (o?.ok !== true) error = typeof o?.error === "string" && o.error ? o.error : "action failed";
    else error = "";
    refresh();
    busy = null;
  }
}
