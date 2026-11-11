pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../../kit/reply.js" as Reply

// Clipboard history (scripts/clipboard.sh): a `wl-paste --watch` runs for the
// whole session and stores every new selection; the popup reads the list and
// calls copy / delete / clear / limit. The window reads the list when it opens.
Singleton {
  id: root

  // ---- history ----
  property var entries: []          // newest first: [{id, kind, preview, path, time}]
  property int limit: 100
  readonly property var limits: [25, 50, 100, 250, 500]
  property string error: ""
  property bool actionFailed: false
  signal copied(string id)

  property var actionQueue: []
  property var activeAction: null
  property var actionReply: null
  property bool listQueued: false

  function refresh() {
    if (listProc.running) { listQueued = true; return; }
    listProc.running = true;
  }

  function copy(id) { enqueueAction("copy", [String(id)]); }
  function remove(id) { enqueueAction("delete", [String(id)]); }
  function clear() { enqueueAction("clear", []); }
  function setLimit(n) {
    if (!Number.isInteger(n) || n < 1 || n > 10000) {
      error = "limit must be from 1 to 10000";
      actionFailed = true;
      return;
    }
    enqueueAction("limit", [String(n)], n);
  }

  function enqueueAction(action, args, newLimit) {
    error = "";
    actionFailed = false;
    actionQueue = actionQueue.concat([{action, args: args.slice(), newLimit}]);
    startNextAction();
  }

  function startNextAction() {
    if (activeAction || actionProc.running || actionQueue.length === 0) return;
    activeAction = actionQueue[0];
    actionQueue = actionQueue.slice(1);
    actionReply = null;
    actionProc.command = ["bash", Paths.scriptsDir + "/clipboard.sh", activeAction.action]
      .concat(activeAction.args);
    actionProc.running = true;
  }

  function parse(text) { return Reply.parse(text, "clipboard.sh"); }
  function parseList(text) { return Reply.parseList(text, null); }

  function validList(list) {
    return Array.isArray(list) && list.every(e => e && typeof e.id === "string"
      && (e.kind === "text" || e.kind === "image") && typeof e.preview === "string"
      && typeof e.path === "string" && typeof e.time === "number" && isFinite(e.time));
  }

  function acceptList(list) {
    if (!Array.isArray(list) || !validList(list)) {
      if (!actionFailed) error = "bad clipboard history reply";
      return false;
    }
    entries = list;
    if (!actionFailed) error = "";
    return true;
  }

  function actionError(reply) {
    return typeof reply?.error === "string" && reply.error.trim() !== ""
      ? reply.error : "clipboard action failed";
  }

  function finishAction(reply, startFailure, processSuccess) {
    const action = activeAction;
    activeAction = null;
    actionReply = null;
    if (!action) { startNextAction(); return; }

    const ok = !startFailure && processSuccess !== false && reply?.ok === true;
    if (ok) {
      error = "";
      actionFailed = false;
      if (action.action === "limit") limit = action.newLimit;
    } else {
      error = startFailure ? "could not start clipboard action" : actionError(reply);
      actionFailed = true;
    }

    refresh();
    startNextAction();
    if (ok && action.action === "copy") copied(action.args[0]);
  }

  // every new selection lands in the history; a line after each store
  // refreshes the list. The watcher dies with the shell (pdeathsig), so a
  // restart never leaves an old one storing everything twice.
  Process {
    id: watcher
    command: ["setpriv", "--pdeathsig", "TERM", "bash", Paths.scriptsDir + "/clipboard.sh", "watch"]
    running: true
    stdout: SplitParser { onRead: root.refresh() }
    onExited: restartTimer.start()
  }

  // the watcher must not stay down
  Timer {
    id: restartTimer
    interval: 2000
    onTriggered: watcher.running = true
  }

  // the saved limit
  FileView {
    path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/clipboard/limit"
    printErrors: false
    onLoaded: { const n = parseInt(text()); if (n > 0) root.limit = n; }
  }

  Process {
    id: listProc
    command: ["bash", Paths.scriptsDir + "/clipboard.sh", "list"]
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) {
        started = false;
        if (root.listQueued) { root.listQueued = false; root.refresh(); }
        return;
      }
      if (!root.actionFailed) root.error = "could not start clipboard history query";
      if (root.listQueued) { root.listQueued = false; root.refresh(); }
    }
    stdout: StdioCollector {
      onStreamFinished: root.acceptList(root.parseList(text));
    }
  }

  Process {
    id: actionProc
    property bool started: false
    property int exitCode: -1
    onStarted: { started = true; exitCode = -1; }
    onExited: code => exitCode = code
    onRunningChanged: {
      if (running) return;
      if (started) {
        started = false;
        root.finishAction(root.actionReply, false, exitCode === 0);
      } else root.finishAction(null, true);
    }
    stdout: StdioCollector {
      onStreamFinished: root.actionReply = root.parse(text);
    }
  }
}
