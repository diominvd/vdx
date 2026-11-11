pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Dotfiles themes (~/.dotfiles/themes/<name>) for the Shell Manager: the list,
// the active one (.theme, gruvbox when absent) and switching through
// `install.py theme set`, which relinks every program's colours. The active
// theme's colours go to Theme.live, so the shell recolours without a reload.
Singleton {
  id: root

  readonly property string dotfiles: Quickshell.env("HOME") + "/.dotfiles"

  property var themes: []
  // name -> that theme's colours by role (the order of scripts/themes.sh)
  readonly property var roles: ["background0", "background1", "background2", "background3",
                                "foreground0", "foreground1", "foreground2", "red", "orange", "yellow",
                                "green", "aqua", "blue", "purple", "gray", "muted", "frame", "dim"]
  property var colors: ({})
  property string current: ""
  property bool busy: false
  property string applying: ""              // the theme being switched to
  property string listError: ""
  property string applyError: ""
  readonly property string error: applyError || listError
  // the curtain (components/ThemeCurtain) hides the switch: up while applying and
  // until the new colours are read, in the new theme's background
  property bool covering: false
  property color coverColor: Theme.background0

  function refresh() { if (!listProc.running) listProc.running = true; }

  function failApply(message) {
    applying = "";
    applyError = message || "could not start theme change";
    covering = false;
    coverSafety.stop();
    busy = false;
  }

  function finishApply(code, message) {
    applying = "";
    if (code !== 0) {
      applyError = message || "install.py theme set failed";
      covering = false;
      coverSafety.stop();
    }
    refresh();
    busy = false;
  }

  function acceptList(text) {
    const separator = "\n---\n";
    const splitAt = text.indexOf(separator);
    if (splitAt < 0 || splitAt !== text.lastIndexOf(separator)) {
      listError = "bad theme list reply";
      return false;
    }

    const listText = text.slice(0, splitAt);
    const active = text.slice(splitAt + separator.length).trim();
    if (!active || /[\r\n]/.test(active)) {
      listError = "bad theme list reply";
      return false;
    }

    const colors = Object.create(null);
    const names = [];
    for (const line of listText.split("\n")) {
      if (!line) continue;
      const fields = line.split(" ");
      const name = fields.shift();
      if (!name || /\s/.test(name) || fields.length !== root.roles.length
          || names.includes(name) || !fields.every(value => /^#[0-9a-fA-F]{6}$/.test(value))) {
        listError = "bad theme list reply";
        return false;
      }
      const roleColors = {};
      root.roles.forEach((role, i) => roleColors[role] = fields[i]);
      colors[name] = roleColors;
      names.push(name);
    }
    if (!names.includes(active)) {
      listError = "bad theme list reply";
      return false;
    }

    root.colors = colors;
    // The default theme leads the list; the rest keep their order.
    root.themes = names.filter(n => n === "default").concat(names.filter(n => n !== "default"));
    root.current = active;
    Theme.live = colors[active];
    root.listError = "";
    return true;
  }

  // ---- light and dark ----
  // a theme "<name>-light" is <name>'s light twin (themes/mktheme.py); the mode is the active one's
  readonly property bool light: current.endsWith("-light")
  readonly property var bases: themes.filter(n => !n.endsWith("-light"))
  function baseOf(name) { return name.replace(/-light$/, ""); }
  // a theme in a mode: its twin when there is one, else itself
  function variant(name, lightMode) {
    const n = lightMode ? baseOf(name) + "-light" : baseOf(name);
    return themes.includes(n) ? n : name;
  }
  // the themes to pick from in the active mode
  readonly property var inMode: bases.map(n => variant(n, light))
  function setLight(on) { if (on !== light) apply(variant(current, on)); }

  function apply(name) {
    if (busy || name === current) return;
    busy = true;
    applying = name;
    applyError = "";
    coverColor = colors[name]?.background0 ?? Theme.background0;
    covering = true;
    coverSafety.restart();
    setProc.command = ["python3", dotfiles + "/install.py", "theme", "set", name];
    setProc.running = true;
  }

  Component.onCompleted: refresh()

  // the screen is repainted a moment after the colours are read
  Timer {
    id: uncover
    interval: 150
    onTriggered: root.covering = false
  }

  // never stuck: a switch that hangs lifts the curtain anyway
  Timer {
    id: coverSafety
    interval: 15000
    onTriggered: root.covering = false
  }

  Process {
    id: listProc
    command: ["bash", Paths.scriptsDir + "/themes.sh"]
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.listError = "could not start theme list query";
    }
    stdout: StdioCollector {
      onStreamFinished: {
        root.acceptList(text);
        if (!root.busy) uncover.restart();
      }
    }
  }

  Process {
    id: setProc
    stderr: StdioCollector { id: setErr }
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.failApply("could not start theme change");
    }
    onExited: code => {
      root.finishApply(code, setErr.text.trim());
    }
  }
}
