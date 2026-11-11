pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.apps.auth
import qs.config
import "../../kit/reply.js" as Reply

// The cleaner's state (scripts/cleaner.py), shared by its window and its bar
// module. Basic: categories with their size, a pick per category (the safe
// ones picked at first); cleaning empties the picked user ones at once and
// hands the system ones, with their steps in words, to RootService: the
// shell's panel shows them, asks to confirm (and the password the first
// time). AI: Claude's suggestions from a summary of ~, picked ones go to the
// Trash. Options: Shell Manager › Shell apps › Cleaner (ModuleSettings
// "cleaner").
Singleton {
  id: root

  readonly property string script: Paths.scriptsDir + "/cleaner.py"

  // ---- options ----
  function opt(key, fallback) { return ModuleSettings.get("cleaner", key, fallback); }
  readonly property bool confirm: opt("confirm", true)
  readonly property bool aiOn: opt("ai", true)
  readonly property string model: opt("model", "haiku")

  // ---- basic ----
  property var categories: []               // [{id, label, hint, size, root, safe, command}]
  property real total: 0
  property var picked: ({})                 // id -> bool
  property bool scanning: false
  property real scannedAt: 0                // ms; 0: never

  readonly property var pickedUser: categories.filter(c => !c.root && picked[c.id])
  readonly property var pickedRoot: categories.filter(c => c.root && picked[c.id])
  readonly property real pickedSize: pickedUser.concat(pickedRoot).reduce((s, c) => s + c.size, 0)
  readonly property real safeSize: categories.filter(c => !c.root && c.safe).reduce((s, c) => s + c.size, 0)

  function pick(id, on) {
    const p = Object.assign({}, picked);
    p[id] = on;
    picked = p;
  }

  // ---- ai ----
  property var suggestions: []              // [{path, size, days, kind, why, risk}]
  property var aiPicked: ({})               // path -> bool
  property bool analyzing: false
  readonly property var aiChosen: suggestions.filter(s => aiPicked[s.path])
  readonly property real aiSize: aiChosen.reduce((s, x) => s + x.size, 0)

  function aiPick(path, on) {
    const p = Object.assign({}, aiPicked);
    p[path] = on;
    aiPicked = p;
  }

  // ---- actions ----
  property bool busy: false
  property string status: ""                // "" | ok | error
  property string message: ""               // what the last action did, or its error

  property bool systemScanPending: false

  function scan(systemSnapshot) {
    const forSystem = systemSnapshot === true;
    if (scanProc.running || !scanProc.responseReceived) {
      if (forSystem) systemScanPending = true;
      return;
    }
    scanning = true;
    scanProc.afterSystemSnapshot = forSystem;
    scanProc.responseReceived = false;
    scanProc.processStopped = false;
    scanProc.running = true;
  }

  function scanStopped() {
    if (systemScanPending && afterSystem && scanProc.processStopped && scanProc.responseReceived
        && !scanProc.running) {
      systemScanPending = false;
      scan(true);
    }
  }

  function finite(value) { return typeof value === "number" && isFinite(value); }

  function record(value) { return value !== null && typeof value === "object" && !Array.isArray(value); }

  function replyError(r, fallback) {
    return typeof r?.error === "string" && r.error !== "" ? r.error : fallback;
  }

  function failScan(text, systemSnapshot) {
    if (systemSnapshot) {
      afterSystem = false;
      systemScanPending = false;
      pendingRoot = [];
      planIds = [];
      planSize = 0;
    }
    done(false, text);
    scanning = false;
    if (systemSnapshot) busy = false;
  }

  function acceptScan(r, systemSnapshot) {
    if (r?.ok !== true) {
      failScan(replyError(r, "could not read cleanup categories"), systemSnapshot);
      return false;
    }
    if (!Array.isArray(r.categories) || !r.categories.every(c => record(c)
        && typeof c.id === "string" && typeof c.label === "string" && typeof c.hint === "string"
        && finite(c.size) && c.size >= 0 && typeof c.root === "boolean" && typeof c.safe === "boolean"
        && (c.command === undefined || typeof c.command === "string"))
        || !finite(r.total) || r.total < 0) {
      failScan("bad cleanup category reply", systemSnapshot);
      return false;
    }
    const first = categories.length === 0;
    categories = r.categories;
    total = r.total;
    scannedAt = Date.now();
    if (first) {
      const p = {};
      for (const c of r.categories) p[c.id] = c.safe && c.size > 0;
      picked = p;
    }
    if (systemSnapshot) {
      const ids = planIds.slice();
      const size = planSize;
      const left = r.categories.filter(c => ids.includes(c.id)).reduce((sum, c) => sum + c.size, 0);
      afterSystem = false;
      systemScanPending = false;
      pendingRoot = [];
      planIds = [];
      planSize = 0;
      done(true, "Freed " + Format.shortSize(Math.max(0, size - left)) + " from the system");
      scanning = false;
      busy = false;
    } else {
      scanning = false;
    }
    return true;
  }

  // a scan older than a minute is redone (the module's popup, the window)
  function freshen() { if (Date.now() - scannedAt > 60000) scan(); }

  function run(args) {
    if (busy) return;
    busy = true;
    status = "";
    actProc.replyReady = false;
    actProc.command = ["python3", script].concat(args);
    actProc.running = true;
  }

  // the picked categories: user ones here, system ones through pkexec
  function clean(ids) {
    if (busy) return;
    const list = ids ?? pickedUser.concat(pickedRoot).map(c => c.id);
    const user = list.filter(id => !(categories.find(c => c.id === id)?.root));
    const sys = list.filter(id => categories.find(c => c.id === id)?.root);
    pendingRoot = sys;
    if (user.length > 0) run(["clean"].concat(user));
    else if (sys.length > 0) plan(sys);
  }
  property var pendingRoot: []

  // the system part: its plan, then RootService runs it after a confirmation
  property var planIds: []
  property real planSize: 0
  function plan(ids, chained) {
    if (busy && !chained) return;
    const requestIds = ids.slice();
    pendingRoot = [];
    planIds = requestIds;
    planSize = 0;
    if (!chained) busy = true;
    planProc.replyReady = false;
    planProc.command = ["python3", script, "plan"].concat(ids);
    planProc.running = true;
  }

  function failPlan(text) {
    pendingRoot = [];
    planIds = [];
    planSize = 0;
    afterSystem = false;
    done(false, text);
    busy = false;
  }

  function acceptPlan(r) {
    if (r?.ok !== true) {
      failPlan(replyError(r, "could not plan system cleanup"));
      return false;
    }
    if (!Array.isArray(r.steps) || !r.steps.every(step => record(step)
        && typeof step.label === "string" && typeof step.what === "string" && typeof step.command === "string")
        || typeof r.script !== "string" || r.script.trim() === ""
        || !finite(r.size) || r.size < 0) {
      failPlan("bad system cleanup plan reply");
      return false;
    }
    const steps = r.steps;
    const command = r.script;
    planSize = r.size;
    pendingRoot = [];
    if (!RootService.request("Cleaner", "Clean the system", steps, command, "cleaner")) {
      failPlan("another root action is waiting");
      return false;
    }
    return true;
  }

  function finishRoot(tag, ok, error) {
    if (tag !== "cleaner") return;
    if (!ok) {
      pendingRoot = [];
      planIds = [];
      planSize = 0;
      afterSystem = false;
      systemScanPending = false;
      done(false, error === "cancelled" ? "System part cancelled" : replyError({error}, "system cleanup failed"));
      scan();
      busy = false;
      return;
    }
    afterSystem = true;
    scan(true);
  }

  function failAction(text) {
    pendingRoot = [];
    done(false, text);
    busy = false;
  }

  function acceptAction(what, r, submittedPaths) {
    if (what !== "clean" && what !== "trash") {
      failAction("unknown cleanup action");
      return false;
    }
    if (r?.ok !== true) {
      failAction(replyError(r, "cleanup action failed"));
      return false;
    }
    if (!finite(r.freed) || r.freed < 0) {
      failAction("bad cleanup action reply");
      return false;
    }
    const nextRoot = pendingRoot.slice();
    pendingRoot = [];
    if (what === "clean" && nextRoot.length > 0) {
      done(true, "Freed " + Format.shortSize(r.freed) + " · now the system part");
      plan(nextRoot, true);
      return true;
    }
    if (what === "clean") done(true, "Freed " + Format.shortSize(r.freed));
    else if (what === "trash") {
      done(true, "Moved " + Format.shortSize(r.freed) + " to trash");
      const removed = submittedPaths || [];
      suggestions = suggestions.filter(s => !removed.includes(s.path));
      const remaining = Object.assign({}, aiPicked);
      for (const path of removed) delete remaining[path];
      aiPicked = remaining;
    }
    scan();
    busy = false;
    return true;
  }

  function failAi(text) {
    done(false, text);
    analyzing = false;
  }

  function acceptAi(r) {
    if (r?.ok !== true) {
      failAi(replyError(r, "could not analyze cleanup suggestions"));
      return false;
    }
    if (!Array.isArray(r.suggestions) || !r.suggestions.every(s => record(s)
        && typeof s.path === "string" && s.path !== "" && typeof s.why === "string"
        && typeof s.kind === "string" && typeof s.risk === "string"
        && finite(s.size) && s.size >= 0 && finite(s.days))) {
      failAi("bad cleanup suggestion reply");
      return false;
    }
    suggestions = r.suggestions;
    const p = {};
    for (const s of r.suggestions) p[s.path] = s.risk === "low";
    aiPicked = p;
    if (r.suggestions.length === 0) done(true, "Nothing Claude would remove");
    analyzing = false;
    return true;
  }

  Process {
    id: planProc
    stdout: StdioCollector {
      onStreamFinished: {
        planProc.pendingReply = root.parse(text);
        planProc.replyReady = true;
        root.consumePlanReply();
      }
    }
    property bool started: false
    property bool processStopped: true
    property bool replyReady: false
    property var pendingReply: null
    onStarted: { started = true; processStopped = false; }
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; processStopped = true; root.consumePlanReply(); return; }
      root.failPlan("could not start cleanup plan");
    }
  }

  function consumePlanReply() {
    if (!planProc.processStopped || !planProc.replyReady) return;
    const reply = planProc.pendingReply;
    planProc.replyReady = false;
    acceptPlan(reply);
  }

  Connections {
    target: RootService
    function onFinished(tag, ok, error) {
      root.finishRoot(tag, ok, error);
    }
  }
  // the scan after a system clean tells how much went
  property bool afterSystem: false

  function cleanSafe() { clean(categories.filter(c => !c.root && c.safe && c.size > 0).map(c => c.id)); }

  function analyze() {
    if (analyzing || !aiOn) return;
    analyzing = true;
    status = "";
    aiProc.replyReady = false;
    aiProc.command = ["python3", script, "ai", model];
    aiProc.running = true;
  }

  function trashChosen() {
    if (busy || aiChosen.length === 0) return;
    run(["trash"].concat(aiChosen.map(s => s.path)));
  }

  function parse(text) {
    return Reply.parse(text, "cleaner.py");
  }

  Timer {
    id: statusReset
    interval: 6000
    onTriggered: { root.status = ""; root.message = ""; }
  }

  function done(ok, text) {
    status = ok ? "ok" : "error";
    message = text;
    statusReset.restart();
  }

  Process {
    id: scanProc
    property bool afterSystemSnapshot: false
    property bool responseReceived: true
    property bool processStopped: true
    command: ["python3", root.script, "scan"]
    stdout: StdioCollector {
      onStreamFinished: {
        const systemSnapshot = scanProc.afterSystemSnapshot;
        scanProc.responseReceived = true;
        root.acceptScan(root.parse(text), systemSnapshot);
        root.scanStopped();
      }
    }
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; processStopped = true; root.scanStopped(); return; }
      processStopped = true;
      responseReceived = true;
      root.failScan("could not start cleanup scan", afterSystemSnapshot);
      root.scanStopped();
    }
  }

  Process {
    id: actProc
    stdout: StdioCollector {
      onStreamFinished: {
        actProc.pendingReply = root.parse(text);
        actProc.replyReady = true;
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
      root.failAction("could not start cleanup action");
    }
  }

  function consumeActionReply() {
    if (!actProc.processStopped || !actProc.replyReady) return;
    const reply = actProc.pendingReply;
    const what = actProc.command[2];
    const submitted = what === "trash" ? actProc.command.slice(3) : [];
    actProc.replyReady = false;
    acceptAction(what, reply, submitted);
  }

  Process {
    id: aiProc
    stdout: StdioCollector {
      onStreamFinished: {
        aiProc.pendingReply = root.parse(text);
        aiProc.replyReady = true;
        root.consumeAiReply();
      }
    }
    property bool started: false
    property bool processStopped: true
    property bool replyReady: false
    property var pendingReply: null
    onStarted: { started = true; processStopped = false; }
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; processStopped = true; root.consumeAiReply(); return; }
      root.failAi("could not start cleanup analysis");
    }
  }

  function consumeAiReply() {
    if (!aiProc.processStopped || !aiProc.replyReady) return;
    const reply = aiProc.pendingReply;
    aiProc.replyReady = false;
    acceptAi(reply);
  }
}
