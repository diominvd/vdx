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

  function preview(base, mode, custom) {
    const [f, o] = colours(mode, custom);
    const key = [base, f, o].join(" ");
    wantedKey = key;
    if (key === shapesKey || previewProc.running) return;
    previewProc.key = key;
    previewProc.command = ["python3", script, "preview", base].concat(f ? [f, o] : []);
    previewProc.running = true;
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
        const r = root.parse(text);
        if (!r.ok) { root.error = r.error; return; }
        root.cursors = r.cursors;
        root.base = r.base;
        root.size = r.size;
        root.mode = r.mode;
        root.fill = r.fill;
        root.outline = r.outline;
        follow.restart();
      }
    }
  }

  Process {
    id: previewProc
    property string key: ""
    stdout: StdioCollector {
      onStreamFinished: {
        const r = root.parse(text);
        root.shapes = r.ok ? r.shapes : [];
        root.shapesKey = previewProc.key;
        // the wanted one changed while this ran
        if (root.wantedKey !== root.shapesKey) {
          const [b, f, o] = root.wantedKey.split(" ");
          previewProc.key = root.wantedKey;
          previewProc.command = ["python3", root.script, "preview", b].concat(f ? [f, o] : []);
          previewProc.running = true;
        }
      }
    }
  }

  Process {
    id: actProc
    stdout: StdioCollector {
      onStreamFinished: {
        const r = root.parse(text);
        if (r.ok && actProc.command[2] === "install") {
          root.set();
          return;
        }
        root.busy = false;
        root.working = "";
        if (!r.ok) root.error = r.error;
        root.refresh();
      }
    }
  }
}
