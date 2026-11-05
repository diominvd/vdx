import QtQuick
import Quickshell
import qs.config
import qs.modules.player
import qs.modules.battery
import qs.modules.audio
import qs.modules.sysmon
import qs.modules.notifications

// What makes Kimmy live inside the machine: it feels what the computer does. Music
// makes it sway, a hot processor makes it sweat, the charger is food, a message is a
// knock, the night makes it sleepy. Nothing here polls: every source is a value the
// shell already holds and tells when it changes (the swaying timer runs only while
// music plays and it is idle at home).
Item {
  id: root

  required property var brain
  required property var ball

  readonly property bool free: !brain.bodyBusy && !ball.asleep && !ball.dozing && brain.doing !== "nap" && !brain.touching
  property double quietUntil: 0
  function ok(gap) {
    const now = Date.now();
    if (now < quietUntil || !free) return false;
    quietUntil = now + gap;
    return true;
  }

  // the machine in a line, for the model's context (nothing from the screen, only state)
  readonly property string line: {
    const parts = [];
    if (playing) parts.push("играет музыка");
    if (sweating) parts.push("процессор сильно нагружен");
    if (BatteryService.present) parts.push(BatteryService.plugged ? "ноутбук заряжается" : "ноутбук на батарее, заряд " + BatteryService.capacity + "%");
    return parts.length ? "Вокруг: " + parts.join(", ") + "." : "";
  }

  // ---- music ----
  readonly property bool playing: PlayerService.playing
  property string lastTitle: ""
  onPlayingChanged: {
    if (playing) { if (ok(8000)) { ball.express("happy", 1200); ball.lookAt(0, -0.5, 900); brain.say("musicOn", true); } }
    else if (ok(8000)) { ball.slowBlink(); brain.say("musicOff"); }
  }
  Connections {
    target: PlayerService
    function onTitleChanged() {
      if (!PlayerService.playing || PlayerService.title === root.lastTitle) return;
      root.lastTitle = PlayerService.title;
      if (root.ok(15000)) { ball.hopBy(0.2); brain.say("track"); }
    }
  }
  // dances to the beat while music plays and it is idle: a sway, small hops, and every
  // eighth beat a figure of its own (a spin, a double hop, a wiggle), notes floating up
  property bool swing: false
  property int beat: 0
  Timer {
    interval: 520
    repeat: true
    running: root.playing && Motion.bar && brain.doing === "home" && root.free
    onTriggered: {
      root.swing = !root.swing;
      root.beat++;
      ball.tilt = root.swing ? 5 : -5;
      if (root.beat % 8 === 0) {
        const f = Math.floor(Math.random() * 4);
        if (f === 0) ball.trick("spin");
        else if (f === 1) { ball.hopBy(0.22); ball.wave(); }
        else if (f === 2) ball.trick("bounce");
        else ball.wave();
        ball.emote("note");
      } else if (root.beat % 4 === 0) { ball.hopBy(0.12); if (Math.random() < 0.5) ball.emote("note"); }
      else if (Math.random() < 0.2) ball.hopBy(0.07);
    }
  }

  // ---- the processor ----
  property real hotFor: 0
  property bool sweating: false
  Connections {
    target: SysmonService
    function onCpuChanged() {
      const hot = SysmonService.cpu >= 85;
      root.hotFor = hot ? root.hotFor + 3 : 0;
      if (!root.sweating && root.hotFor >= 9 && root.ok(30000)) {
        root.sweating = true;
        ball.express("focus", 2500);
        ball.emote("sweat");
        brain.say("cpuHot", true);
      } else if (root.sweating && SysmonService.cpu < 50) {
        root.sweating = false;
        if (root.ok(5000)) { ball.slowBlink(); ball.land(0.3); brain.say("cpuCool"); }
      }
    }
  }

  // ---- the charger ----
  readonly property bool plugged: BatteryService.plugged
  property bool pluggedSeen: BatteryService.plugged
  readonly property int level: BatteryService.capacity
  property int levelSeen: BatteryService.capacity
  onPluggedChanged: {
    if (!BatteryService.ready || plugged === pluggedSeen) return;
    pluggedSeen = plugged;
    if (!ok(6000)) return;
    if (plugged) { ball.express("glee", 1500); ball.hopBy(0.25); brain.say("plugIn", true); }
    else { ball.express("surprised", 900); brain.say("plugOut", true); }
  }
  onLevelChanged: {
    if (!BatteryService.ready || !BatteryService.present) return;
    const was = levelSeen;
    levelSeen = level;
    if (level <= 15 && was > 15 && !plugged && ok(60000)) { ball.express("sad", 3000); brain.say("hungry", true); }
    else if (level >= 100 && was < 100 && plugged && ok(60000)) { ball.express("proud", 2000); brain.say("full", true); }
  }

  // ---- messages and sound ----
  property int unseenSeen: NotificationsService.unseen
  Connections {
    target: NotificationsService
    function onUnseenChanged() {
      const n = NotificationsService.unseen;
      const more = n > root.unseenSeen;
      root.unseenSeen = n;
      if (!more || !root.ok(5000)) return;
      ball.lookAt(0.3, -0.7, 900);
      ball.hopBy(0.18);
      brain.say("knock");
    }
  }
  property bool mutedSeen: AudioService.muted
  Connections {
    target: AudioService
    function onMutedChanged() {
      const muted = AudioService.muted;
      if (muted === root.mutedSeen) return;
      root.mutedSeen = muted;
      if (!root.ok(4000)) return;
      if (muted) { ball.express("surprised", 700); brain.say("muted"); }
      else brain.say("unmuted");
    }
  }

  // ---- the hour ----
  SystemClock { id: clock; precision: SystemClock.Hours }
  readonly property int hour: clock.date.getHours()
  property int hourSeen: -1
  onHourChanged: {
    const h = hour, was = hourSeen;
    hourSeen = h;
    if (was === -1 || h === was) return;
    if (h === 23 && ok(1000)) { ball.yawn(); brain.say("late", true); }
    else if (h === 2 && ok(1000)) { ball.express("sleepy", 2500); brain.say("veryLate", true); }
    else if (h === 7 && ok(1000)) { ball.wave(); brain.say("morning", true); }
  }
  Component.onCompleted: hourSeen = hour
}
