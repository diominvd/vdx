pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.bar
import qs.config
import "../../kit/reply.js" as Reply

// How the shell's own windows open (scripts/shellapps.py): floating or tiled;
// floating at the app's size, a preset share of the monitor or a custom one;
// centred, at the cursor or at a custom spot. A change rewrites the Hyprland
// rules and reloads — it shows the next time the window opens.
Singleton {
  id: root

  readonly property string script: Paths.scriptsDir + "/shellapps.py"

  // ---- the shell's apps: apps/apps.json, the one registry (the Shell ----
  // Manager, the launcher, scripts/shellapps.py) ----
  // id, label, icon, about; bind — the Hyprland bind that opens it; ipc +
  // open — `qs ipc call <ipc> <open>`; window — {id, title, width, height}
  // when it is a window of its own; settings — its options page (values in
  // ModuleSettings under `id`); module — its bar module (BarLayout id),
  // moduleSettings — that module's options page; desktop — the id of its
  // .desktop file when one is installed (the launcher then lists it once);
  // page — a Shell Manager page of its own holds its options (not listed in Apps)
  readonly property var entries: {
    try { return JSON.parse(registry.text()); } catch (e) { return []; }
  }

  // an app whose bar module's components are all off (BarLayout.notInstalled):
  // greyed in Shell apps, out of the launcher
  function installed(entry) { return !entry?.module || BarLayout.installed(entry.module); }

  function run(entry) { ShellIpc.call(entry.ipc, entry.open); }

  FileView {
    id: registry
    path: Quickshell.shellPath("apps/apps.json")
    blockLoading: true
  }

  // ---- state ----
  property var windows: []                  // [{id, title, icon, ipc, width, height, settings}]
  property var presets: ({})                // name -> [share of width, of height]
  property int minWidth: 480
  property int minHeight: 360
  property var spots: ({})                  // spot -> [x, y] as 0 / 0.5 / 1
  property int gap: 12                      // a spot's distance from the edges
  property int top: 46                      // … and from the top, under the bar
  property bool busy: false
  property string busyApp: ""
  property string error: ""
  property string errorApp: ""

  // ---- the monitor the preview draws (the first one) ----
  readonly property real screenW: Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920
  readonly property real screenH: Quickshell.screens.length > 0 ? Quickshell.screens[0].height : 1080

  // the window's size in pixels for some settings
  function sizeOf(app, s) {
    if (s.size === "preset") {
      const p = presets[s.preset] ?? [0.65, 0.7];
      return [Math.round(screenW * p[0]), Math.round(screenH * p[1])];
    }
    return s.size === "custom" ? [s.width, s.height] : [app.width, app.height];
  }

  // a position in words
  function placeName(s) {
    if (s.position === "cursor") return "at the cursor";
    if (s.position === "custom") return "at " + s.x + ", " + s.y;
    return s.position === "center" ? "centred" : s.position.replace("-", " ");
  }

  function refresh() { if (!listProc.running) listProc.running = true; }

  function finite(value) { return typeof value === "number" && isFinite(value); }

  function object(value) { return value !== null && typeof value === "object" && !Array.isArray(value); }

  function pairs(value) {
    return object(value) && Object.keys(value).every(key => Array.isArray(value[key])
      && value[key].length === 2 && finite(value[key][0]) && finite(value[key][1]));
  }

  function validSettings(s, presets, spots, minW, minH) {
    if (!object(s) || !["floating", "tiled"].includes(s.mode)
        || !["default", "preset", "custom"].includes(s.size)
        || !["small", "medium", "large"].includes(s.preset)
        || !Object.prototype.hasOwnProperty.call(presets, s.preset)
        || !(Object.prototype.hasOwnProperty.call(spots, s.position)
          || s.position === "cursor" || s.position === "custom")) return false;
    if (![s.width, s.height, s.x, s.y].every(value => finite(value) && Number.isInteger(value))) return false;
    if (s.size === "custom" && (s.width < minW || s.height < minH)) return false;
    if (s.position === "custom" && (s.x < 0 || s.y < 0)) return false;
    return true;
  }

  function acceptListReply(r) {
    if (r?.ok !== true) {
      if (errorApp === "")
        error = typeof r?.error === "string" && r.error !== "" ? r.error : "could not read shell apps";
      return false;
    }
    const minW = r.minWidth, minH = r.minHeight;
    if (!Array.isArray(r.apps) || !pairs(r.presets) || !pairs(r.spots)
        || !finite(minW) || minW <= 0 || !finite(minH) || minH <= 0
        || !finite(r.gap) || r.gap < 0 || !finite(r.top) || r.top < 0
        || !r.apps.every(app => app && typeof app.id === "string" && typeof app.title === "string"
          && typeof app.icon === "string" && typeof app.ipc === "string"
          && finite(app.width) && app.width > 0 && finite(app.height) && app.height > 0
          && validSettings(app.settings, r.presets, r.spots, minW, minH))) {
      if (errorApp === "") error = "bad shell apps list reply";
      return false;
    }
    windows = r.apps;
    presets = r.presets;
    minWidth = minW;
    minHeight = minH;
    spots = r.spots;
    gap = r.gap;
    top = r.top;
    if (errorApp === "") error = "";
    return true;
  }

  function failSet(message) {
    const failedApp = busyApp;
    errorApp = failedApp;
    busyApp = "";
    error = typeof message === "string" && message !== "" ? message : "shell app action failed";
    busy = false;
    refresh();
  }

  function set(app, change) {
    if (busy) return;
    busy = true;
    busyApp = app.id;
    error = "";
    errorApp = "";
    setProc.command = ["python3", script, "set", app.id, JSON.stringify(change)];
    setProc.running = true;
  }

  function parse(text) {
    return Reply.parse(text, "shellapps.py");
  }

  Component.onCompleted: refresh()

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
      if (root.errorApp === "") root.error = "could not start shell apps list query";
    }
  }

  Process {
    id: setProc
    stdout: StdioCollector {
      onStreamFinished: {
        const r = root.parse(text);
        if (r?.ok !== true) {
          root.failSet(typeof r?.error === "string" && r.error !== "" ? r.error : "shell app action failed");
          return;
        }
        root.busyApp = "";
        root.error = "";
        root.errorApp = "";
        root.busy = false;
        root.refresh();
      }
    }
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.failSet("could not start shell app action");
    }
  }
}
