pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.apps.capture
import qs.bar.island

// The sound as bar levels for the Equalizer module, the island's player and
// its hub, the recording's live activity: cava's bars while something plays (IslandService.playing) or a recording runs, a calm
// made-up wave without cava. Runs only while some EqualizerBars is visible.
Singleton {
  id: root

  // ---- tuning ----
  readonly property int bars: 12
  readonly property int fps: 30

  property var levels: new Array(bars).fill(0)
  property bool cava: true                      // false once cava turns out missing
  property int users: 0                         // EqualizerBars on screen right now
  readonly property bool on: (IslandService.playing || (CaptureService.recording && !CaptureService.paused)) && users > 0

  Process {
    id: cavaProc
    running: root.on && root.cava
    command: ["bash", "-c", "command -v cava >/dev/null || exit 3\nexec cava -p /dev/stdin <<'EOF'\n"
      + "[general]\nbars = " + root.bars + "\nframerate = " + root.fps + "\n"
      + "[input]\nmethod = pipewire\n"
      + "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\n"
      + "bar_delimiter = 59\nframe_delimiter = 10\nEOF"]
    stdout: SplitParser {
      onRead: line => {
        const v = line.split(";").filter(s => s !== "").map(s => Number(s) / 100);
        if (v.length === root.bars) root.levels = v;
      }
    }
    onExited: code => {
      if (code === 3) root.cava = false;
      root.levels = new Array(root.bars).fill(0);
    }
  }

  property real phase: 0
  Timer {
    running: root.on && !root.cava
    interval: 90
    repeat: true
    onTriggered: {
      root.phase += 0.55;
      const out = [];
      for (let i = 0; i < root.bars; i++) {
        const base = 0.35 + 0.25 * Math.sin(root.phase + i * 0.8) + 0.15 * Math.sin(root.phase * 1.7 - i * 1.3);
        out.push(Math.max(0.08, Math.min(1, base + (Math.random() - 0.5) * 0.3)));
      }
      root.levels = out;
    }
    onRunningChanged: if (!running && !cavaProc.running) root.levels = new Array(root.bars).fill(0)
  }

}
