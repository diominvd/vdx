pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Timer: one countdown or one stopwatch at a time. The bar module, the hub's
// tile and the island's live slot read it; `now` ticks only while it runs.
// Time is taken from the clock (`since`), not counted by ticks, so a late tick
// costs nothing. A countdown that reaches zero ends with a notification.
Singleton {
  id: root

  // ---- tuning ----
  readonly property int countdownTickMs: 250
  readonly property int stopwatchTickMs: 50
  readonly property var presets: (ModuleSettings.get("timer", "presets", []) ?? [])
    .filter(minutes => Number.isInteger(minutes) && minutes > 0 && minutes <= maxMinutes)
  readonly property int maxMinutes: 1440                    // 24 hours

  // ---- state ----
  property string kind: ""                    // "" | countdown | stopwatch
  property bool paused: false
  property real total: 0                      // countdown: its length, ms
  property string label: ""
  property real base: 0                       // ms counted before the last resume
  property real since: 0                      // Date.now() at the last resume
  property real now: 0
  property var laps: []                       // stopwatch: lap times, ms, newest first
  property int lastMinutes: 15                // what the ruler starts at

  readonly property bool active: kind !== ""
  readonly property bool running: active && !paused
  readonly property real elapsed: base + (running ? Math.max(0, now - since) : 0)
  readonly property real remaining: kind === "countdown" ? Math.max(0, total - elapsed) : 0
  readonly property real progress: kind === "countdown" && total > 0 ? Math.min(1, elapsed / total) : 0
  // the clock time a running countdown ends at (every tick of `remaining` renews it)
  readonly property string endsText: kind === "countdown" && running ? Qt.formatTime(new Date(Date.now() + remaining), "hh:mm") : ""
  readonly property string text: kind === "countdown" ? fmt(remaining, false) : kind === "stopwatch" ? fmt(elapsed, true) : ""
  readonly property string title: kind === "stopwatch" ? "Stopwatch" : "Timer"

  // ---- actions ----
  function startCountdown(minutes, name) {
    if (minutes <= 0) return;
    lastMinutes = minutes;
    begin("countdown", minutes * 60000, name ?? "");
  }
  function startStopwatch() { begin("stopwatch", 0, ""); }
  function begin(k, ms, name) {
    laps = [];
    total = ms;
    label = name;
    base = 0;
    since = Date.now();
    now = since;
    paused = false;
    kind = k;
  }
  function pause() {
    if (!running) return;
    now = Date.now();
    if (kind === "countdown" && remaining <= 0) { finish(); return; }
    base = elapsed;
    paused = true;
  }
  function resume() {
    if (!paused) return;
    since = Date.now();
    now = since;
    paused = false;
  }
  function togglePause() { if (paused) resume(); else pause(); }
  function stop() { kind = ""; paused = false; base = 0; laps = []; }
  function lap() {
    if (kind !== "stopwatch" || !running) return;
    now = Date.now();
    laps = [elapsed - lapsTotal()].concat(laps);
  }
  function lapsTotal() { return laps.reduce((a, b) => a + b, 0); }

  // 83 s → "01:23"; an hour or more → "1:01:23"; `cs`: the hundredths, "01:23,45"
  function fmt(ms, cs) {
    const t = Math.max(0, ms);
    const whole = cs ? Math.floor(t / 1000) : Math.ceil(t / 1000);
    const h = Math.floor(whole / 3600), m = Math.floor(whole % 3600 / 60), s = whole % 60;
    const pad = n => (n < 10 ? "0" : "") + n;
    return (h > 0 ? h + ":" + pad(m) : pad(m)) + ":" + pad(s) + (cs ? "," + pad(Math.floor(t % 1000 / 10)) : "");
  }

  // ---- the tick ----
  Timer {
    interval: root.kind === "stopwatch" ? root.stopwatchTickMs : root.countdownTickMs
    running: root.running
    repeat: true
    onTriggered: {
      root.now = Date.now();
      if (root.kind === "countdown" && root.remaining <= 0) root.finish();
    }
  }

  function finish() {
    if (kind !== "countdown") return;
    const name = label !== "" ? label : fmt(total, false) + " timer";
    stop();
    ring.command = ["notify-send", "-a", "Timer", "-i", "alarm-symbolic", "Time is up", name];
    ring.running = true;
  }
  Process { id: ring }
}
