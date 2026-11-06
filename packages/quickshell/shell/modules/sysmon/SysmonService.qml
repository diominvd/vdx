pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../../kit/reply.js" as Reply

// System metrics from scripts/sysmon.sh: the bar reads only the CPU load (a
// cheap sample every few seconds); the open popup gets a full snapshot every
// 1.5 s. Percentages and rates come from the difference of two snapshots.
Singleton {
  id: root

  // ---- tuning ----
  readonly property string script: Paths.scriptsDir + "/sysmon.sh"
  readonly property int fullMs: 1500           // a sample while the popup or a holder is open
  readonly property int barMs: 3000            // the bar's cpu-only sample

  // ---- cpu ----
  property int cpu: 0                 // all cores, %
  property var cores: []              // each core, %
  property int freq: 0                // MHz, average
  property var load: [0, 0, 0]
  property int uptime: 0              // s

  // ---- memory ----
  property var mem: ({ total: 0, available: 0, swapTotal: 0, swapFree: 0 })
  readonly property real memUsed: mem.total - mem.available
  readonly property real swapUsed: mem.swapTotal - mem.swapFree

  // ---- gpu, sensors ----
  property var igpu: null             // {cur, max} MHz
  property var dgpu: ({ state: "none" })
  property var temps: ({ cpu: null, nvme: [], wifi: null })
  property var fans: []

  // ---- disks, network ----
  property var disks: []
  property string iface: ""
  property real rxRate: 0             // B/s
  property real txRate: 0
  property real readRate: 0
  property real writeRate: 0

  property bool popupOpen: false
  // others that want the full snapshot (GPU, network…) while they are open:
  // hold() when shown, release() when gone (the task manager)
  property int holders: 0
  readonly property bool full: popupOpen || holders > 0
  function hold() { holders++; sample(); }
  function release() { holders = Math.max(0, holders - 1); }
  property var last: null             // previous snapshot, for the differences

  function popupShown() { popupOpen = true; sample(); }
  function popupHidden() { popupOpen = false; }

  function sample() {
    if (proc.running) return;
    proc.command = ["bash", root.script].concat(full ? [] : ["cpu"]);
    proc.running = true;
  }

  function percent(now, before) {
    const total = now[0] - before[0], idle = now[1] - before[1];
    return total > 0 ? Math.round(100 * (total - idle) / total) : 0;
  }

  function take(s) {
    const now = Date.now();
    const prev = last;
    if (prev && prev.cpu?.length === s.cpu.length) {
      cpu = percent(s.cpu[0], prev.cpu[0]);
      cores = s.cpu.slice(1).map((c, i) => percent(c, prev.cpu[i + 1]));
    }
    if (s.uptime !== undefined) uptime = s.uptime;
    if (s.mem) {
      freq = s.freq;
      load = s.load;
      mem = s.mem;
      igpu = s.igpu;
      dgpu = s.dgpu;
      temps = s.temps;
      fans = s.fans;
      disks = s.disks;
      iface = s.net?.iface ?? "";
      // rates over the time since the previous full snapshot
      // (a stale one, from the popup's last opening, gives no rate yet)
      const span = prev?.fullAt && now - prev.fullAt < 5000 ? (now - prev.fullAt) / 1000 : 0;
      if (prev?.net && s.net && span > 0) {
        rxRate = Math.max(0, (s.net.rx - prev.net.rx) / span);
        txRate = Math.max(0, (s.net.tx - prev.net.tx) / span);
      }
      if (prev?.io && span > 0) {
        readRate = Math.max(0, (s.io.read - prev.io.read) / span);
        writeRate = Math.max(0, (s.io.write - prev.io.write) / span);
      }
    }
    // a cpu-only snapshot keeps the full one's other counters for the next diff
    last = s.mem ? Object.assign({}, s, { fullAt: now }) : Object.assign({}, prev ?? {}, { cpu: s.cpu });
  }

  Timer {
    interval: root.full ? root.fullMs : root.barMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.sample()
  }

  Process {
    id: proc
    stdout: StdioCollector {
      onStreamFinished: {
        const s = Reply.parse(text, "sysmon.sh", null);
        if (s) root.take(s);
      }
    }
  }
}
