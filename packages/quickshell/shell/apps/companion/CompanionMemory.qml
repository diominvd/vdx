import QtQuick
import Quickshell
import Quickshell.Io

// What Kimmy remembers between sessions, so it is somebody you know and not a toy that
// starts blank: how well you know each other (bond), when you were last here, on how
// many days you met, the hour you usually come. A small file in the shell's state
// directory, written at most every few minutes and only after something changed.
Item {
  id: root

  readonly property bool loaded: file.ready
  readonly property real bond: store.bond                   // 0 strangers … 1 close friends
  readonly property double lastSeen: store.lastSeen         // ms; 0 = never met
  readonly property double firstMet: store.firstMet
  readonly property int days: store.days
  readonly property real usualHour: store.usualHour
  property double sessionStart: Date.now()

  // the mood of the day: rolled again after a few hours, kept over a reload
  readonly property string mood: store.mood
  readonly property double moodAt: store.moodAt
  function setMood(name) { store.mood = name; store.moodAt = Date.now(); dirty(); }
  // how close it feels: 0 strangers, 1 friends, 2 close, 3 best friends (announced once each)
  readonly property int stage: store.stage
  function setStage(n) { store.stage = n; dirty(); }
  // what you spend your time in, by kind of program: it knows your habits
  readonly property var apps: store.apps
  function count(kind) {
    const a = Object.assign({}, store.apps);
    a[kind] = (a[kind] ?? 0) + 1;
    store.apps = a;
    dirty();
  }
  function favourite() {
    let best = "", n = 0, total = 0;
    for (const k in store.apps) { total += store.apps[k]; if (store.apps[k] > n) { n = store.apps[k]; best = k; } }
    return { kind: best, n: n, share: total > 0 ? n / total : 0 };
  }

  // how long it was alone before this session, in hours (0 for a first meeting)
  property real away: 0
  property int dayNumber: 0                                  // which day of knowing each other
  property bool newDay: false
  property bool firstMeeting: false
  signal ready

  function today() { return new Date().toDateString(); }

  function begin() {
    const now = Date.now();
    root.sessionStart = now;
    firstMeeting = store.firstMet === 0;
    away = store.lastSeen > 0 ? (now - store.lastSeen) / 3600000 : 0;
    if (firstMeeting) store.firstMet = now;
    // a long absence cools the bond a little: a day or two is nothing, a week is felt
    if (away > 72) store.bond = Math.max(0, store.bond - Math.min(0.25, (away - 72) / 24 * 0.02));
    newDay = store.lastDay !== today();
    if (newDay) {
      store.lastDay = today();
      store.days += 1;
      store.bond = Math.min(1, store.bond + 0.02);
      const h = new Date().getHours();
      store.usualHour = store.days <= 1 ? h : store.usualHour * 0.8 + h * 0.2;
    }
    dayNumber = Math.max(1, Math.round((now - store.firstMet) / 86400000) + 1);
    store.lastSeen = now;
    dirty();
    ready();
  }

  // what a moment does to the bond: small, so it takes weeks
  readonly property var steps: ({ stroke: 0.004, play: 0.003, throwFun: 0.003, trick: 0.002, pokeFun: 0.001,
                                   poke: -0.001, throwBad: -0.012, shaken: -0.006, ignored: -0.012 })
  function moment(kind) {
    const d = steps[kind];
    if (d === undefined || !file.ready) return;
    store.bond = Math.max(0, Math.min(1, store.bond + d));
    dirty();
  }

  function dirty() { if (!saver.running) saver.start(); }
  Timer {
    id: saver
    interval: 180000
    onTriggered: { store.lastSeen = Date.now(); file.writeAdapter(); }
  }
  Component.onDestruction: if (file.ready) { store.lastSeen = Date.now(); file.writeAdapter(); }

  readonly property string dir: Quickshell.env("HOME") + "/.local/state/vdx"
  Process {
    command: ["mkdir", "-p", root.dir]
    running: true
    onExited: file.path = root.dir + "/kimmy.json"
  }

  FileView {
    id: file
    // a fixed place, so the standalone run and the shell share one memory
    path: ""      // set when the folder is there (Process below)
    printErrors: false
    property bool ready: false
    onLoaded: { ready = true; root.begin(); }
    onLoadFailed: { ready = true; writeAdapter(); root.begin(); }

    JsonAdapter {
      id: store
      property real bond: 0.25
      property double lastSeen: 0
      property double firstMet: 0
      property string lastDay: ""
      property int days: 0
      property real usualHour: 12
      property string mood: ""
      property double moodAt: 0
      property int stage: 0
      property var apps: ({})
    }
  }
}
