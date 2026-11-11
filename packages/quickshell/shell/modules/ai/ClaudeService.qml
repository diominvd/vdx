pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../../kit/reply.js" as Reply

// Claude Code usage on top of scripts/claude.sh: plan limits (the `/usage`
// numbers, polled from the API), today's tokens from the local session logs,
// and the running sessions. The bar module and the popup only read these
// properties and call these functions.
Singleton {
  id: root

  // ---- tuning ----
  readonly property int usagePollMs: 300000  // plan limits poll (API)
  readonly property int localPollMs: 30000   // today's tokens + sessions, popup open
  readonly property int fair: 50             // %, a limit above it is yellow
  readonly property int warning: 75          // %, above it orange
  readonly property int critical: 90         // %, from it red
  readonly property string script: Paths.scriptsDir + "/claude.sh"

  property var usage: ({})                     // last good `claude.sh --usage`
  property string error: ""                    // last failure; `usage` keeps older data
  property real fetchedAt: 0                   // when `usage` was fetched
  property var today: ({})                     // see `claude.sh --today`
  property var sessions: []                    // see `claude.sh --sessions`
  property bool popupOpen: false
  property int barUsers: 0

  readonly property string plan: usage.plan ?? ""
  readonly property var limits: usage.limits ?? []
  readonly property int busy: sessions.filter(s => s.status === "busy").length
  readonly property bool refreshing: usageProc.running || todayProc.running

  function finite(value) { return typeof value === "number" && isFinite(value); }
  function record(value) { return value !== null && typeof value === "object" && !Array.isArray(value); }

  function validUsage(o) {
    return record(o) && o.ok === true && typeof o.plan === "string" && Array.isArray(o.limits)
        && o.limits.every(limit => record(limit) && typeof limit.kind === "string"
          && finite(limit.percent) && limit.percent >= 0 && limit.percent <= 100
          && (limit.resets_at === undefined || limit.resets_at === null || typeof limit.resets_at === "string"));
  }

  function validToday(o) {
    return record(o) && ["messages", "input", "output", "cache_read", "cache_write"].every(key =>
      finite(o[key]) && o[key] >= 0);
  }

  function validSessions(rows) {
    return Array.isArray(rows) && rows.every(s => record(s) && typeof s.name === "string"
      && typeof s.cwd === "string" && typeof s.status === "string" && typeof s.version === "string"
      && finite(s.started) && s.started >= 0);
  }

  function validCache(value, timestamp) {
    return validUsage(value) && finite(timestamp) && timestamp > 0 && timestamp <= Date.now();
  }

  // one set of colours for a limit, in the popup's bars and the bar's icon
  function limitColor(percent) {
    return percent >= critical ? Theme.red : percent > warning ? Theme.orange : percent > fair ? Theme.yellow : Theme.green;
  }

  function popupShown() {
    popupOpen = true;
    refresh();
  }

  function popupHidden() { popupOpen = false; }
  function attachBar() { barUsers++; if (barUsers === 1) refreshUsage(); }
  function detachBar() { barUsers = Math.max(0, barUsers - 1); }

  // The usage API rate-limits: on open, ask only if the data is a minute old.
  function refreshUsage() {
    if (Date.now() - fetchedAt > 60000) run(usageProc, ["--usage"]);
  }

  function refresh() {
    refreshUsage();
    refreshLocal();
  }

  function refreshLocal() {
    run(todayProc, ["--today"]);
    run(sessionsProc, ["--sessions"]);
  }

  function run(proc, args) {
    if (proc.running) return;
    proc.command = ["bash", root.script].concat(args);
    proc.running = true;
  }

  function parse(text, fallback) { return Reply.parse(text, "claude.sh", fallback); }

  // the last good usage survives shell restarts: a rate-limited first ask
  // after a restart still has something to show
  FileView {
    path: Quickshell.statePath("claude-usage.json")
    printErrors: false
    onAdapterUpdated: writeAdapter()
    onLoaded: {
      if (root.fetchedAt === 0 && root.validCache(saved.usage, saved.fetchedAt)) {
        root.usage = saved.usage;
        root.fetchedAt = saved.fetchedAt;
      }
    }

    JsonAdapter {
      id: saved
      property var usage: ({})
      property real fetchedAt: 0
    }
  }

  Timer {
    interval: root.usagePollMs
    running: root.barUsers > 0
    repeat: true
    onTriggered: root.run(usageProc, ["--usage"])
  }

  Timer {
    interval: root.localPollMs
    running: root.popupOpen
    repeat: true
    onTriggered: root.refreshLocal()
  }

  Process {
    id: usageProc
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text, { ok: false, error: "no answer" });
        if (root.validUsage(o)) {
          root.usage = o;
          root.fetchedAt = Date.now();
          root.error = "";
          saved.usage = o;
          saved.fetchedAt = root.fetchedAt;
        } else {
          root.error = typeof o?.error === "string" && o.error ? o.error : "bad Claude usage reply";
        }
      }
    }
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.error = "could not start Claude usage query";
    }
  }

  Process {
    id: todayProc
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text, null);
        if (root.validToday(o)) root.today = o;
        else root.error = typeof o?.error === "string" && o.error ? o.error : "bad Claude today reply";
      }
    }
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.error = "could not start Claude today query";
    }
  }

  Process {
    id: sessionsProc
    stdout: StdioCollector {
      onStreamFinished: {
        const rows = Reply.parseList(text, null);
        if (root.validSessions(rows)) root.sessions = rows;
        else root.error = "bad Claude sessions reply";
      }
    }
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.error = "could not start Claude sessions query";
    }
  }
}
