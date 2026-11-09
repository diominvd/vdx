pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.components
import qs.config
import qs.apps.capture
import qs.apps.shellmanager
import "../../kit/reply.js" as Reply

// Notification history on top of mako (scripts/notifications.sh). mako keeps
// only a short, untimed history, so this service records every notification it
// sees, with the time, in the shell's state dir. "Unseen" = arrived after the
// popup was last opened.
Singleton {
  id: root

  // ---- tuning ----
  readonly property int historyMax: 100  // kept in history
  readonly property string script: Paths.scriptsDir + "/notifications.sh"

  readonly property var items: state.items     // newest first: [{key, app, desktop, summary, body, urgency, category, time}]
  readonly property int unseen: items.filter(n => n.time > state.seenAt).length

  property real openedSeenAt: 0                // seenAt before the popup opened: marks fresh rows

  // the centre opened (from anywhere): the island's toasts close
  signal opened()

  function popupShown() {
    openedSeenAt = state.seenAt;
    state.seenAt = Date.now();
    root.opened();
  }

  // the island's last notice went away: the batch counts as seen (the rows stay)
  function markSeen() {
    state.seenAt = Date.now();
  }

  function clear() {
    state.items = [];
    state.seenAt = Date.now();
  }

  function isFresh(item) { return item.time > openedSeenAt; }

  // the open centre's rows count as read: their dots go
  function markRead() { openedSeenAt = Date.now(); }

  // one row dismissed from the history
  function remove(key) { state.items = state.items.filter(n => n.key !== key); }

  // The app's window, focused (restored first when minimized). Its class is the
  // desktop entry or the app's name, as the app's own windows name themselves:
  // "org.telegram.desktop" and "Telegram Desktop" both reduce to a letters-and-
  // digits key that matches the class. Older history rows have no desktop entry.
  // False when the app has no window open.
  // A click on a notification brings up its app: its window when one is open
  // (by class, or by a shell app's window title), else the shell app of that
  // name (apps.json: "Backup" → Backups) is opened. false: no app is known.
  function focusApp(item) {
    // Capture is the shell's own app: its notices open its library
    if ((item.app ?? "").toLowerCase() === "capture") {
      CaptureService.openLibrary();
      return true;
    }
    Hyprland.refreshToplevels();
    const key = s => (s ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
    const names = [item.desktop, item.app].map(key).filter(s => s !== "");
    const entry = shellApp(key(item.app), key);
    const title = key(entry?.window?.title);
    const win = Hyprland.toplevels.values.find(t => {
      const cls = key(Hypr.classOf(t));
      if (title !== "" && key(t.title) === title) return true;
      return cls !== "" && names.some(n => n === cls || cls.endsWith(n) || n.endsWith(cls));
    });
    if (win) {
      if (Hypr.minimized(win)) Hypr.call("RestoreWindow(\"" + Hypr.addr(win) + "\")");
      // the pointer stays where it is (FocusWindow: a plain focus warps it to the window)
      Hypr.call("FocusWindow(\"" + Hypr.addr(win) + "\")");
      return true;
    }
    if (!entry) return false;
    ShellAppsService.run(entry);
    return true;
  }

  // the shell app a notification's app name stands for: its id or label, the label in the plural
  function shellApp(name, key) {
    if (name === "") return null;
    return ShellAppsService.entries.find(e => e.ipc && (key(e.id) === name || key(e.label) === name || key(e.label) === name + "s")) ?? null;
  }

  // One row per notification: its mako id within one mako run (`epoch`; a
  // lower top id means mako restarted and numbering began again). A new id is
  // news. A row mako sends again with new text (replaces_id) is updated in
  // place and comes back as news. Any other known or cleared id is left alone,
  // so a cleared history stays clear. The first run on a fresh state only
  // notes where the ids are: what mako already holds is not news.
  // the colour of a notification: a warning (category "warning": an agent waiting for a
  // yes) yellow, a critical one red, the rest their app's
  function toneOf(n) {
    return n?.category === "warning" ? Theme.yellow : n?.urgency === "critical" ? Theme.red : Theme.appColour(n?.app);
  }

  function ingest(list) {
    const top = list.reduce((m, n) => Math.max(m, n.id), 0);
    if (!state.tracked) {
      state.lastId = top;
      state.tracked = true;
      return;
    }
    if (top < state.lastId) {
      state.lastId = 0;
      state.epoch += 1;
    }
    const now = Date.now();
    const rows = new Map(state.items.map(n => [n.key, n]));
    const news = [];
    for (const n of list) {
      const key = state.epoch + "|" + n.id;
      const row = rows.get(key);
      if (row ? row.summary === n.summary && row.body === n.body && row.urgency === n.urgency
              : n.id <= state.lastId) continue;
      news.push({ key: key, app: n.app, desktop: n.desktop, summary: n.summary, body: n.body,
                  urgency: n.urgency, category: n.category ?? "", time: now });
    }
    state.lastId = Math.max(state.lastId, top);
    if (news.length > 0)
      state.items = news.concat(state.items.filter(n => !news.some(f => f.key === n.key)))
                        .slice(0, root.historyMax);
  }

  function refresh() {
    if (!listProc.running) listProc.running = true;
  }

  // mako registers a notification a moment after the Notify call.
  Timer {
    id: refreshDelay
    interval: 300
    onTriggered: root.refresh()
  }

  Timer {
    id: saveDelay
    interval: 500
    onTriggered: stateFile.writeAdapter()
  }

  Process {
    id: listProc
    command: ["bash", root.script, "--list"]
    stdout: StdioCollector {
      onStreamFinished: {
        const o = Reply.parseList(text, null);
        if (o) root.ingest(o);
      }
    }
  }

  // Every Notify call on the session bus, whoever shows it.
  Process {
    id: monitorProc
    command: ["dbus-monitor", "--session", "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"]
    running: true
    stdout: SplitParser {
      onRead: line => { if (line.startsWith("method call")) refreshDelay.restart(); }
    }
    onExited: monitorRestart.start()
  }

  Timer {
    id: monitorRestart
    interval: 2000
    onTriggered: monitorProc.running = true
  }

  FileView {
    id: stateFile
    path: Quickshell.statePath("notifications.json")
    printErrors: false
    onAdapterUpdated: saveDelay.restart()
    onLoaded: root.refresh()
    onLoadFailed: {
      writeAdapter();
      root.refresh();
    }

    JsonAdapter {
      id: state
      property var items: []
      property real seenAt: 0
      property int lastId: 0
      property int epoch: 0                   // mako runs so far: its ids restart each run
      property bool tracked: false            // lastId is known
    }
  }
}
