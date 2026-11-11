pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.windows

// Hyprland's binds as they are in effect (`hyprctl binds -j`), each with the
// tab and section it shows in (`places`): the group of its description
// "Group · What it does" (hypr/components/keybinds.lua) decides it; binds
// without one go to Desktop. A run of numbered binds (workspaces 1–10) folds
// into one row. The window mode's own keys (modeHints) are on the Mode tab:
// its whole scheme, touchpad gestures and arrow fallbacks included — those
// are no binds to hyprctl.
Singleton {
  id: root

  // ---- state ----
  property var binds: []                    // [{tab, section, what, keys: [string]}]
  property string error: ""
  property bool open: false                 // the keybinds (Keybinds.qml): Super+B

  // `qs -c shell ipc call keybinds toggle`
  IpcHandler {
    target: "keybinds"
    function toggle(): void { root.open = !root.open; }
    function open(): void { root.open = true; }
    function close(): void { root.open = false; }
  }

  function refresh() { if (!proc.running) proc.running = true; }

  // the window mode decides the wheel's and the touchpad's binds
  property string mode: "tiling"
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/dotfiles/window-mode"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { root.mode = text().trim() || "tiling"; root.refresh(); }
  }

  // ---- tabs ----
  readonly property var tabs: [
    { value: "mode", label: "Mode", icon: "columns" },
    { value: "windows", label: "Windows", icon: "app-window" },
    { value: "desktop", label: "Desktop", icon: "grid" },
    { value: "media", label: "Media", icon: "music" }
  ]

  // group -> [tab, section], in the order the tabs show them
  readonly property var places: ({
    "Focus": ["windows", "Focus"],
    "Move": ["windows", "Move & resize"],
    "Resize": ["windows", "Move & resize"],
    "Windows": ["windows", "Window"],
    "Workspaces": ["desktop", "Workspaces"],
    "Apps": ["desktop", "Apps"],
    "Shell": ["desktop", "Shell"],
    "Capture": ["desktop", "Capture"],
    "Media": ["media", "Media"]
  })
  // the window modes' own groups: their binds are the Mode tab's hints
  readonly property var modeGroups: ["Scrolling", "Floating", "Tiling"]

  // modmask bits, in the order they are written
  readonly property var mods: [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]]
  readonly property var keyNames: ({
    "mouse:272": "LMB", "mouse:273": "RMB", "mouse:274": "MMB", "mouse_down": "Wheel ↓", "mouse_up": "Wheel ↑",
    "comma": ",", "period": ".", "left": "←", "right": "→", "up": "↑", "down": "↓",
    "space": "Space", "return": "Enter", "escape": "Esc", "tab": "Tab"
  })

  function keysOf(b) {
    const keys = mods.filter(m => b.modmask & m[0]).map(m => m[1]);
    const name = b.key.toLowerCase();
    const k = Object.prototype.hasOwnProperty.call(keyNames, name)
      ? keyNames[name] : (b.key.length === 1 ? b.key.toUpperCase() : b.key);
    return keys.concat([k]);
  }

  // the keys of the bind named `what` ("Keybinds"), [] when none
  function keysFor(what) {
    const b = binds.find(x => x.what === what);
    return b ? b.keys : [];
  }

  function build(list) {
    const byGroup = Object.create(null);
    for (const b of list) {
      const desc = b.has_description ? b.description : "";
      const cut = desc.indexOf(" · ");
      const group = cut > 0 ? desc.slice(0, cut) : "Other";
      if (modeGroups.includes(group)) continue;
      const what = cut > 0 ? desc.slice(cut + 3) : desc || (b.dispatcher + " " + b.arg).trim();
      if (!byGroup[group]) byGroup[group] = [];
      byGroup[group].push({ what: what, keys: keysOf(b) });
    }
    const order = Object.keys(places).concat(Object.keys(byGroup).filter(g => !Object.prototype.hasOwnProperty.call(places, g)));
    const out = [];
    for (const g of order) {
      if (!byGroup[g]) continue;
      const place = Object.prototype.hasOwnProperty.call(places, g) ? places[g] : ["desktop", g];
      for (const b of fold(byGroup[g])) out.push({ tab: place[0], section: place[1], what: b.what, keys: b.keys });
    }
    return out.concat(modeHints());
  }

  // the window mode's keys (hypr/components/modes/<mode>.lua, windowmode.lua);
  // the wheel and the arrows are the Shell Manager › Windows option's
  function modeHints() {
    const wheel = WindowsService.opts.scrollKeys !== "arrows";
    const arrows = WindowsService.opts.scrollKeys !== "wheel";
    const rows = [];
    const add = (section, what, keys) => rows.push({ tab: "mode", section: section, what: what, keys: keys });
    const scroll = "Scroll & workspaces";
    const workspaces = () => {
      if (wheel) add(scroll, "Workspace above / below", ["Super", "Wheel ↑↓"]);
      if (arrows) add(scroll, "Workspace above / below", ["Super", "↑ ↓"]);
    };
    if (mode === "scrolling") {
      add("Focus", "Focus column left / right", ["Super", "H / L"]);
      add("Focus", "Focus window up / down in column", ["Super", "K / J"]);
      add("Move & resize", "Move window", ["Super", "Shift", "H / J / K / L"]);
      add("Move & resize", "Wide / half column", ["Super", "W"]);
      add(scroll, "Scroll columns", ["3 fingers", "← →"]);
      if (wheel) add(scroll, "Scroll columns", ["Super", "Wheel ↑↓"]);
      if (arrows) add(scroll, "Scroll columns", ["Super", "← →"]);
      add(scroll, "Workspace above / below", ["3 fingers", "↑ ↓"]);
      if (wheel) add(scroll, "Workspace above / below", ["Super", "Shift", "Wheel ↑↓"]);
      if (arrows) add(scroll, "Workspace above / below", ["Super", "Shift", "↑ ↓"]);
      add("Mouse", "Drag window", ["Super", "LMB"]);
      add("Mouse", "Resize column", ["Super", "RMB"]);
    } else if (mode === "floating") {
      add("Snap & size", "Snap left / right half", ["Super", "H / L"]);
      add("Snap & size", "Maximize / back", ["Super", "K"]);
      add("Snap & size", "Minimize", ["Super", "J"]);
      add("Move & resize", "Move window", ["Super", "Shift", "H / J / K / L"]);
      workspaces();
      add("Mouse", "Drag window", ["Super", "LMB"]);
      add("Mouse", "Resize window", ["Super", "RMB"]);
    } else {
      add("Focus", "Focus", ["Super", "H / J / K / L"]);
      add("Move & resize", "Move window", ["Super", "Shift", "H / J / K / L"]);
      workspaces();
      add("Mouse", "Drag window", ["Super", "LMB"]);
      add("Mouse", "Resize window", ["Super", "RMB"]);
    }
    return rows;
  }

  // "Go to 1" … "Go to 10" on Super+1 … Super+0 → "Go to 1–10" on Super, 1…0
  function fold(binds) {
    const out = [];
    const runs = Object.create(null);
    for (const b of binds) {
      const m = b.what.match(/^(.*?)(\d+)$/);
      const last = b.keys[b.keys.length - 1];
      if (m && /^\d$/.test(last)) {
        const id = m[1] + "|" + b.keys.slice(0, -1).join("+");
        if (!runs[id]) {
          runs[id] = { prefix: m[1], mods: b.keys.slice(0, -1), from: +m[2], to: +m[2], first: last, lastKey: last };
          out.push(runs[id]);
        } else {
          runs[id].to = +m[2];
          runs[id].lastKey = last;
        }
      } else {
        out.push(b);
      }
    }
    return out.map(r => r.prefix === undefined ? r
      : { what: r.prefix + r.from + (r.to !== r.from ? "–" + r.to : ""),
          keys: r.mods.concat([r.first + (r.lastKey !== r.first ? "…" + r.lastKey : "")]) });
  }

  Component.onCompleted: refresh()

  Process {
    id: proc
    command: ["hyprctl", "binds", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.binds = root.build(JSON.parse(text));
          root.error = "";
        } catch (e) {
          root.error = "hyprctl binds: " + e;
        }
      }
    }
  }
}
