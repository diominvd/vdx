pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../../kit/reply.js" as Reply

// mihomo state and actions on top of scripts/mihomo.sh. The bar module and the
// popup only read these properties and call these functions.
Singleton {
  id: root

  // ---- tuning ----
  readonly property string defaultGroup: "Proxies"
  readonly property int statusPollMs: 2000     // while the popup is open
  readonly property int idlePollMs: 15000      // closed: the face only
  readonly property int trafficRestartMs: 2000
  readonly property string script: Paths.scriptsDir + "/mihomo.sh"

  // ---- service ----
  property bool serviceOn: false
  property bool toggling: false                // start / stop in flight
  property string mode: "rule"
  property string group: root.defaultGroup
  property string current: ""                  // node the policy group points at
  property string currentProvider: ""          // provider of that node
  property int currentDelay: 0                 // last measured ping of `current`, ms

  // ---- providers / servers ----
  property var providers: []                   // [{name, nodes}]
  property string provider: ""                 // provider whose servers are listed
  property var nodes: []                       // [{name, alive, delay}]
  property string nodesWantedProvider: ""

  // ---- actions ----
  property bool updating: false
  property bool pinging: false
  property string error: ""                    // last failed action, shown in the popup
  property bool toggleBefore: false

  // ---- traffic (measured only while the popup is open) ----
  property real up: 0
  property real down: 0
  property real upTotal: 0
  property real downTotal: 0

  property bool popupOpen: false
  property bool statusQueued: false

  // ---- lifecycle ----
  function popupShown() {
    popupOpen = true;
    error = "";
    refresh();
  }

  function popupHidden() {
    popupOpen = false;
  }

  onPopupOpenChanged: trafficProc.running = popupOpen
  onProviderChanged: refreshNodes()

  Component.onCompleted: refresh()

  // ---- actions ----
  function toggleService() {
    if (toggling || toggleProc.running) return;
    toggleBefore = serviceOn;
    toggling = true;
    serviceOn = !serviceOn;
    if (!run(toggleProc, ["--toggle"])) {
      serviceOn = toggleBefore;
      error = "could not start mihomo toggle";
      toggling = false;
    }
  }

  function selectNode(name) {
    if (serviceOn && typeof name === "string" && name !== "" && !selectProc.running) {
      error = "";
      selectProc.reply = null;
      selectProc.exitCode = -1;
      if (!run(selectProc, ["--select", name])) finishSelect(null, false, true);
    }
  }

  function pingNodes() {
    if (!serviceOn || provider === "" || pinging || pingProc.running) return;
    pinging = true;
    error = "";
    if (!run(pingProc, ["--ping", provider])) {
      error = "could not start ping";
      pinging = false;
    }
  }

  function runUpdate() {
    if (updating || updateProc.running) return;
    updating = true;
    error = "";
    if (!run(updateProc, ["--update"])) {
      error = "could not start update";
      updating = false;
    }
  }

  function openMihomoConfig() { run(pathProc, ["--config-path"]); }
  function openProviderConfig(name) { run(pathProc, ["--path", name]); }

  // ---- internals ----
  function run(proc, args) {
    if (proc.running) return false;
    proc.command = ["bash", root.script].concat(args);
    proc.running = true;
    return true;
  }

  function parse(text) {
    return Reply.parse(text, "mihomo.sh", null);
  }

  function refresh() {
    refreshStatus();
    refreshProviders();
  }

  function refreshStatus() {
    if (statusProc.running) { statusQueued = true; return; }
    statusProc.running = true;
  }
  function refreshProviders() { if (!providersProc.running) providersProc.running = true; }

  function refreshNodes() {
    nodesWantedProvider = serviceOn ? provider : "";
    if (nodesWantedProvider === "") { nodes = []; return; }
    if (!nodesProc.running) startNodes();
  }

  function startNodes() {
    const wanted = nodesWantedProvider;
    if (wanted === "" || nodesProc.running) return;
    nodesProc.requestedProvider = wanted;
    run(nodesProc, ["--nodes", wanted]);
  }

  function finiteNonnegative(n) { return typeof n === "number" && isFinite(n) && n >= 0; }

  function acceptStatus(o) {
    if (!o || !["on", "off"].includes(o.service) || typeof o.mode !== "string"
        || typeof o.group !== "string" || typeof o.node !== "string" || typeof o.provider !== "string"
        || !Number.isInteger(o.delay) || o.delay < 0) return false;
    const wasOn = serviceOn;
    if (!toggling) serviceOn = o.service === "on";
    mode = o.mode;
    group = o.group;
    current = o.node;
    currentProvider = o.provider;
    currentDelay = o.delay;
    if (serviceOn && !wasOn) refreshProviders();
    return true;
  }

  function acceptProviders(list) {
    if (!Array.isArray(list) || !list.every(p => p && typeof p.name === "string"
        && Number.isInteger(p.nodes) && p.nodes >= 0)) return false;
    providers = list;
    const has = name => list.some(p => p.name === name);
    if (!has(provider)) provider = has(currentProvider) ? currentProvider : (list[0]?.name ?? "");
    return true;
  }

  function acceptNodes(list, requested) {
    if (!serviceOn || requested !== provider || requested !== nodesWantedProvider
        || !Array.isArray(list) || !list.every(n => n
        && typeof n.name === "string" && typeof n.alive === "boolean"
        && Number.isInteger(n.delay) && n.delay >= 0)) return false;
    nodes = list;
    return true;
  }

  function acceptTraffic(o) {
    if (!o || !finiteNonnegative(o.up) || !finiteNonnegative(o.down)
        || (o.upTotal !== undefined && !finiteNonnegative(o.upTotal))
        || (o.downTotal !== undefined && !finiteNonnegative(o.downTotal))) return false;
    up = o.up;
    down = o.down;
    if (o.upTotal !== undefined) upTotal = o.upTotal;
    if (o.downTotal !== undefined) downTotal = o.downTotal;
    return true;
  }

  function finishPing(o, startFailure) {
    if (startFailure) error = "could not start ping";
    else if (o?.ok !== true || !Number.isInteger(o.alive) || o.alive < 0)
      error = typeof o?.error === "string" && o.error !== "" ? o.error : "bad ping reply";
    else error = "";
    refreshNodes();
    refreshStatus();
    pinging = false;
  }

  function finishUpdate(o, startFailure) {
    if (startFailure) error = "could not start update";
    else if (o?.ok !== true) error = typeof o?.error === "string" && o.error !== ""
      ? o.error : "update failed";
    else error = "";
    refresh();
    updating = false;
  }

  function finishSelect(o, success, startFailure) {
    if (startFailure) error = "could not start node selection";
    else if (!success || o?.ok !== true) error = typeof o?.error === "string" && o.error !== ""
      ? o.error : "node selection failed";
    else error = "";
    refreshStatus();
  }

  // ---- polling ----
  Timer {
    interval: root.popupOpen ? root.statusPollMs : root.idlePollMs
    running: true
    repeat: true
    onTriggered: root.refreshStatus()
  }

  Timer {
    id: trafficRestart
    interval: root.trafficRestartMs
    onTriggered: if (root.popupOpen) trafficProc.running = true
  }

  // ---- after a toggle ----
  Timer {
    id: toggleSettle
    interval: 1500                             // TUN + controller need a moment
    onTriggered: {
      root.toggling = false;
      root.refresh();
    }
  }

  // ---- processes ----
  Process {
    id: statusProc
    property bool started: false
    command: ["bash", root.script, "--status"]
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) started = false;
      if (root.statusQueued) { root.statusQueued = false; root.refreshStatus(); }
    }
    stdout: StdioCollector {
      onStreamFinished: root.acceptStatus(root.parse(text));
    }
  }

  Process {
    id: providersProc
    property bool started: false
    command: ["bash", root.script, "--providers"]
    onStarted: started = true
    stdout: StdioCollector {
      onStreamFinished: {
        const list = Reply.parseList(text, null);
        if (root.acceptProviders(list)) root.refreshNodes();
      }
    }
  }

  Process {
    id: nodesProc
    property string requestedProvider: ""
    property var reply: null
    property bool started: false
    onStarted: { started = true; reply = null; }
    onRunningChanged: {
      if (running) return;
      const requested = requestedProvider;
      if (started) { started = false; root.acceptNodes(reply, requested); }
      if (root.nodesWantedProvider !== requested) root.startNodes();
    }
    stdout: StdioCollector {
      onStreamFinished: nodesProc.reply = Reply.parseList(text, null);
    }
  }

  Process {
    id: selectProc
    property bool started: false
    property int exitCode: -1
    property var reply: null
    onStarted: { started = true; exitCode = -1; reply = null; }
    onExited: code => exitCode = code
    onRunningChanged: {
      if (running) return;
      const wasStarted = started;
      started = false;
      root.finishSelect(reply, wasStarted && exitCode === 0, !wasStarted);
    }
    stdout: StdioCollector {
      onStreamFinished: selectProc.reply = root.parse(text)
    }
  }

  Process {
    id: pingProc
    property var reply: null
    property bool started: false
    onStarted: { started = true; reply = null; }
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; root.finishPing(reply, false); }
      else root.finishPing(null, true);
    }
    stdout: StdioCollector {
      onStreamFinished: pingProc.reply = root.parse(text);
    }
  }

  Process {
    id: updateProc
    property var reply: null
    property bool started: false
    onStarted: { started = true; reply = null; }
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; root.finishUpdate(reply, false); }
      else root.finishUpdate(null, true);
    }
    stdout: StdioCollector {
      onStreamFinished: updateProc.reply = root.parse(text);
    }
  }

  Process {
    id: toggleProc
    property bool started: false
    property int exitCode: -1
    onStarted: { started = true; exitCode = -1; }
    onExited: code => exitCode = code
    onRunningChanged: {
      if (running) return;
      if (started) {
        started = false;
        if (exitCode === 0) toggleSettle.restart();
        else {
          root.serviceOn = root.toggleBefore;
          root.error = "could not toggle mihomo service";
          root.toggling = false;
          root.refreshStatus();
        }
      } else {
        root.serviceOn = root.toggleBefore;
        root.error = "could not start mihomo toggle";
        root.toggling = false;
        root.refreshStatus();
      }
    }
  }

  Process {
    id: pathProc
    stdout: StdioCollector {
      onStreamFinished: {
        const path = text.trim();
        if (path !== "") Quickshell.execDetached(["kitty", "-e", "nvim", path]);
      }
    }
  }

  Process {
    id: trafficProc
    command: ["bash", root.script, "--traffic"]
    property bool started: false
    onStarted: started = true
    stdout: SplitParser {
      onRead: line => {
        const o = root.parse(line);
        root.acceptTraffic(o);
      }
    }
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      if (root.popupOpen) trafficRestart.restart();
    }
    onExited: if (root.popupOpen) trafficRestart.restart()
  }
}
