pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.apps.auth
import qs.config
import "../../kit/reply.js" as Reply

// The package manager's state (scripts/packages.py), shared by its window and
// its bar module: pending updates from the repos and the AUR, the installed
// packages (the picked ones can be removed), pacman's cache with its versions,
// and the rollback of the last upgrade. The repo updates (download, then
// install from the cache), removing and rolling back go to RootService, which
// shows the steps first. The AUR updates open a terminal running
// `yay -S --needed --sudo pkexec`: yay shows the builds there, and the password
// comes from the auth panel.
Singleton {
  id: root

  readonly property string script: Paths.scriptsDir + "/packages.py"

  // ---- updates ----
  property var pacman: []                   // [{name, from, to}]
  property var aur: []
  property string aurError: ""
  property bool checking: false
  property real checkedAt: 0                // ms; 0: never
  // ---- options (Shell Manager › Shell apps, ModuleSettings "packages") ----
  function opt(key, fallback) { return ModuleSettings.get("packages", key, fallback); }
  readonly property bool aurOn: opt("aur", true)
  readonly property bool confirm: opt("confirm", true)

  readonly property int count: pacman.length + (aurOn ? aur.length : 0)
  // every pending update in one list: {name, from, to, desc, repo, aur}
  readonly property var pending: pacman.map(p => Object.assign({ aur: false }, p))
      .concat(aurOn ? aur.map(p => Object.assign({ aur: true }, p)) : [])
  property var updPicked: ({})              // name -> bool
  readonly property var pickedUpdates: pending.filter(p => updPicked[p.name] === true)

  // ---- installed ----
  property var installed: []                // [{name, version, desc, size, aur, repo, explicit, apps}]
  property bool loading: false
  property var picked: ({})                 // name -> bool
  readonly property var pickedNames: Object.keys(picked).filter(n => picked[n])
  readonly property real pickedSize: installed.filter(p => picked[p.name]).reduce((s, p) => s + p.size, 0)

  // ---- cache ----
  property var cache: []                    // [{name, installed, versions: [{version, file, size, date}]}]
  property var lastUpdate: null             // {date, packages: [{name, from, to, file}], missing: [{name, from}]}
  readonly property int rollbackCount: lastUpdate?.packages?.length ?? 0

  // ---- actions ----
  property bool busy: false
  property string status: ""                // "" | ok | error
  property string message: ""

  function pick(name, on) { pickMany([name], on); }

  function pickMany(names, on) {
    const p = Object.assign({}, picked);
    for (const n of names) p[n] = on;
    picked = p;
  }

  function pickUpdate(name, on) {
    const p = Object.assign({}, updPicked);
    p[name] = on;
    updPicked = p;
  }

  function pickAllUpdates(on) {
    const p = {};
    for (const u of pending) p[u.name] = on;
    updPicked = p;
  }

  function parse(text) {
    return Reply.parse(text, "packages.py");
  }

  // ---- checks ----
  function check() {
    if (checking) return;
    checking = true;
    checkProc.running = true;
  }

  function loadInstalled() {
    if (installedProc.running) return;
    loading = true;
    installedProc.running = true;
  }

  function loadCache() {
    if (cacheProc.running) return;
    cacheProc.running = true;
  }

  function loadLast() {
    if (lastProc.running) return;
    lastProc.running = true;
  }

  // the whole view again. The update check runs when forced (the refresh
  // button), or on opening when the option is on and the last check is old
  function freshen(force) {
    if (force || (opt("checkOnOpen", true) && Date.now() - checkedAt > 600000)) check();
    loadInstalled();
    loadCache();
    loadLast();
  }

  Component.onCompleted: check()

  // the repos and the AUR move on: check again at the chosen interval (0: off)
  Timer {
    interval: root.opt("interval", 30) * 60000
    running: root.opt("interval", 30) > 0
    repeat: true
    onTriggered: root.check()
  }

  // ---- actions ----
  // ---- the in-app update of the repo packages: download, then install ----
  // Each stage is a root action confirmed in the auth panel (RootService).
  // Progress is what the cache holds of the new versions (scripts/packages.py
  // progress), against the download sizes.
  property string stage: ""                 // "" | downloading | installing
  property var stageList: []                // [{name, from, to, size}]
  property real stageBytes: 0               // all of the download
  property real stageDone: 0                // what is in the cache so far
  readonly property real stagePercent: stageBytes > 0 ? Math.min(1, stageDone / stageBytes) : 0
  readonly property var repoPending: pending.filter(p => !p.aur)
  readonly property var repoPicked: pickedUpdates.filter(p => !p.aur)
  readonly property var aurPicked: pickedUpdates.filter(p => p.aur)
  readonly property real repoPickedSize: repoPicked.reduce((s, p) => s + p.size, 0)

  function updatePicked() { startDownload(repoPicked); }
  function updateAll() { startDownload(repoPending); }

  function startDownload(list) {
    if (busy || stage !== "" || list.length === 0) return;
    busy = true;
    status = "";
    stageList = list;
    stageBytes = list.reduce((s, p) => s + p.size, 0);
    stageDone = 0;
    stage = "downloading";
    planProc.command = ["python3", root.script, "plan-download"].concat(list.map(p => p.name));
    planProc.plan = { tag: "packages-download", title: "Download updates" };
    planProc.running = true;
  }

  // the install, from the cache, after the download is confirmed and done
  function startInstall() {
    stage = "installing";
    planProc.command = ["python3", root.script, "plan-install"].concat(stageList.map(p => p.name));
    planProc.plan = { tag: "packages-install", title: "Install updates" };
    planProc.running = true;
  }

  Timer {
    id: progressTimer
    interval: 500
    repeat: true
    running: root.stage === "downloading"
    triggeredOnStart: true
    onTriggered: if (!progressProc.running) progressProc.running = true
  }

  Process {
    id: progressProc
    command: ["python3", root.script, "progress"].concat(root.stageList.map(p => p.name + "=" + p.to))
    stdout: StdioCollector {
      onStreamFinished: {
        const r = root.parse(text);
        if (r.ok && root.stage === "downloading") root.stageDone = r.bytes;
      }
    }
  }

  // the AUR picks: built by yay, which shows each PKGBUILD in a terminal
  function updateAur() {
    if (aurPicked.length === 0) return;
    Quickshell.execDetached(["kitty", "-e", "bash", "-c",
      "yay -S --needed --sudo pkexec \"$@\"; echo; read -rp 'press Enter to close ' _",
      "bash"].concat(aurPicked.map(p => p.name)));
    updPicked = ({});
  }

  function removePicked() {
    if (busy || pickedNames.length === 0) return;
    busy = true;
    status = "";
    planProc.command = ["python3", root.script, "plan-remove"].concat(pickedNames);
    planProc.plan = { tag: "packages-remove", title: "Remove packages" };
    planProc.running = true;
  }

  function rollback(files) {
    if (busy || files.length === 0) return;
    busy = true;
    status = "";
    planProc.command = ["python3", root.script, "plan-rollback"].concat(files);
    planProc.plan = { tag: "packages-rollback", title: "Roll back" };
    planProc.running = true;
  }

  function rollbackLast() { rollback((lastUpdate?.packages ?? []).map(p => p.file)); }

  function done(ok, text) {
    status = ok ? "ok" : "error";
    message = text;
    statusReset.restart();
  }

  Timer {
    id: statusReset
    interval: 6000
    onTriggered: { root.status = ""; root.message = ""; }
  }

  // the plan's steps go to RootService, which shows them and runs the script
  Process {
    id: planProc
    property var plan: null
    stdout: StdioCollector {
      onStreamFinished: {
        const r = root.parse(text);
        if (!r.ok) { root.endStage(false, r.error); return; }
        if (!RootService.request("Packages", planProc.plan.title, r.steps, r.script, planProc.plan.tag, root.skipPanel(planProc.plan.tag))) {
          root.endStage(false, "another root action is waiting");
        }
      }
    }
  }

  // the end of a stage (or of a failed plan): the flags off, the message, the lists again
  function endStage(ok, text) {
    if (opt("notify", true) && text !== "Download cancelled" && text !== "Install cancelled")
      notify(ok, text);
    stage = "";
    busy = false;
    done(ok, text);
    freshen(true);
  }

  // the update stages run without the confirmation panel when the options say so
  function skipPanel(tag) {
    if (tag === "packages-install" && opt("autoInstall", false)) return true;
    return opt("noConfirm", false) && (tag === "packages-install" || tag === "packages-download");
  }

  function notify(ok, text) {
    Quickshell.execDetached(["notify-send", "-a", "Packages", "-u", ok ? "normal" : "critical",
      ok ? "Updates installed" : "Update failed",
      ok ? "All updates are installed (" + stageList.length + " packages)." : text]);
  }

  Connections {
    target: RootService
    function onFinished(tag, ok, error) {
      if (!tag.startsWith("packages-")) return;
      const cancelled = error === "cancelled";
      if (tag === "packages-download") {
        // downloaded: the install is a second confirmation in the panel
        if (ok) { root.stageDone = root.stageBytes; root.startInstall(); }
        else root.endStage(false, cancelled ? "Download cancelled" : error);
        return;
      }
      if (tag === "packages-install") {
        if (ok) root.updPicked = ({});
        root.endStage(ok, ok ? "Updated " + root.stageList.length + " packages" : cancelled ? "Install cancelled" : error);
        return;
      }
      root.busy = false;
      if (!ok) { root.done(false, cancelled ? "cancelled" : error); return; }
      if (tag === "packages-remove") root.picked = ({});
      root.done(true, tag === "packages-remove" ? "Removed" : "Rolled back");
      root.freshen();
    }
  }

  Process {
    id: checkProc
    command: ["python3", root.script, "updates"]
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.checking = false;
      root.done(false, "could not start package update check");
    }
    stdout: StdioCollector {
      onStreamFinished: {
        const r = root.parse(text);
        root.checking = false;
        if (!r.ok) { root.done(false, r.error); return; }
        root.pacman = r.pacman;
        root.aur = r.aur;
        root.aurError = r.aurError;
        root.checkedAt = Date.now();
      }
    }
  }

  Process {
    id: installedProc
    command: ["python3", root.script, "installed"]
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.loading = false;
      root.done(false, "could not start installed package query");
    }
    stdout: StdioCollector {
      onStreamFinished: {
        const r = root.parse(text);
        root.loading = false;
        if (!r.ok) { root.done(false, r.error); return; }
        root.installed = r.packages;
      }
    }
  }

  Process {
    id: cacheProc
    command: ["python3", root.script, "cache"]
    stdout: StdioCollector {
      onStreamFinished: {
        const r = root.parse(text);
        if (!r.ok) { root.done(false, r.error); return; }
        root.cache = r.packages;
      }
    }
  }

  Process {
    id: lastProc
    command: ["python3", root.script, "last-update"]
    stdout: StdioCollector {
      onStreamFinished: {
        const r = root.parse(text);
        if (!r.ok) { root.done(false, r.error); return; }
        root.lastUpdate = r;
      }
    }
  }
}
