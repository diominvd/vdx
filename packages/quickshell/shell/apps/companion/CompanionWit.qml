import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.chat
import "steer.js" as Steer

// Kimmy gets smarter while there is internet: now and then, instead of a canned line, it
// asks a free opencode model (the Chat module's, `opencode run`, the read-only "plan"
// agent in an empty folder, so it can touch nothing) for one short line about the moment.
// Only a few plain facts go out (the kind of program, the hour, its mood); never a window
// title, a file or text from the screen. One request at a time, at most one in a few
// minutes; a failure (no network) silences it for a quarter of an hour, and the canned
// lines go on as before.
Item {
  id: root

  readonly property bool enabled: ModuleSettings.get("companion", "smart", true)
  readonly property real gapMs: 4 * 60000
  readonly property real offlineMs: 15 * 60000
  readonly property int timeoutMs: 25000

  property double lastAt: 0
  property double offlineUntil: 0
  property var done: null
  readonly property bool busy: proc.running

  function canAsk() {
    const now = Date.now();
    return enabled && !proc.running && now >= offlineUntil && now - lastAt >= gapMs;
  }

  // `facts` is a plain sentence of the moment; `callback(text)` gets the cleaned line
  function ask(facts, callback) {
    if (!canAsk()) return false;
    lastAt = Date.now();
    done = callback;
    proc.reply = "";
    // stdin closed: with a pipe open, opencode waits to read the message from it
    proc.command = ["bash", "-c", 'mkdir -p "$1" && cd "$1" && shift && exec opencode run "$@" </dev/null', "_",
                    Quickshell.env("HOME") + "/.cache/dotfiles/kimmy",
                    "-m", ChatService.model, "--agent", "plan", "--format", "json"]
                   .concat(ChatService.keepServer ? [] : ["--standalone"]).concat([Steer.witPrompt(facts)]);
    proc.running = true;
    killer.restart();
    return true;
  }

  Process {
    id: proc
    property string reply: ""
    stdout: SplitParser {
      onRead: line => {
        let d;
        try { d = JSON.parse(line); } catch (e) { return; }
        if (d.type === "text" && d.part?.text) proc.reply += d.part.text;
      }
    }
    onExited: code => {
      killer.stop();
      const text = Steer.cleanLine(proc.reply);
      const cb = root.done;
      root.done = null;
      if (code !== 0 || text === "") { if (code !== 0) root.offlineUntil = Date.now() + root.offlineMs; return; }
      if (cb) cb(text);
    }
  }
  Timer { id: killer; interval: root.timeoutMs; onTriggered: proc.running = false }
}
