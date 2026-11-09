pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.bar
import qs.config
import "../../kit/reply.js" as Reply

// MPD player shared by the music module's sources (scripts/music.sh): the local
// files, the Yandex Music likes and the radio. One state stream, the playback
// commands and the queue. Each source adds its own data on top (YandexService,
// RadioService).
Singleton {
  id: root

  // ---- tuning ----
  readonly property int restartMs: 5000
  readonly property string script: Paths.scriptsDir + "/music.sh"

  // MPD is the music module's source for files, likes and radio (its components
  // `mpd`, `yandex-music`, `radio`: each requires mpd): with them off (`./install.py
  // components`) nothing polls it
  readonly property bool needed: BarLayout.installed("files")
  onNeededChanged: {
    if (needed) listenProc.running = true;
    else {
      listenRestart.stop();
      listenProc.running = false;
      player = ({});
    }
  }
  Component.onCompleted: if (needed) listenProc.running = true;

  property var player: ({})                    // see `music.sh --status`
  property var queue: []                       // [{pos, artist, title}]: MPD's queue (`music.sh --queue`)

  readonly property bool service: player.service ?? false
  readonly property bool playing: player.state === "playing"
  readonly property bool paused: player.state === "paused"
  readonly property bool stopped: !service || player.state === "stopped" || source === ""
  readonly property string source: player.source ?? ""     // likes | radio | files | ""
  readonly property string file: player.file ?? ""
  readonly property real duration: player.duration ?? 0
  property real elapsed: 0                     // ticks locally between MPD events

  property var busy: null                      // what is being started, for its spinner
  property string error: ""

  // ---- playback ----
  function control(args) {
    Quickshell.execDetached(["bash", root.script].concat(args));
    settle.restart();
  }

  // the state is read again once a command has had time to land: the stream of events
  // can lag (MPD coming up is only noticed by its 2 s poll), and a popup waits on it
  function refresh() { if (needed && !statusProc.running) run(statusProc, ["--status"]); }

  function toggle() { control(["--toggle"]); }
  // the popup's switch: MPD itself on (playing what it kept, else the likes) or off
  function setOn(on) {
    if (on) load("on", ["--on"]);
    else control(["--off"]);
  }
  function pause() { control(["--pause"]); }
  function stop() { control(["--stop"]); }
  function next() { control(["--next"]); }
  function prev() { control(["--prev"]); }
  function play(pos) { control(pos === undefined ? ["--play"] : ["--play", String(pos)]); }
  function toggleRandom() { control(["--random"]); }
  function cycleRepeat() { control(["--repeat"]); }

  function seek(fraction) {
    elapsed = Math.round(fraction * duration);
    control(["--seek", String(elapsed)]);
  }

  // Replaces the queue (likes, a station or a folder); errors are dismissed after six seconds.
  function load(value, args) {
    busy = value;
    error = "";
    run(loadProc, args);
  }

  function clearError() { error = ""; }

  // a folder of the local files, played from `file` (else its first track)
  function playFolder(dir, file) {
    load(dir, ["--files-play", dir].concat(file ? [file] : []));
  }

  function addFile(file, next) { control([next ? "--files-next" : "--files-add", file]); }

  // the queue as MPD has it now (the popups and the window ask when they show)
  function refreshQueue() {
    if (!queueProc.running) run(queueProc, ["--queue"]);
  }

  // ---- internals ----
  function run(proc, args) {
    proc.command = ["bash", root.script].concat(args);
    proc.running = true;
  }

  function parseList(text) { return Reply.parseList(text); }

  function parse(text) {
    return Reply.parse(text, "music.sh", null);
  }

  Timer {
    interval: 1000
    running: root.playing && root.source === "likes"
    repeat: true
    onTriggered: root.elapsed = Math.min(root.duration, root.elapsed + 1)
  }

  Timer { id: settle; interval: 500; onTriggered: root.refresh() }

  Timer {
    id: errorExpiry
    interval: 6000
    onTriggered: root.clearError()
  }
  onErrorChanged: {
    if (error !== "") errorExpiry.restart();
    else errorExpiry.stop();
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        if (!o) return;
        root.player = o;
        root.elapsed = o.elapsed ?? 0;
      }
    }
  }

  Timer {
    id: listenRestart
    interval: root.restartMs
    onTriggered: listenProc.running = root.needed
  }

  Process {
    id: listenProc
    command: ["bash", root.script, "--listen"]
    stdout: SplitParser {
      onRead: line => {
        const o = root.parse(line);
        if (!o) return;
        const changed = o.length !== root.player.length;
        root.player = o;
        root.elapsed = o.elapsed ?? 0;
        if (changed) root.refreshQueue();
      }
    }
    onExited: if (root.needed) listenRestart.start()
  }

  Process {
    id: queueProc
    stdout: StdioCollector {
      onStreamFinished: root.queue = root.parseList(text)
    }
  }

  Process {
    id: loadProc
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        root.busy = null;
        if (!o?.ok) root.error = o?.error ?? "could not start playback";
        root.refreshQueue();
        root.refresh();
      }
    }
  }
}
