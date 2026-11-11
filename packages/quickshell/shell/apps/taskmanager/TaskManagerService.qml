pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.sysmon
import "../../kit/reply.js" as Reply

// The task manager's state (scripts/tasks.py), polled while its window or
// its bar popup is open: the processes, the machine's CPU and memory, the
// view — filtered, grouped by program or one row per process, sorted — and
// ending what is selected or any row (TERM, or KILL). Options: Shell
// Manager › Shell apps › Task manager (ModuleSettings "taskmanager").
Singleton {
  id: root

  readonly property string script: Paths.scriptsDir + "/tasks.py"

  // ---- options ----
  function opt(key, fallback) { return ModuleSettings.get("taskmanager", key, fallback); }
  readonly property bool group: opt("group", true)
  readonly property bool kernel: opt("kernel", false)
  readonly property bool onlyMine: opt("onlyMine", false)
  readonly property string sortBy: opt("sortBy", "cpu")          // cpu | mem | name
  readonly property int refreshMs: opt("refresh", 2) * 1000
  readonly property bool confirm: opt("confirm", true)

  function setSort(key) { ModuleSettings.set("taskmanager", "sortBy", key); }

  // ---- data ----
  property bool open: false                 // the window is up: poll
  property bool popupOpen: false            // … or the bar's popup
  readonly property bool watching: open || popupOpen
  // GPU and network come from the System module's sampler, kept full meanwhile
  onWatchingChanged: watching ? SysmonService.hold() : SysmonService.release()

  // ---- gpu, network ----
  readonly property var dgpu: SysmonService.dgpu
  readonly property var igpu: SysmonService.igpu
  // the GPU's load: NVIDIA's own when it is awake, else Intel's clock share
  readonly property real gpu: dgpu.state === "active" ? (dgpu.util ?? 0)
                            : igpu && igpu.max > 0 ? 100 * igpu.cur / igpu.max : 0
  readonly property string gpuName: dgpu.state === "active" ? "NVIDIA" : igpu ? "INTEL" : "NONE"
  readonly property real rx: SysmonService.rxRate
  readonly property real tx: SysmonService.txRate

  // ---- history (the graphs): one point per refresh, the last `historyLength` ----
  readonly property int historyLength: 60
  property var cpuHistory: []
  property var memHistory: []
  property var gpuHistory: []
  property var rxHistory: []
  property var txHistory: []

  function keep(list, value) { return list.concat([value]).slice(-historyLength); }
  function record() {
    cpuHistory = keep(cpuHistory, cpu);
    memHistory = keep(memHistory, 100 * memUsed / memTotal);
    gpuHistory = keep(gpuHistory, gpu);
    rxHistory = keep(rxHistory, rx);
    txHistory = keep(txHistory, tx);
  }

  function replyError(r, fallback) {
    return typeof r?.error === "string" && r.error.trim() !== "" ? r.error : fallback;
  }

  function validListReply(r) {
    const finiteNonnegative = n => typeof n === "number" && isFinite(n) && n >= 0;
    return r?.ok === true && Array.isArray(r.procs)
      && typeof r.cpu === "number" && isFinite(r.cpu) && r.cpu >= 0 && r.cpu <= 100
      && finiteNonnegative(r.memUsed)
      && typeof r.memTotal === "number" && isFinite(r.memTotal) && r.memTotal > 0
      && r.procs.every(p => p && Number.isInteger(p.pid) && p.pid > 0
        && Number.isInteger(p.ppid) && p.ppid >= 0
        && typeof p.name === "string" && typeof p.user === "string" && typeof p.cmd === "string"
        && typeof p.mine === "boolean" && typeof p.kernel === "boolean"
        && finiteNonnegative(p.cpu) && finiteNonnegative(p.mem) && finiteNonnegative(p.threads));
  }

  function acceptListReply(r) {
    if (r?.ok !== true) { queryError = replyError(r, "could not read task list"); return false; }
    if (!validListReply(r)) { queryError = "bad task list reply"; return false; }
    procs = r.procs;
    cpu = r.cpu;
    memUsed = r.memUsed;
    memTotal = r.memTotal;
    queryError = "";
    record();
    return true;
  }
  property var procs: []
  property real cpu: 0                      // the machine, 0–100
  property real memUsed: 0
  property real memTotal: 1
  property string query: ""

  // ---- view ----
  // the window's tab: programs (one row each, when `group`) or processes (one
  // row per pid); the bar popup always lists programs (`popupRows`)
  property string tab: "programs"
  readonly property bool grouped: group && tab === "programs"

  // a row: {key, name, user, pids, ppid, count, cpu, mem, threads, cmd}; ppid and pid are 0 for a program
  function build(byProgram) {
    const q = query.trim().toLowerCase();
    let list = procs.filter(p => (kernel || !p.kernel) && (!onlyMine || p.mine)
                              && (q === "" || p.name.toLowerCase().includes(q) || String(p.pid) === q
                                  || p.cmd.toLowerCase().includes(q)));
    let out;
    if (byProgram) {
      const by = Object.create(null);
      out = [];
      for (const p of list) {
        let r = by[p.name];
        if (!r) {
          r = by[p.name] = { key: p.name, name: p.name, user: p.user, pids: [], ppid: 0, pid: 0, count: 0, cpu: 0, mem: 0, threads: 0, cmd: p.cmd };
          out.push(r);
        }
        if (r.user !== p.user) r.user = "—";
        r.pids.push(p.pid);
        r.count++;
        r.cpu += p.cpu;
        r.mem += p.mem;
        r.threads += p.threads;
      }
    } else {
      out = list.map(p => ({ key: String(p.pid), name: p.name, user: p.user, pids: [p.pid], ppid: p.ppid, pid: p.pid, count: 1,
                             cpu: p.cpu, mem: p.mem, threads: p.threads, cmd: p.cmd }));
    }
    const by = sortBy;
    out.sort((a, b) => by === "name" ? a.name.localeCompare(b.name)
                     : by === "mem" ? b.mem - a.mem || a.name.localeCompare(b.name)
                     : by === "pid" ? a.pid - b.pid
                     : b.cpu - a.cpu || b.mem - a.mem);
    return out;
  }

  readonly property var rows: build(grouped)
  readonly property var popupRows: build(group)

  property string selected: ""              // a row's key
  readonly property var selectedRow: rows.find(r => r.key === selected) ?? null

  // the pid of a process and of all its descendants (children, their children …)
  function treePids(pid) {
    const kids = Object.create(null);
    for (const p of procs) (kids[p.ppid] = kids[p.ppid] ?? []).push(p.pid);
    const out = [], todo = [pid], seen = new Set();
    while (todo.length > 0) {
      const next = todo.pop();
      if (seen.has(next)) continue;
      seen.add(next);
      out.push(next);
      todo.push(...(kids[next] ?? []));
    }
    return out;
  }

  // the search shows just the selected process's parent, which becomes the selection
  function goParent() {
    const row = selectedRow;
    if (!row || grouped || row.ppid <= 0) return;
    query = String(row.ppid);
    selected = String(row.ppid);
  }

  // ---- actions ----
  property bool busy: false
  property string status: ""                // "" | ok | error
  property string queryError: ""
  property string actionError: ""
  readonly property string error: actionError || queryError
  property string notice: ""                // a line in the foot, cleared after a moment

  function end(force) { endRow(selectedRow, force); }

  // TERM the selected process and everything under it (processes tab)
  function endTree() {
    if (!selectedRow || grouped) return;
    endRow({ pids: treePids(selectedRow.pids[0]) }, false);
  }

  function copyPid() {
    const row = selectedRow;
    if (!row || grouped || copyProc.running) return;
    status = "";
    actionError = "";
    notice = "";
    copyProc.command = ["wl-copy", String(row.pids[0])];
    copyProc.running = true;
  }

  function finishKill(message) {
    status = "error";
    actionError = typeof message === "string" && message.trim() !== "" ? message : "task action failed";
    statusReset.restart();
    refresh();
    busy = false;
  }

  function acceptKillReply(r) {
    if (r?.ok !== true) { finishKill(replyError(r, "task action failed")); return false; }
    if (!Number.isInteger(r.killed) || r.killed < 0) { finishKill("bad task kill reply"); return false; }
    status = "ok";
    actionError = "";
    statusReset.restart();
    refresh();
    busy = false;
    return true;
  }

  // TERM (or KILL) every process of a row
  function endRow(row, force) {
    if (!row || busy) return;
    busy = true;
    actionError = "";
    killProc.command = ["python3", script, "kill", force ? "KILL" : "TERM"].concat(row.pids.map(String));
    killProc.running = true;
  }

  function refresh() { if (!listProc.running) listProc.running = true; }

  function parse(text) {
    return Reply.parse(text, "tasks.py");
  }

  Timer {
    interval: root.refreshMs
    running: root.watching
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: statusReset
    interval: Theme.popupStatusMs
    onTriggered: { root.status = ""; root.notice = ""; }
  }

  Process {
    id: listProc
    command: ["python3", root.script, "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.acceptListReply(root.parse(text));
      }
    }
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.queryError = "could not start task list query";
    }
  }

  Process {
    id: copyProc
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.status = "error";
      root.actionError = "could not start PID copy";
      root.notice = "";
      statusReset.restart();
    }
    stderr: StdioCollector { id: copyError }
    onExited: code => {
      if (code === 0) {
        root.status = "ok";
        root.actionError = "";
        root.notice = "PID " + String(copyProc.command[1]) + " copied";
      } else {
        root.status = "error";
        root.actionError = copyError.text.trim() || "could not copy PID";
        root.notice = "";
      }
      statusReset.restart();
    }
  }

  Process {
    id: killProc
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.finishKill("could not start task action");
    }
    stdout: StdioCollector {
      onStreamFinished: {
        root.acceptKillReply(root.parse(text));
      }
    }
  }
}
