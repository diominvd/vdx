pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.apps.auth
import qs.config
import "../../kit/reply.js" as Reply

// The backups' state (scripts/backup.py), shared by the window. Reads (the
// status, the snapshots, one folder of a snapshot) run on their own; writes
// go through `job`, one at a time: a backup streams its progress, every
// other job ends with one reply. Reinstalling packages is a root action:
// RootService shows its steps and asks for the password.
Singleton {
  id: root

  readonly property string script: Paths.scriptsDir + "/backup.py"

  // ---- tuning ----
  readonly property int messageMs: 6000
  readonly property int revealMs: 20000     // the password stays on show this long

  // ---- settings and status ----
  property var config: ({})
  property var last: null                   // {ts, ok, message, auto, …} or null
  property bool configured: false           // a repository and its password
  property bool resticFound: true
  property bool claude: false               // the claude command is there: the AI analysis is offered
  property bool loaded: false
  property string loadError: ""

  function record(value) { return value !== null && typeof value === "object" && !Array.isArray(value); }
  function finite(value) { return typeof value === "number" && isFinite(value) && value >= 0; }
  function strings(value) { return Array.isArray(value) && value.every(v => typeof v === "string"); }

  function validConfig(value) {
    return record(value) && typeof value.repo === "string" && strings(value.extra) && strings(value.excludes)
      && record(value.sources) && ["home", "etc", "packages", "root"].every(k => typeof value.sources[k] === "boolean")
      && record(value.keep) && typeof value.keep.on === "boolean"
      && ["daily", "weekly", "monthly"].every(k => Number.isInteger(value.keep[k]) && value.keep[k] >= 0 && value.keep[k] <= 999)
      && record(value.schedule) && ["off", "daily", "weekly"].includes(value.schedule.mode)
      && typeof value.schedule.time === "string" && /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(value.schedule.time)
      && typeof value.notify === "boolean";
  }

  function acceptStatus(r) {
    if (r.ok !== true || !validConfig(r.config) || typeof r.configured !== "boolean"
        || typeof r.restic !== "boolean" || typeof r.claude !== "boolean"
        || !(r.last === null || (record(r.last) && finite(r.last.ts)
          && typeof r.last.ok === "boolean" && typeof r.last.message === "string"))) {
      loadError = typeof r.error === "string" && r.error !== "" ? r.error : "bad backup status reply";
      done(false, loadError);
      return false;
    }
    config = r.config;
    last = r.last;
    configured = r.configured;
    resticFound = r.restic;
    claude = r.claude;
    loaded = true;
    loadError = "";
    return true;
  }

  function validSnapshots(rows) {
    return Array.isArray(rows) && rows.every(r => record(r) && typeof r.id === "string"
      && typeof r.short === "string" && finite(r.ts) && finite(r.size) && strings(r.tags) && strings(r.paths));
  }

  function validEntries(rows) {
    return Array.isArray(rows) && rows.every(r => record(r) && typeof r.name === "string"
      && typeof r.path === "string" && typeof r.dir === "boolean" && finite(r.size) && finite(r.ts));
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true;
  }

  Process {
    id: statusProc
    command: ["python3", root.script, "--json", "status"]
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.loadError = "could not start backup status query";
      root.done(false, root.loadError);
    }
    stdout: StdioCollector {
      onStreamFinished: {
        const r = Reply.parse(text, "backup.py");
        root.acceptStatus(r);
      }
    }
  }

  // ---- the restore guide (the same text as `backup.py guide`) ----
  property var guideLines: []
  property string tabRequest: ""            // a part of the shell asks the window for a tab: "restore", …

  function loadGuide() {
    if (!guideProc.running) guideProc.running = true;
  }

  Component.onCompleted: loadGuide()

  Process {
    id: guideProc
    command: ["python3", root.script, "--json", "guide"]
    stdout: StdioCollector {
      onStreamFinished: {
        const r = Reply.parse(text, "backup.py");
        if (r.ok === true && root.strings(r.lines)) root.guideLines = r.lines;
      }
    }
  }

  // ---- sizes: the repository on disk, what the newest snapshot restores to, each folder's size ----
  property real onDisk: -1                  // bytes; -1 until measured
  property real restoreSize: -1
  property var sizes: ({})                  // absolute path -> bytes, of the folders listed

  function loadSize() {
    if (!sizeProc.running && configured) sizeProc.running = true;
  }

  Process {
    id: sizeProc
    command: ["python3", root.script, "--json", "size"]
    stdout: StdioCollector {
      onStreamFinished: {
        const r = Reply.parse(text, "backup.py");
        if (r.ok !== true || !root.finite(r.on_disk) || !root.finite(r.restore)) return;
        root.onDisk = r.on_disk;
        root.restoreSize = r.restore;
      }
    }
  }

  property string sizesSnapshot: ""
  property var sizesNext: null

  function loadSizes(snap, path) {
    if (sizesSnapshot !== snap) { sizesSnapshot = snap; sizes = ({}); }
    if (sizesProc.running) { sizesNext = {snapshot: snap, path}; return; }
    sizesProc.command = ["python3", root.script, "--json", "sizes", snap, path];
    sizesProc.running = true;
  }

  Process {
    id: sizesProc
    onRunningChanged: {
      if (running || !root.sizesNext) return;
      const next = root.sizesNext;
      root.sizesNext = null;
      root.loadSizes(next.snapshot, next.path);
    }
    stdout: StdioCollector {
      onStreamFinished: {
        const r = Reply.parse(text, "backup.py");
        if (sizesProc.command[4] !== root.sizesSnapshot || r.ok !== true || !r.sizes
            || typeof r.sizes !== "object" || Array.isArray(r.sizes)
            || !Object.keys(r.sizes).every(k => typeof r.sizes[k] === "number"
              && isFinite(r.sizes[k]) && r.sizes[k] >= 0)) return;
        root.sizes = Object.assign({}, root.sizes, r.sizes);
      }
    }
  }

  // ---- snapshots ----
  property var snapshots: []                // newest first
  property bool listing: false

  function loadSnapshots() {
    if (snapsProc.running) return;
    listing = true;
    snapsProc.running = true;
  }

  Process {
    id: snapsProc
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.done(false, "could not start backup snapshots query");
      root.listing = false;
    }
    command: ["python3", root.script, "--json", "snapshots"]
    stdout: StdioCollector {
      onStreamFinished: {
        const r = Reply.parse(text, "backup.py");
        if (r.ok !== true || !root.validSnapshots(r.snapshots)) root.done(false, r.error || "bad backup snapshots reply");
        else root.snapshots = r.snapshots;
        root.listing = false;
      }
    }
  }

  // the folder open in the Snapshots page: its entries, one level at a time
  property string snapshot: ""              // short id; "" when none is open
  property string folder: "/"
  property var entries: []
  property bool browsing: false
  property var browseNext: null             // the latest folder asked while one is listed

  function browse(snap, path) {
    snapshot = snap;
    folder = path;
    if (lsProc.running) { browseNext = { snapshot: snap, path: path }; return; }
    entries = [];
    browsing = true;
    lsProc.command = ["python3", root.script, "--json", "ls", snap, path];
    lsProc.running = true;
    loadSizes(snap, path);
  }

  function leave() { browseNext = null; snapshot = ""; entries = []; folder = "/"; }

  Process {
    id: lsProc
    property bool started: false
    onStarted: started = true
    stdout: StdioCollector {
      onStreamFinished: {
        const r = Reply.parse(text, "backup.py");
        if (lsProc.command[4] !== root.snapshot || lsProc.command[5] !== root.folder) return;
        if (r.ok !== true || !root.validEntries(r.entries) || r.path !== root.folder) {
          root.done(false, r.error || "bad backup folder reply");
          return;
        }
        root.entries = r.entries;
      }
    }
    onRunningChanged: {
      if (running) return;
      if (!started) root.done(false, "could not start backup folder query");
      started = false;
      if (root.browseNext) {
        const next = root.browseNext;
        root.browseNext = null;
        root.browse(next.snapshot, next.path);
      } else root.browsing = false;
    }
  }

  // ---- jobs: one at a time ----
  property bool busy: false
  property string jobKind: ""               // run init password config schedule restore packages forget verify
  property real progress: -1                // 0–100 while a backup runs
  property var answer: null                 // the job's reply, once it has come
  property string status: ""                // "" | ok | error
  property string message: ""
  property string revealed: ""              // the password, shown on request
  property string restored: ""              // the folder of the last restore
  property var aiSuggestions: []            // [{path, shown, mb, days, why, risk}] from Claude
  property var aiApplying: []
  property var nextJob: null
  property var aiPicked: ({})               // path -> bool: what the user leaves out

  function job(kind, args) {
    if (busy) return false;
    busy = true;
    jobKind = kind;
    answer = null;
    progress = -1;
    status = "";
    jobProc.command = ["python3", root.script, "--json"].concat(args);
    jobProc.running = true;
    return true;
  }

  function feed(line) {
    const r = Reply.parse(line, "backup.py", null);
    if (r === null) return;
    if (r.progress !== undefined) {
      if (typeof r.progress === "number" && isFinite(r.progress) && r.progress >= 0 && r.progress <= 100) root.progress = r.progress;
    }
    else root.answer = r;
  }

  function completeJob(reply) {
    const kind = jobKind;
    answer = null;
    progress = -1;
    jobKind = "";
    finish(kind, reply);
    const next = nextJob;
    nextJob = null;
    if (next) {
      // Keep ownership while handing off an authorized follow-up.
      jobKind = next.kind;
      status = "";
      jobProc.command = ["python3", root.script, "--json"].concat(next.args);
      jobProc.running = true;
    } else busy = false;
  }

  Process {
    id: jobProc
    property bool started: false
    property var reply: null
    onStarted: { started = true; reply = null; }
    stdout: SplitParser { onRead: line => root.feed(line) }
    stderr: StdioCollector { id: jobErr }
    onExited: code => {
      const r = code === 0 && root.answer !== null ? root.answer
        : { ok: false, error: ((typeof root.answer?.error === "string" ? root.answer.error : "") || jobErr.text.trim().split("\n").pop()
          || "no reply from the backup script").slice(0, 200) };
      reply = r;
    }
    onRunningChanged: {
      if (running) return;
      const r = started ? reply : {ok: false, error: "could not start backup job"};
      started = false;
      root.completeJob(r || {ok: false, error: "no reply from the backup script"});
    }
  }

  function validJobReply(kind, r) {
    if (r.ok !== true) return true;
    const object = value => value !== null && typeof value === "object" && !Array.isArray(value);
    if (kind === "password") return typeof r.password === "string";
    if (kind === "pick") return typeof r.path === "string" && r.path !== "";
    if (kind === "config" || kind === "schedule") return validConfig(r.config);
    if (kind === "restore") return typeof r.target === "string";
    if (kind === "packages" || kind === "rootplan")
      return typeof r.script === "string" && r.script.trim() !== "" && Array.isArray(r.steps)
        && r.steps.length > 0 && r.steps.every(s => object(s) && typeof s.label === "string"
          && typeof s.what === "string" && typeof s.command === "string");
    if (kind === "aur") return Array.isArray(r.aur) && r.aur.every(n => typeof n === "string" && n !== "");
    if (kind === "ai") return Array.isArray(r.suggestions) && r.suggestions.every(s => object(s)
      && typeof s.path === "string" && typeof s.shown === "string" && typeof s.why === "string"
      && typeof s.mb === "number" && isFinite(s.mb) && typeof s.days === "number" && isFinite(s.days)
      && (s.risk === "low" || s.risk === "medium"));
    return true;
  }

  function finish(kind, r) {
    if (r.ok !== true) r = {ok: false, error: typeof r.error === "string" && r.error !== "" ? r.error : "backup job failed"};
    if (!validJobReply(kind, r)) r = {ok: false, error: "bad backup " + kind + " reply"};
    if (kind === "password") {
      if (r.ok) { root.revealed = r.password; hideSecret.restart(); }
      else root.done(false, r.error);
      return;
    }
    if (kind === "packages") {
      if (!r.ok) { root.done(false, r.error); return; }
      if (!RootService.request("Backups", "Reinstall packages", r.steps, r.script, "backup-packages"))
        root.done(false, "another root action is waiting");
      else root.message = r.message;
      return;
    }
    if (kind === "pick") {
      if (r.ok) nextJob = {kind: "init", args: ["init", "--repo", r.path]};
      else root.done(false, r.error);
      return;
    }
    if (kind === "ai") {
      if (!r.ok) { root.done(false, r.error); return; }
      const picked = {};
      r.suggestions.forEach(s => picked[s.path] = s.risk === "low");
      root.aiSuggestions = r.suggestions;
      root.aiPicked = picked;
      root.done(true, r.message);
      return;
    }
    if (kind === "rootplan") {
      if (!r.ok) { root.done(false, r.error); return; }
      if (!RootService.request("Backups", "Back up the root-only files", r.steps, r.script, "backup-root"))
        root.done(false, "another root action is waiting");
      return;
    }
    if (kind === "aur") {
      if (!r.ok) { root.done(false, r.error); return; }
      // yay builds each one in a terminal, shows its PKGBUILD and asks for the password itself
      Quickshell.execDetached(["kitty", "-e", "bash", "-c",
        "yay -S --needed --sudo pkexec \"$@\"; echo; read -rp 'press Enter to close ' _",
        "bash"].concat(r.aur));
      root.done(true, r.message + " · in the terminal");
      return;
    }
    if (kind === "config") {
      if (r.ok) {
        root.config = r.config;
        if (aiApplying.length) {
          root.aiSuggestions = aiSuggestions.filter(s => !aiApplying.includes(s.path));
          const picked = Object.assign({}, aiPicked);
          aiApplying.forEach(path => delete picked[path]);
          aiPicked = picked;
        }
      } else root.done(false, r.error);
      aiApplying = [];
      return;
    }
    if (r.ok && (kind === "schedule")) root.config = r.config;
    // a manual run also takes the root-only files, when the switch is on (the root panel asks the password)
    if (kind === "run" && r.ok && root.config.sources && root.config.sources.root === true) nextJob = {kind: "rootplan", args: ["root-plan"]};
    if (r.ok && kind === "restore") root.restored = r.target;
    done(r.ok, r.ok ? r.message : r.error);
    if (kind === "run" || kind === "init" || kind === "schedule" || kind === "forget") {
      refresh();
      loadSnapshots();
      loadSize();
    }
  }

  Connections {
    target: RootService
    function onFinished(tag, ok, error) {
      if (tag === "backup-root") {
        root.done(ok, ok ? "Root-only files backed up" : error === "cancelled" ? "Root-only backup cancelled" : error);
        return;
      }
      if (tag !== "backup-packages") return;
      root.done(ok, ok ? "Packages reinstalled" : error === "cancelled" ? "Reinstall cancelled" : error);
    }
  }

  // ---- actions ----
  function runNow() { return job("run", ["run"]); }
  function cancel() { if (busy && jobKind === "run") jobProc.signal(2); }
  function init(repo) { return job("init", ["init", "--repo", repo]); }
  // any folder, chosen in the Files window; it becomes the repository at once
  function pick() { return job("pick", ["pick"]); }
  function showPassword() { return job("password", ["password"]); }
  function setConfig(change) { return job("config", ["config", "set", JSON.stringify(change)]); }
  function setSchedule(mode, time) { return job("schedule", ["schedule", mode, "--time", time]); }
  function verify(deep) { return job("verify", ["verify"].concat(deep ? ["--deep"] : [])); }
  function packages(snap) { return job("packages", ["packages", snap]); }
  function aur(snap) { return job("aur", ["aur", snap]); }
  function analyze() { return job("ai", ["ai"]); }
  function aiPick(path, on) {
    const p = Object.assign({}, aiPicked);
    p[path] = on;
    aiPicked = p;
  }
  // Remove submitted suggestions only after the excludes are saved.
  function aiApply() {
    const paths = aiSuggestions.filter(s => aiPicked[s.path]).map(s => s.path);
    if (paths.length === 0) return;
    if (busy) return;
    aiApplying = paths.slice();
    if (!setConfig({ "excludes": (config.excludes ?? []).concat(paths) })) aiApplying = [];
  }
  function forget(snaps) { return job("forget", ["forget"].concat(snaps)); }

  // paths: the folders or files to restore; none restores the whole snapshot
  function restore(snap, paths) {
    const args = ["restore", snap];
    paths.forEach(p => args.push("--include", p));
    return job("restore", args);
  }

  // wl-copy: the shell says it was copied, or why not (it is not installed)
  property bool copied: false
  function copyPassword() {
    if (copyProc.running || revealed === "") return;
    copyProc.secret = revealed;
    copyProc.stdinEnabled = true;
    copyProc.running = true;
  }

  Process {
    id: copyProc
    command: ["wl-copy"]
    property string secret: ""
    property bool started: false
    onStarted: {
      started = true;
      write(secret);
      secret = "";
      stdinEnabled = false;
    }
    onRunningChanged: {
      if (running) return;
      secret = "";
      if (started) { started = false; return; }
      root.copied = false;
      root.done(false, "could not start clipboard command");
    }
    stderr: StdioCollector { id: copyErr }
    onExited: code => {
      root.copied = code === 0;
      copiedReset.restart();
      root.done(code === 0, code === 0 ? "Password copied to the clipboard"
        : "Not copied: " + (copyErr.text.trim() || "wl-copy failed (wl-clipboard installed?)").slice(0, 120));
    }
  }

  Timer {
    id: copiedReset
    interval: 2500
    onTriggered: root.copied = false
  }

  // asks the window for a tab (the bar's Guide button, a page's link)
  function showTab(tab) {
    tabRequest = "";
    tabRequest = tab;
  }

  function openFolder(path) { Quickshell.execDetached(["xdg-open", path]); }

  // the time since a timestamp, in words
  function agoText(ts) {
    if (!ts) return "never";
    const s = Date.now() / 1000 - ts;
    if (s < 60) return "just now";
    if (s < 3600) return Math.floor(s / 60) + " min ago";
    if (s < 86400) return Math.floor(s / 3600) + " h ago";
    return Math.floor(s / 86400) + " days ago";
  }

  function done(ok, text) {
    status = ok ? "ok" : "error";
    message = text;
    statusReset.restart();
  }

  Timer {
    id: statusReset
    interval: root.messageMs
    onTriggered: { root.status = ""; root.message = ""; }
  }

  Timer {
    id: hideSecret
    interval: root.revealMs
    onTriggered: root.revealed = ""
  }
}
