pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../../kit/reply.js" as Reply

// The cursor for the Shell Manager (scripts/cursors.py): the list (curated
// themes and whatever is installed), previews of the main shapes, installing
// into ~/.local/share/icons and applying a theme with a size and a colour —
// its own (original), the active theme's (text colour body, background
// outline; redone whenever the theme changes) or a custom one. Applied at
// once in Hyprland and GTK, and again at every Hyprland start (`restore`).
Singleton {
  id: root

  readonly property string script: Paths.scriptsDir + "/cursors.py"

  // ---- state ----
  property var cursors: []                  // [{id, name, installed}]
  property string base: ""                  // the theme in use (before tinting)
  property int size: 24
  property string mode: "original"          // original | theme | custom
  property string fill: ""                  // rrggbb, tinted modes
  property string outline: ""
  property bool busy: false
  property string working: ""               // the theme being installed / applied
  property string error: ""

  // ---- preview ----
  property var shapes: []                   // [{name, path, width, height}] of `shapesKey`
  property string shapesKey: ""
  property string wantedKey: ""

  // the two colours of a mode: the theme's text over its background, or the
  // custom body with an outline that stands out from it
  function colours(mode, custom) {
    if (mode === "theme") return [hex(Theme.foreground0), hex(Theme.background0)];
    if (mode === "custom") {
      const c = Qt.color("#" + custom);
      const light = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b > 0.5;
      return [custom.toLowerCase(), hex(light ? Theme.background0 : Theme.foreground0)];
    }
    return ["", ""];
  }

  function hex(color) {
    const channel = value => Math.round(value * 255).toString(16).padStart(2, "0");
    return channel(color.r) + channel(color.g) + channel(color.b);
  }

  function refresh() { if (!listProc.running) listProc.running = true; }

  function replyError(r, fallback) {
    return typeof r?.error === "string" && r.error.trim() !== "" ? r.error : fallback;
  }

  function acceptListReply(r) {
    if (r?.ok !== true) { error = replyError(r, "could not read cursor list"); return false; }
    if (typeof r.base !== "string" || typeof r.size !== "number" || !Number.isInteger(r.size)
        || r.size < 12 || r.size > 96
        || !["original", "theme", "custom"].includes(r.mode)
        || typeof r.fill !== "string" || typeof r.outline !== "string"
        || !Array.isArray(r.cursors)
        || !r.cursors.every(cursor => cursor && typeof cursor.id === "string"
          && typeof cursor.name === "string" && typeof cursor.installed === "boolean")) {
      error = "bad cursor list reply";
      return false;
    }
    base = r.base;
    size = r.size;
    mode = r.mode;
    fill = r.fill;
    outline = r.outline;
    cursors = r.cursors;
    error = "";
    follow.restart();
    return true;
  }

  function acceptPreviewReply(key, r) {
    if (key !== wantedKey) return false;
    if (r?.ok !== true) { error = replyError(r, "could not read cursor preview"); return false; }
    if (!Array.isArray(r.shapes) || !r.shapes.every(shape => shape
        && typeof shape.name === "string" && typeof shape.path === "string"
        && typeof shape.width === "number" && isFinite(shape.width) && shape.width > 0
        && typeof shape.height === "number" && isFinite(shape.height) && shape.height > 0)) {
      error = "bad cursor preview reply";
      return false;
    }
    shapes = r.shapes;
    shapesKey = key;
    error = "";
    return true;
  }

  function startWantedPreview() {
    if (wantedKey === "" || wantedKey === shapesKey || previewProc.running) return;
    const [base, fill, outline] = JSON.parse(wantedKey);
    previewProc.key = wantedKey;
    previewProc.command = ["python3", script, "preview", base].concat(fill ? [fill, outline] : []);
    previewProc.running = true;
  }

  function preview(base, mode, custom) {
    const [f, o] = colours(mode, custom);
    const key = JSON.stringify([base, f, o]);
    wantedKey = key;
    if (key === shapesKey) return;
    startWantedPreview();
  }

  function apply(cursor, size, mode, custom) {
    if (busy) return;
    busy = true;
    working = cursor.name;
    error = "";
    pending = { base: cursor.name, size: size, mode: mode, custom: custom };
    if (cursor.installed) set();
    else run(["install", cursor.name]);
  }

  function setSize(size) {
    if (size !== root.size && base !== "")
      apply({ name: base, installed: true }, size, mode, mode === "custom" ? fill : "");
  }

  property var pending: null

  function set() {
    const p = pending;
    const [f, o] = colours(p.mode, p.custom);
    run(["set", p.base, String(p.size), p.mode].concat(f ? [f, o] : []));
  }

  function run(args) {
    actProc.command = ["python3", script].concat(args);
    actProc.running = true;
  }

  function failAction(message) {
    working = "";
    pending = null;
    error = typeof message === "string" && message.trim() !== "" ? message : "cursor action failed";
    busy = false;
  }

  function acceptActionReply(r, action) {
    if (r?.ok !== true) { failAction(replyError(r, "cursor action failed")); return false; }
    if (action === "install") {
      if (!pending || typeof r.name !== "string" || r.name !== pending.base) {
        failAction("bad cursor install reply");
        return false;
      }
      set();
      return true;
    }
    if (action !== "set") { failAction("bad cursor action reply"); return false; }
    if (!pending) { failAction("missing cursor action"); return false; }
    working = "";
    pending = null;
    error = "";
    busy = false;
    refresh();
    return true;
  }

  function parse(text) {
    return Reply.parse(text, "cursors.py");
  }

  // a theme-coloured cursor follows the theme
  readonly property string themeColours: hex(Theme.foreground0) + hex(Theme.background0)
  onThemeColoursChanged: follow.restart()
  Timer {
    id: follow
    interval: 400
    onTriggered: {
      if (root.mode !== "theme" || root.base === "" || root.busy) return;
      if (root.fill + root.outline === root.themeColours) return;
      root.apply({ name: root.base, installed: true }, root.size, "theme", "");
    }
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
      root.error = "could not start cursor list query";
    }
  }

  Process {
    id: previewProc
    property string key: ""
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      if (root.wantedKey !== key) root.startWantedPreview();
      else root.error = "could not start cursor preview";
    }
    stdout: StdioCollector {
      onStreamFinished: {
        const key = previewProc.key;
        root.acceptPreviewReply(key, root.parse(text));
        if (root.wantedKey !== key) root.startWantedPreview();
      }
    }
  }

  Process {
    id: actProc
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.failAction("could not start cursor action");
    }
    stdout: StdioCollector {
      onStreamFinished: {
        const r = root.parse(text);
        root.acceptActionReply(r, actProc.command[2]);
      }
    }
  }
}
