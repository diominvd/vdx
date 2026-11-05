import QtQuick
import Quickshell
import qs.config
import qs.modules.audio
import qs.modules.focus

// Kimmy's voice: little synthesized blips (sounds/, rebuilt by make_sounds.py), played
// by `pw-play` only when it speaks: no player process, no audio device held while quiet.
// Quiet by design: a low volume, never twice at once, never while the sound is muted or
// Focus is on.
Item {
  id: root

  readonly property bool enabled: ModuleSettings.get("companion", "sound", true)
  readonly property real volume: ModuleSettings.get("companion", "volume", "quiet") === "normal" ? 0.5 : 0.22
  readonly property var gaps: ({ purr: 1400, yawn: 2500, whee: 600, chirp1: 90, chirp2: 90, chirp3: 90, chirp4: 90 })
  property var lastAt: ({})
  property double anyAt: 0

  // it talks in chirps: one to three blips, in the length of what it says, never the same run twice
  property int lastChirp: -1
  function babble(text) {
    if (!enabled) return;
    const n = Math.max(1, Math.min(3, Math.round(text.length / 9)));
    chirps.left = n;
    chirps.restart();
  }
  Timer {
    id: chirps
    property int left: 0
    interval: 120
    repeat: true
    onTriggered: {
      if (left <= 0) { stop(); return; }
      left--;
      let k = Math.floor(Math.random() * 4);
      if (k === root.lastChirp) k = (k + 1) % 4;
      root.lastChirp = k;
      root.play("chirp" + (k + 1));
    }
  }

  function play(name) {
    if (!enabled || AudioService.muted || FocusService.on) return;
    const now = Date.now();
    if (now - anyAt < 70 || now - (lastAt[name] ?? 0) < (gaps[name] ?? 250)) return;
    anyAt = now;
    lastAt[name] = now;
    Quickshell.execDetached(["pw-play", "--volume", String(volume), Quickshell.shellDir + "/apps/companion/sounds/" + name + ".wav"]);
  }
}
