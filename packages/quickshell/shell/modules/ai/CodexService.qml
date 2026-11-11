pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../../kit/reply.js" as Reply

// Codex CLI plan limits on top of scripts/codex.sh: the numbers of its last
// answer, read from its session logs (no network). The bar module and the
// popup only read these properties and call refresh().
Singleton {
  id: root

  // ---- tuning ----
  readonly property int pollMs: 60000        // the logs are local: cheap to read
  readonly property string script: Paths.scriptsDir + "/codex.sh"

  property var usage: ({})                   // last good `codex.sh --usage`
  property string error: ""
  property int barUsers: 0

  readonly property string plan: usage.plan ?? ""
  readonly property var limits: usage.limits ?? []
  // when Codex last saw these numbers (ms), 0 before any
  readonly property real fetchedAt: usage.at ? new Date(usage.at).getTime() : 0
  readonly property bool refreshing: proc.running

  function finite(value) { return typeof value === "number" && isFinite(value); }
  function record(value) { return value !== null && typeof value === "object" && !Array.isArray(value); }

  function validUsage(o) {
    if (!record(o) || o.ok !== true || typeof o.plan !== "string" || typeof o.at !== "string"
        || !finite(Date.parse(o.at)) || !Array.isArray(o.limits)) return false;
    return o.limits.every(limit => record(limit) && typeof limit.kind === "string"
      && finite(limit.percent) && limit.percent >= 0 && limit.percent <= 100
      && typeof limit.resets_at === "string");
  }

  function refresh() {
    if (proc.running) return;
    proc.command = ["bash", root.script, "--usage"];
    proc.running = true;
  }
  function attachBar() { barUsers++; if (barUsers === 1) refresh(); }
  function detachBar() { barUsers = Math.max(0, barUsers - 1); }

  Timer {
    interval: root.pollMs
    running: root.barUsers > 0
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: proc
    stdout: StdioCollector {
      onStreamFinished: {
        const o = Reply.parse(text, "codex.sh", { ok: false, error: "no answer" });
        if (root.validUsage(o)) { root.usage = o; root.error = ""; }
        else root.error = typeof o?.error === "string" && o.error ? o.error : "bad Codex usage reply";
      }
    }
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.error = "could not start Codex usage query";
    }
  }
}
