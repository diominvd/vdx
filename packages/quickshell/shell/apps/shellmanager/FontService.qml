pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../../kit/reply.js" as Reply

// The system monospace font for the Shell Manager (scripts/fonts.py): the list
// (curated Nerd Fonts and whatever monospace is installed), installing one into
// ~/.local/share/fonts and making it `monospace` everywhere. The shell follows
// through ShellSettings.font; a font installed after the shell started is
// unknown to it, so the shell restarts to pick it up.
Singleton {
  id: root

  readonly property string script: Paths.scriptsDir + "/fonts.py"
  readonly property string supervisor: Paths.scriptsDir + "/supervise.sh"

  // ---- state ----
  property var fonts: []                    // [{id, family, installed}]
  property string current: ""               // what fontconfig resolves `monospace` to
  property bool busy: false
  property string working: ""               // the family being installed / applied
  property string error: ""

  function refresh() { if (!listProc.running) listProc.running = true; }

  function apply(font) {
    if (busy || font.family === current) return;
    busy = true;
    working = font.family;
    error = "";
    run(font.installed ? ["set", font.family] : ["install", font.id]);
  }

  function run(args) {
    actProc.command = ["python3", script].concat(args);
    actProc.running = true;
  }

  function parse(text) {
    return Reply.parse(text, "fonts.py");
  }

  function acceptListReply(r) {
    if (r?.ok !== true) {
      error = typeof r?.error === "string" && r.error !== "" ? r.error : "could not read fonts";
      return false;
    }
    if (typeof r.current !== "string" || !Array.isArray(r.fonts)
        || !r.fonts.every(font => font && typeof font.id === "string"
          && typeof font.family === "string" && typeof font.installed === "boolean")) {
      error = "bad font list reply";
      return false;
    }
    current = r.current;
    fonts = r.fonts;
    error = "";
    return true;
  }

  function failAction(message) {
    busy = false;
    working = "";
    error = typeof message === "string" && message !== "" ? message : "font action failed";
  }

  // the running shell only knows the fonts it found at start
  // (also About › Restart, the launcher's Restart shell): a TERM ends the
  // supervisor of this one too, the new one comes with its own
  function restartShell() {
    Quickshell.execDetached(["bash", "-c",
      "sleep 0.3; kill " + Quickshell.processId + "; while kill -0 " + Quickshell.processId
      + " 2>/dev/null; do sleep 0.1; done; setsid -f \"$1\" >/dev/null 2>&1",
      "restart", root.supervisor]);
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
      root.error = "could not start font list query";
    }
  }

  Process {
    id: actProc
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.failAction("could not start font action");
    }
    stdout: StdioCollector {
      onStreamFinished: {
        const r = root.parse(text);
        if (r?.ok !== true) {
          root.failAction(r.error);
          return;
        }
        if (actProc.command[2] === "install") {
          if (typeof r.family !== "string" || r.family !== root.working) {
            root.failAction("bad font install reply");
            return;
          }
          root.run(["set", r.family]);
          return;
        }
        const family = root.working;
        root.busy = false;
        root.working = "";
        root.error = "";
        ShellSettings.set("font", family);
        if (!Qt.fontFamilies().includes(family)) root.restartShell();
        else root.refresh();
      }
    }
  }
}
