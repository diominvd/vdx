import QtQuick
import QtQuick.Shapes
import qs.config
import "eyes.js" as Eyes

// The Companion's body: a white ball with two eyes. It draws and it plays moves; what
// to do and when is the brain's (CompanionBrain), so every move here is a verb the
// brain can call, never a loop of its own beyond small life signs.
//
//   gaze     a spring after a target: the pointer near it, an object it was shown, or a
//            saccade at a random 1-5 s (quicker when it has energy)
//   lids     blinks at 2-7 s, of three kinds (quick, slow, double); a slow blink on
//            purpose when it trusts you
//   looks    the eyes' shape per expression comes from eyes.js: capsules cut by lids
//            (smug, sleepy, cross, sad, focused), ^ ^ arcs (purr, glee, proud), spirals
//            (dizzy); every change springs or eases, nothing snaps
//   body     breath, squash and stretch (pressed, landing, a wall, a fast carry), lean,
//            roll (a throw turns it over, then it rights itself with a wobble), a
//            shiver, a purr wobble, a shake-off, tricks (flip, spin, bounce)
//   moods    a reaction has a priority, a hold time and a cooldown: a weaker one cannot
//            cut a stronger one and the same one waits before it plays again;
//            express() is the brain's own word and always wins
// Reduced motion (Motion.bar off): no breath, saccades, fidgets or springs; blinks stay,
// instant, so it still looks alive.
Item {
  id: root

  property real size: 22

  // ---- its look ----
  // A CompanionStyle (what the user set in Shell Manager › Kimmy); without one it is the
  // white ball with black eyes. Every part is read from here, never from the settings.
  property var style: null
  readonly property color cBody: style ? style.bodyColour : "#ffffff"
  readonly property real cDepth: style ? style.bodyDepth : 0.45
  readonly property bool cRim: style ? style.rimOn : false
  readonly property color cRimColour: style ? style.rimColour : "#ffffff"
  readonly property real cRimWidth: style ? style.rimWidth : 0.04
  readonly property bool cShine: style ? style.shineOn : false
  readonly property color eyeColor: style ? style.eyeColour : "#0c0c0e"
  readonly property real cEyeW: style ? style.eyeWidth : 1
  readonly property real cEyeH: style ? style.eyeHeight : 1
  readonly property real cEyeGap: style ? style.eyeGap : 1
  readonly property real cEyeTilt: style ? style.eyeTilt : 0
  readonly property bool cGlow: style ? style.glowOn : false
  readonly property color cGlowColour: style ? style.glowColour : "#a35bd6"
  readonly property real cGlowSize: style ? style.glowSize : 1
  readonly property int cSparkles: style ? style.sparkleCount : 0
  readonly property color cSparkleColour: style ? style.sparkleColour : "#ffffff"

  // its voice: the window plays it (CompanionSound), so a ball without a window stays mute
  signal sound(string name)
  // a small sign over its head, like a thought: heart, note, spark, tear, bang, ask, z, anger, sweat
  signal emote(string kind)

  // ---- inner state, from the brain ----
  property real energy: 0.6             // 0 drained … 1 wound up: quick saccades, a quicker breath
  property real drowsy: 0               // 0 awake … 1 about to drop off: the lids sink, the head nods
  property real sulk: 0                 // 0 … 1: half-lidded, turned away
  property bool busy: false             // held or flying: no fidgets, no weight shifts

  // ---- motion, from the brain while it runs, is carried or flies ----
  property real speedFrac: 0            // 0 still … 1 flat out
  property real lean: 0                 // degrees, into the run or the swing
  property real bounce: 0               // px up, the run's hops
  property real lift: 0                 // px up, carried or in the air
  property real flowX: 0                // stretch along a fast carry: + wider, - narrower
  property real flowY: 0                //                             + taller, - flatter
  property bool sneaking: false         // low to the ground, stalking
  property real roll: 0                 // degrees the body has turned over in a throw
  property bool rolling: false          // the brain drives `roll`; off: it springs back

  // ---- the pointer ----
  // in the ball's own terms (-1..1 per axis), from the brain or the hover handler
  property bool pointerNear: false
  property bool pointerOver: false
  property real pointerX: 0
  property real pointerY: 0

  // ---- mood ----
  property string mood: "idle"
  readonly property var priority: ({ sleeping: 0, idle: 0, curious: 1, hover: 1, mischief: 1, focus: 1, smug: 2, confused: 2, sad: 2,
                                     surprised: 3, happy: 3, glee: 3, proud: 3, purr: 3, offended: 3, dizzy: 4, error: 4, panic: 4 })
  readonly property var holdMs: ({ mischief: 3000, curious: 1400, happy: 1300, error: 1600, confused: 1500, surprised: 900, dizzy: 1600 })
  readonly property var cooldownMs: ({ mischief: 0, curious: 9000, happy: 600, error: 600, confused: 1500, surprised: 1200, dizzy: 3000 })
  property var lastPlayed: ({})
  property string held: ""

  // a reaction from the world: it may lose to a stronger one, and waits out its cooldown
  function react(kind) {
    const now = Date.now();
    if (now - (lastPlayed[kind] ?? 0) < (cooldownMs[kind] ?? 0)) return;
    if (held !== "" && (priority[kind] ?? 0) < (priority[held] ?? 0)) return;
    lastPlayed[kind] = now;
    express(kind, holdMs[kind] ?? 1000);
    if (kind === "happy") hopBy(0.22);
    else if (kind === "error") shake.restart();
    else if (kind === "surprised") jolt();
    else if (kind === "confused") { gazeX = 0.5; gazeY = -0.35; tilt = 8; tiltBack.restart(); }
    else if (kind === "curious") { gazeX = pointerX; gazeY = pointerY; blinkSoon(); }
  }
  // the brain's word: this face, for this long, whatever was there
  readonly property var voices: ({ purr: "purr", happy: "pip", glee: "pip", sad: "sad", surprised: "boop", offended: "boop" })
  readonly property var signs: ({ purr: "heart", happy: "heart", glee: "spark", proud: "spark", sad: "tear", surprised: "bang", panic: "bang",
                                  confused: "ask", curious: "ask", offended: "anger", error: "anger", focus: "sweat", smug: "spark" })
  function express(kind, ms) {
    if (voices[kind]) sound(voices[kind]);
    if (signs[kind]) emote(signs[kind]);
    wake();
    held = kind;
    holdTimer.interval = Math.max(60, ms);
    holdTimer.restart();
    if (kind === "dizzy") { dizzyTick.phase = 0; dizzyTick.restart(); }
    refreshMood();
  }
  function relax() { held = ""; holdTimer.stop(); refreshMood(); }

  Timer {
    id: dizzyTick
    property real phase: 0
    interval: 70
    repeat: true
    onTriggered: {
      phase += 0.9;
      root.gazeX = Math.cos(phase) * 0.7;
      root.gazeY = Math.sin(phase) * 0.7;
      if (phase > 16) { stop(); root.gazeX = 0; root.gazeY = 0; }
    }
  }

  // it goes to sleep at once (the brain does this when it is back home, tired)
  function sleepNow() { dozing = false; sleepy.stop(); drowsy = 0; held = ""; sleepTimer.stop(); sleepTimer.expired = true; refreshMood(); }
  function wake() { sleepTimer.expired = false; sleepTimer.restart(); if (mood === "sleeping") refreshMood(); }
  readonly property bool asleep: mood === "sleeping"

  function refreshMood() {
    if (held !== "") mood = held;
    else if (sleepTimer.expired) mood = "sleeping";
    else if (pointerOver) mood = "hover";
    else mood = "idle";
  }
  onPointerOverChanged: {
    if (pointerOver && !asleep) { wake(); react("curious"); }
    else if (!pointerOver && !pointerNear) { gazeX = 0; gazeY = 0; }
    refreshMood();
  }
  onPointerNearChanged: if (!pointerNear && !pointerOver) { gazeX = 0; gazeY = 0; }

  Timer { id: holdTimer; onTriggered: { root.held = ""; root.refreshMood(); } }
  // five quiet minutes and it dozes off; any touch wakes it
  Timer {
    id: sleepTimer
    property bool expired: false
    interval: 300000
    running: true
    onTriggered: { expired = true; root.refreshMood(); }
  }

  // ---- gaze ----
  property real gazeX: 0                // target, -1..1
  property real gazeY: 0
  property real eyeX: 0                 // shown
  property real eyeY: 0
  Behavior on eyeX { enabled: Motion.bar; SpringAnimation { spring: 2.6; damping: 0.32; epsilon: 0.002 } }
  Behavior on eyeY { enabled: Motion.bar; SpringAnimation { spring: 2.6; damping: 0.32; epsilon: 0.002 } }
  onGazeXChanged: eyeX = gazeX
  onGazeYChanged: eyeY = gazeY

  function lookAtPointer() {
    gazeX = Math.max(-1, Math.min(1, pointerX * 0.9));
    gazeY = Math.max(-1, Math.min(1, pointerY * 0.9));
  }
  // looks at something else for a while (a window, a wall, away from you)
  property double glanceUntil: 0
  function lookAt(x, y, ms) {
    glanceUntil = Date.now() + ms;
    gazeX = Math.max(-1, Math.min(1, x));
    gazeY = Math.max(-1, Math.min(1, y));
  }
  onPointerXChanged: if ((pointerNear || pointerOver) && Date.now() > glanceUntil && held !== "dizzy") lookAtPointer()
  onPointerYChanged: if ((pointerNear || pointerOver) && Date.now() > glanceUntil && held !== "dizzy") lookAtPointer()

  Timer {
    id: saccade
    running: Motion.bar && root.visible && !root.asleep
    interval: 2000
    repeat: true
    onTriggered: {
      interval = (900 + Math.random() * 3200) * (1.7 - root.energy);
      if (root.held === "dizzy" || Date.now() < root.glanceUntil) return;
      if (root.held === "panic") { root.gazeX = (Math.random() - 0.5) * 1.8; root.gazeY = (Math.random() - 0.5) * 1.2; interval = 160 + Math.random() * 220; return; }
      if (root.pointerNear || root.pointerOver) {
        if (Math.random() < 0.3 && !root.pointerOver && !root.busy) {
          root.glanceUntil = Date.now() + 700 + Math.random() * 900;
          root.gazeX = (Math.random() - 0.5) * 1.6;
          root.gazeY = -0.2 + Math.random() * 0.6;
          if (Math.random() < 0.4) root.blinkSoon();
        }
        return;
      }
      let x, y;
      if (Math.random() < 0.3) { x = 0; y = 0; }
      else if (Math.random() < 0.2) return;
      else { x = (Math.random() - 0.5) * 1.3; y = (Math.random() - 0.5) * 0.8; }
      const jump = Math.abs(x - root.gazeX) + Math.abs(y - root.gazeY);
      root.gazeX = x;
      root.gazeY = y;
      if (jump > 0.9 && Math.random() < 0.45) root.blinkSoon();
    }
  }

  // ---- the look, from eyes.js; each part eases on its own ----
  readonly property var look: Eyes.look(mood)
  property real eW: look.w
  property real eH: look.h
  property real eHL: look.hL
  property real eHR: look.hR
  property real eRotL: look.rotL
  property real eRotR: look.rotR
  property real eDy: look.dy
  // drowsiness and a sulk lower the lids over whatever the face is
  property real eTop: Math.max(look.top, drowsy * 0.62, sulk > 0.3 ? 0.32 : 0)
  property real eBottom: look.bottom
  readonly property bool arcs: look.shape === "arc"
  readonly property bool spirals: look.shape === "spiral"
  Behavior on eW { enabled: Motion.bar; SpringAnimation { spring: 4; damping: 0.35; epsilon: 0.002 } }
  Behavior on eH { enabled: Motion.bar; SpringAnimation { spring: 4; damping: 0.35; epsilon: 0.002 } }
  Behavior on eHL { enabled: Motion.bar; NumberAnimation { duration: Motion.quick; easing.type: Easing.OutCubic } }
  Behavior on eHR { enabled: Motion.bar; NumberAnimation { duration: Motion.quick; easing.type: Easing.OutCubic } }
  Behavior on eRotL { enabled: Motion.bar; NumberAnimation { duration: Motion.normal; easing.type: Easing.OutBack } }
  Behavior on eRotR { enabled: Motion.bar; NumberAnimation { duration: Motion.normal; easing.type: Easing.OutBack } }
  Behavior on eDy { enabled: Motion.bar; NumberAnimation { duration: Motion.normal; easing.type: Easing.OutCubic } }
  Behavior on eTop { enabled: Motion.bar; NumberAnimation { duration: Motion.normal; easing.type: Easing.OutCubic } }
  Behavior on eBottom { enabled: Motion.bar; NumberAnimation { duration: Motion.normal; easing.type: Easing.OutCubic } }

  // ---- lids ----
  property real lid: 0                  // 0 open … 1 shut (a blink on top of the rest)
  property real lidRest: drowsy > 0 && !asleep ? Math.max(look.lid, 0.06 + drowsy * 0.3) : look.lid
  readonly property real lidShown: Math.max(-0.2, Math.min(1, lidRest + lid * (1 - Math.max(0, lidRest))))
  Behavior on lidRest { enabled: Motion.bar; NumberAnimation { duration: Motion.normal; easing.type: Easing.OutCubic } }

  function blinkSoon() { if (blinker.running) return; blinkTimer.interval = 90 + Math.random() * 160; blinkTimer.restart(); }
  // a slow blink: the cat's "I trust you"
  function slowBlink() {
    if (!Motion.bar || blinker.running) return;
    blinkMs = 620; blinksLeft = 0; blinker.restart();
  }

  SequentialAnimation {
    id: blinker
    NumberAnimation { target: root; property: "lid"; to: 1; duration: root.blinkMs * 0.45; easing.type: Easing.InQuad }
    PauseAnimation { duration: root.blinkMs * 0.12 }
    NumberAnimation { target: root; property: "lid"; to: 0; duration: root.blinkMs * 0.8; easing.type: Easing.OutQuad }
  }
  property int blinkMs: 130
  property int blinksLeft: 0
  Timer {
    id: blinkTimer
    interval: 3000
    running: root.visible
    onTriggered: {
      const kind = Math.random();
      root.blinkMs = Motion.bar ? (kind < 0.62 ? 130 : kind < 0.85 ? 260 : 120) : 1;
      root.blinksLeft = (kind >= 0.85 && !root.asleep) ? 1 : 0;
      if (!root.arcs && !root.spirals) { if (Motion.bar) blinker.restart(); else { root.lid = 1; instantOpen.restart(); } }
      interval = (root.held === "panic" ? 900 : 2000) + Math.random() * 5000 + (root.asleep ? 4000 : 0);
      restart();
    }
  }
  Timer { id: instantOpen; interval: 90; onTriggered: root.lid = 0 }
  Connections {
    target: blinker
    function onRunningChanged() {
      if (!blinker.running && root.blinksLeft > 0) { root.blinksLeft--; root.blinkMs = 120; blinker.restart(); }
    }
  }

  // ---- verbs: the beats of a move ----
  // Before it goes, it gathers (the body sinks); the release overshoots into a stretch
  // and the spring settles it. Landing is the same thing backwards.
  function crouch() { if (Motion.bar) gather.restart(); }
  function land(strength) { if (Motion.bar) squash = Math.min(0.85, strength); if (strength >= 0.4) sound("thud"); }
  // a wall: flat against it, then the spring
  function wallHit(side, strength) { if (strength > 0.25) sound("thud"); if (Motion.bar) squash = side === "x" ? -Math.min(0.8, strength) : Math.min(0.8, strength); }
  // pressed by a finger; held, it stays a little squeezed
  function pressIn() { sound("boop"); if (Motion.bar) press.restart(); }
  function squeeze(on) { if (Motion.bar) { press.stop(); squash = on ? 0.32 : 0; } }
  function jolt() { if (Motion.bar) { squash = 0; joltAnim.restart(); } }
  function hopBy(frac) { if (!Motion.bar) return; if (frac > 0.1) sound("pip"); hop.height = size * frac * (0.85 + Math.random() * 0.3); hop.restart(); }
  function wave() { sound("hello"); if (Motion.bar) wiggle.restart(); }
  function shakeOff() { if (Motion.bar) shakeOffAnim.restart(); }
  function rollEyes() {
    if (!Motion.bar) return;
    express("smug", 1700);
    rollEyesAnim.restart();
  }
  // before a pounce: the butt wiggle
  function ready() { if (Motion.bar) buttWiggle.restart(); }
  function trick(kind) {
    if (!Motion.bar) return;
    sound("whee");
    if (kind === "flip") flipAnim.restart();
    else if (kind === "spin") spinAnim.restart();
    else bounceAnim.restart();
  }
  // after a throw it has turned over: it rights itself the short way round, with a wobble
  function rightItself() {
    rolling = true;
    roll = ((roll % 360) + 540) % 360 - 180;
    rolling = false;
    roll = 0;
  }
  // a dream: a small jolt and a twitch of the lids
  function twitch() {
    if (!Motion.bar) return;
    squash = 0.25;
    tiltNow = (Math.random() < 0.5 ? -1 : 1) * 4;
    twitchBack.restart();
  }
  Timer { id: twitchBack; interval: 160; onTriggered: root.tiltNow = 0 }

  SequentialAnimation {
    id: gather
    NumberAnimation { target: root; property: "squash"; to: 0.75; duration: 170; easing.type: Easing.OutQuad }
    PauseAnimation { duration: 90 }
    ScriptAction { script: root.squash = -0.35 }
  }
  SequentialAnimation {
    id: press
    NumberAnimation { target: root; property: "squash"; to: 0.55; duration: 60; easing.type: Easing.OutQuad }
    ScriptAction { script: root.squash = 0 }
  }
  SequentialAnimation {
    id: joltAnim
    NumberAnimation { target: root; property: "hopY"; to: -root.size * 0.14; duration: Motion.bar ? 70 : 1; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "hopY"; to: 0; duration: Motion.bar ? 220 : 1; easing.type: Easing.OutBack }
  }
  SequentialAnimation {
    id: hop
    property real height: root.size * 0.22
    ScriptAction { script: root.squash = 0.3 }
    PauseAnimation { duration: 60 }
    NumberAnimation { target: root; property: "hopY"; to: -hop.height; duration: 150 + hop.height * 2; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "hopY"; to: 0; duration: 180 + hop.height * 3; easing.type: Easing.InQuad }
    ScriptAction { script: root.squash = 0.4 }
  }
  SequentialAnimation {
    id: shake
    NumberAnimation { target: root; property: "shakeX"; to: -root.size * 0.09; duration: Motion.bar ? 55 : 1 }
    NumberAnimation { target: root; property: "shakeX"; to: root.size * 0.09; duration: Motion.bar ? 90 : 1 }
    NumberAnimation { target: root; property: "shakeX"; to: -root.size * 0.05; duration: Motion.bar ? 80 : 1 }
    NumberAnimation { target: root; property: "shakeX"; to: 0; duration: Motion.bar ? 70 : 1 }
  }
  // a dog out of the water: fast, decaying turns of the whole body, eyes shut tight
  SequentialAnimation {
    id: shakeOffAnim
    ScriptAction { script: root.express("doze", 620) }
    NumberAnimation { target: root; property: "tiltNow"; to: -16; duration: 60; easing.type: Easing.OutSine }
    NumberAnimation { target: root; property: "tiltNow"; to: 15; duration: 85; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "tiltNow"; to: -12; duration: 80; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "tiltNow"; to: 9; duration: 80; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "tiltNow"; to: -5; duration: 85; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "tiltNow"; to: 0; duration: 120; easing.type: Easing.OutSine }
    ScriptAction { script: { root.squash = 0.3; root.blinkSoon(); } }
  }
  SequentialAnimation {
    id: wiggle
    NumberAnimation { target: root; property: "tiltNow"; to: -9; duration: 140; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "tiltNow"; to: 9; duration: 220; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "tiltNow"; to: -5; duration: 200; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "tiltNow"; to: 0; duration: 160; easing.type: Easing.InOutSine }
  }
  SequentialAnimation {
    id: buttWiggle
    ScriptAction { script: root.squash = 0.45 }
    loops: 1
    SequentialAnimation {
      loops: 3
      NumberAnimation { target: root; property: "tiltNow"; to: -5; duration: 70; easing.type: Easing.InOutSine }
      NumberAnimation { target: root; property: "tiltNow"; to: 5; duration: 70; easing.type: Easing.InOutSine }
    }
    NumberAnimation { target: root; property: "tiltNow"; to: 0; duration: 60 }
  }
  // eyes go up and round, half-lidded: "oh, please"
  SequentialAnimation {
    id: rollEyesAnim
    ScriptAction { script: root.lookAt(-0.6, -0.4, 1500) }
    PauseAnimation { duration: 180 }
    ScriptAction { script: root.lookAt(0, -1, 1300) }
    PauseAnimation { duration: 220 }
    ScriptAction { script: root.lookAt(0.7, -0.5, 1000) }
    PauseAnimation { duration: 260 }
    ScriptAction { script: { root.lookAt(0.3, 0.2, 500); root.tilt = 5; tiltBack.restart(); } }
  }
  SequentialAnimation {
    id: flipAnim
    ScriptAction { script: root.squash = 0.6 }
    PauseAnimation { duration: 140 }
    ScriptAction { script: root.squash = -0.3 }
    ParallelAnimation {
      SequentialAnimation {
        NumberAnimation { target: root; property: "hopY"; to: -root.size * 0.9; duration: 260; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "hopY"; to: 0; duration: 240; easing.type: Easing.InQuad }
      }
      NumberAnimation { target: root; property: "flip"; from: 0; to: 360; duration: 480; easing.type: Easing.InOutQuad }
    }
    ScriptAction { script: { root.flip = 0; root.squash = 0.7; root.express("proud", 1400); } }
  }
  SequentialAnimation {
    id: spinAnim
    ScriptAction { script: root.squash = 0.35 }
    NumberAnimation { target: root; property: "flip"; from: 0; to: -720; duration: 720; easing.type: Easing.InOutCubic }
    ScriptAction { script: { root.flip = 0; root.express("dizzy", 900); root.squash = 0.3; } }
  }
  SequentialAnimation {
    id: bounceAnim
    NumberAnimation { target: root; property: "hopY"; to: -root.size * 0.45; duration: 150; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "hopY"; to: 0; duration: 140; easing.type: Easing.InQuad }
    ScriptAction { script: root.squash = 0.5 }
    NumberAnimation { target: root; property: "hopY"; to: -root.size * 0.3; duration: 120; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "hopY"; to: 0; duration: 115; easing.type: Easing.InQuad }
    ScriptAction { script: root.squash = 0.4 }
    NumberAnimation { target: root; property: "hopY"; to: -root.size * 0.16; duration: 90; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "hopY"; to: 0; duration: 90; easing.type: Easing.InQuad }
    ScriptAction { script: { root.squash = 0.3; root.express("glee", 900); } }
  }

  // ---- fidgets ----
  // Now and then, with nobody touching it, it does something of its own. Never twice in a row.
  property int lastFidget: -1
  Timer {
    id: fidgetTimer
    running: Motion.bar && root.visible && !root.busy
    interval: 9000
    repeat: true
    onTriggered: {
      interval = 4000 + Math.random() * 9000;
      if (root.held !== "" || root.pointerOver || root.asleep || root.sneaking) return;
      const kinds = 10;
      let k = Math.floor(Math.random() * kinds);
      if (k === root.lastFidget) k = (k + 1) % kinds;
      root.lastFidget = k;
      if (k === 0) root.hopBy(0.18);
      else if (k === 1) wiggle.restart();
      else if (k === 2) lookRound.restart();
      else if (k === 3) stretch.restart();
      else if (k === 4) doubleTake.restart();
      else if (k === 5) root.yawn();
      else if (k === 6) { root.hopBy(0.12); hopAgain.restart(); }
      else if (k === 7) root.shakeOff();
      else if (k === 8) { root.express("happy", 900); root.slowBlink(); }
      else { root.lookAt((Math.random() - 0.5) * 1.8, -0.1 - Math.random() * 0.3, 900); root.blinkSoon(); }
    }
  }
  // a hop and a second, smaller one: it can not keep still
  Timer { id: hopAgain; interval: 380; onTriggered: root.hopBy(0.08) }
  // a yawn: the lids go heavy, the body stretches, then it blinks the sleep away
  function yawn() {
    if (!Motion.bar) return;
    express("sleepy", 1900);
    sound("yawn");
    stretch.restart();
    yawnEnd.restart();
  }
  Timer { id: yawnEnd; interval: 2000; onTriggered: { root.slowBlink(); } }
  property real tiltNow: 0
  Behavior on tiltNow { enabled: Motion.bar; SpringAnimation { spring: 4; damping: 0.3 } }
  SequentialAnimation {
    id: lookRound
    ScriptAction { script: { root.gazeX = -0.9; root.gazeY = -0.1; } }
    PauseAnimation { duration: 700 }
    ScriptAction { script: { root.gazeX = 0.9; root.gazeY = 0.1; } }
    PauseAnimation { duration: 800 }
    ScriptAction { script: { root.gazeX = 0; root.gazeY = 0; root.blinkSoon(); } }
  }
  property real stretchY: 0
  SequentialAnimation {
    id: stretch
    NumberAnimation { target: root; property: "stretchY"; to: 1; duration: 420; easing.type: Easing.OutCubic }
    PauseAnimation { duration: 260 }
    NumberAnimation { target: root; property: "stretchY"; to: 0; duration: 520; easing.type: Easing.InOutQuad }
  }
  SequentialAnimation {
    id: doubleTake
    ScriptAction { script: { root.gazeX = 0.8; root.gazeY = -0.2; } }
    PauseAnimation { duration: 450 }
    ScriptAction { script: { root.gazeX = 0; root.gazeY = 0; root.blinkSoon(); } }
    PauseAnimation { duration: 260 }
    ScriptAction { script: { root.gazeX = 0.85; root.gazeY = -0.25; } }
    PauseAnimation { duration: 600 }
    ScriptAction { script: { root.gazeX = 0; root.gazeY = 0; } }
  }

  // weight shifts: a degree or two, now and then, never the same twice
  Timer {
    interval: 6000
    running: Motion.bar && root.visible && !root.asleep && !root.busy
    repeat: true
    onTriggered: { interval = 4000 + Math.random() * 8000; root.tilt = (Math.random() - 0.5) * 6; }
  }

  // drowsiness: the lids sink and the head nods before it sleeps, and the other way round
  property bool dozing: false
  function getSleepy(ms) { dozing = true; sleepTimer.stop(); sleepy.duration = ms; sleepy.from = drowsy; sleepy.to = 1; sleepy.restart(); }
  function rouse() { dozing = false; sleepy.stop(); drowsy = 0; wake(); }
  NumberAnimation { id: sleepy; target: root; property: "drowsy"; easing.type: Easing.InOutSine; onFinished: if (root.dozing) { root.dozing = false; root.sleepNow(); } }
  SequentialAnimation on tilt {
    running: root.drowsy > 0.3 && Motion.bar && !root.asleep && !root.busy
    loops: Animation.Infinite
    NumberAnimation { to: 7; duration: 1500; easing.type: Easing.InOutSine }
    NumberAnimation { to: 0; duration: 220; easing.type: Easing.OutBack }
  }

  // ---- small life signs that run only while their face is on ----
  // panic: a shiver; purr and doze: a soft wobble, as if it breathed into your hand
  property real shiverX: 0
  SequentialAnimation on shiverX {
    running: Motion.bar && root.mood === "panic"
    loops: Animation.Infinite
    NumberAnimation { to: root.size * 0.035; duration: 38 }
    NumberAnimation { to: -root.size * 0.03; duration: 46 }
    onRunningChanged: if (!running) root.shiverX = 0
  }
  property real wobble: 0
  SequentialAnimation on wobble {
    running: Motion.bar && (root.mood === "purr" || root.mood === "doze" || root.mood === "glee")
    loops: Animation.Infinite
    NumberAnimation { to: 1; duration: root.mood === "glee" ? 170 : 380; easing.type: Easing.InOutSine }
    NumberAnimation { to: -1; duration: root.mood === "glee" ? 190 : 430; easing.type: Easing.InOutSine }
    onRunningChanged: if (!running) root.wobble = 0
  }

  // ---- body ----
  property real squash: 0               // + pressed flat … - squeezed thin; springs back with an overshoot
  Behavior on squash { enabled: Motion.bar; SpringAnimation { spring: 5; damping: 0.22; epsilon: 0.002 } }
  property real hopY: 0
  property real shakeX: 0
  property real tilt: 0
  property real flip: 0
  Behavior on tilt { enabled: Motion.bar; SpringAnimation { spring: 3; damping: 0.3 } }
  Behavior on roll { enabled: Motion.bar && !root.rolling; SpringAnimation { spring: 2.2; damping: 0.16; epsilon: 0.05 } }
  Timer { id: tiltBack; interval: 600; onTriggered: root.tilt = 0 }

  property real breath: 0
  property real breathMs: 1700
  SequentialAnimation on breath {
    running: Motion.bar && root.visible
    loops: Animation.Infinite
    NumberAnimation { to: 1; duration: root.breathMs; easing.type: Easing.InOutSine }
    NumberAnimation { to: 0; duration: root.breathMs * 1.15; easing.type: Easing.InOutSine }
    ScriptAction { script: root.breathMs = (root.asleep ? 3600 : root.mood === "panic" ? 420 : 1300 + (1 - root.energy) * 700) * (0.85 + Math.random() * 0.3) }
  }

  implicitWidth: size * 1.1
  implicitHeight: size * 1.1

  Item {
    id: body
    width: root.size
    height: root.size
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: root.shakeX + root.shiverX
    anchors.verticalCenterOffset: root.hopY - root.bounce - root.lift + (root.sneaking ? root.size * 0.08 : 0)
    rotation: root.tilt + root.tiltNow + root.lean + root.flip + root.roll
    scale: 1 + root.breath * 0.035 + (root.mood === "hover" ? 0.06 : 0) + (root.mood === "happy" ? 0.04 : 0)
    transform: Scale {
      origin.x: body.width / 2
      origin.y: body.height
      xScale: 1 + root.squash * 0.16 - root.stretchY * 0.06 + root.speedFrac * 0.1 + root.flowX + root.wobble * 0.035 + (root.sneaking ? 0.12 : 0)
      yScale: 1 - root.squash * 0.18 + root.stretchY * 0.14 - root.speedFrac * 0.07 + root.flowY - root.wobble * 0.035 - (root.sneaking ? 0.16 : 0)
    }
    Behavior on scale { enabled: Motion.bar; NumberAnimation { duration: Motion.quick; easing.type: Easing.OutCubic } }

    // the halo: two soft discs of colour behind the body, the accent low right and its
    // neighbour hue low left (a glass bubble catching two lights)
    Shape {
      id: haloA
      visible: root.cGlow
      width: root.size * 1.9 * root.cGlowSize
      height: width
      anchors.centerIn: parent
      anchors.horizontalCenterOffset: root.size * 0.08
      anchors.verticalCenterOffset: root.size * 0.1
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Theme.clear
        fillGradient: RadialGradient {
          centerX: haloA.width / 2; centerY: haloA.height / 2; centerRadius: root.size * 0.95 * root.cGlowSize
          focalX: haloA.width / 2; focalY: haloA.height / 2
          GradientStop { position: 0.0; color: Qt.rgba(root.cGlowColour.r, root.cGlowColour.g, root.cGlowColour.b, 0.0) }
          GradientStop { position: 0.45; color: Qt.rgba(root.cGlowColour.r, root.cGlowColour.g, root.cGlowColour.b, 0.0) }
          GradientStop { position: 0.55; color: Qt.rgba(root.cGlowColour.r, root.cGlowColour.g, root.cGlowColour.b, 0.42) }
          GradientStop { position: 1.0; color: Qt.rgba(root.cGlowColour.r, root.cGlowColour.g, root.cGlowColour.b, 0.0) }
        }
        PathAngleArc { centerX: haloA.width / 2; centerY: haloA.height / 2; radiusX: root.size * 0.95 * root.cGlowSize; radiusY: root.size * 0.95 * root.cGlowSize; startAngle: 0; sweepAngle: 360 }
      }
    }
    Shape {
      id: haloB
      visible: root.cGlow
      width: root.size * 1.6 * root.cGlowSize
      height: width
      anchors.centerIn: parent
      anchors.horizontalCenterOffset: -root.size * 0.12
      anchors.verticalCenterOffset: root.size * 0.02
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Theme.clear
        fillGradient: RadialGradient {
          centerX: haloB.width / 2; centerY: haloB.height / 2; centerRadius: root.size * 0.8 * root.cGlowSize
          focalX: haloB.width / 2; focalY: haloB.height / 2
          GradientStop { position: 0.0; color: Qt.hsla((Qt.color(root.cGlowColour).hslHue + 0.62) % 1, 0.7, 0.6, 0.0) }
          GradientStop { position: 0.5; color: Qt.hsla((Qt.color(root.cGlowColour).hslHue + 0.62) % 1, 0.7, 0.6, 0.0) }
          GradientStop { position: 0.6; color: Qt.hsla((Qt.color(root.cGlowColour).hslHue + 0.62) % 1, 0.7, 0.6, 0.3) }
          GradientStop { position: 1.0; color: Qt.hsla((Qt.color(root.cGlowColour).hslHue + 0.62) % 1, 0.7, 0.6, 0.0) }
        }
        PathAngleArc { centerX: haloB.width / 2; centerY: haloB.height / 2; radiusX: root.size * 0.8 * root.cGlowSize; radiusY: root.size * 0.8 * root.cGlowSize; startAngle: 0; sweepAngle: 360 }
      }
    }

    // a white sphere, lit from the top left, a little grey at the bottom right; two
    // tall black capsules for eyes, leaning. White and black on purpose: it is a pet,
    // not part of the theme, and it must read on any wallpaper.
    Shape {
      id: sphere
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Theme.clear
        fillGradient: RadialGradient {
          centerX: sphere.width * 0.42; centerY: sphere.height * 0.36; centerRadius: sphere.width * 0.78
          focalX: sphere.width * 0.34; focalY: sphere.height * 0.26
          GradientStop { position: 0.0; color: root.cBody }
          GradientStop { position: 0.55; color: Qt.darker(root.cBody, 1 + root.cDepth * 0.15) }
          GradientStop { position: 1.0; color: root.mood === "error" ? Qt.tint(Qt.darker(root.cBody, 1 + root.cDepth * 0.95), "#55c04848")
                                                                      : Qt.darker(root.cBody, 1 + root.cDepth * 0.95) }
        }
        PathAngleArc {
          centerX: sphere.width / 2; centerY: sphere.height / 2
          radiusX: sphere.width / 2; radiusY: sphere.height / 2
          startAngle: 0; sweepAngle: 360
        }
      }
    }

    // the rim and a soft reflection, when they are on
    Rectangle {
      visible: root.cRim
      anchors.fill: parent
      radius: width / 2
      color: Theme.clear
      border.width: Math.max(1.5, root.size * root.cRimWidth)
      border.color: Qt.rgba(root.cRimColour.r, root.cRimColour.g, root.cRimColour.b, 0.85)
    }
    Rectangle {
      visible: root.cShine
      x: root.size * 0.2; y: root.size * 0.1
      width: root.size * 0.42; height: root.size * 0.2
      radius: height / 2
      rotation: -28
      color: Qt.rgba(1, 1, 1, 0.1)
    }

    // little stars around it, twinkling out of step
    Repeater {
      model: root.cSparkles
      Rectangle {
        id: star
        required property int index
        readonly property real ang: [0.5, 1.3, 2.4, 3.5, 4.4, 5.5, 0.9, 2.0, 3.0, 5.0][index]
        readonly property real dist: root.size * [0.78, 0.92, 0.74, 0.88, 0.8, 0.95, 0.86, 0.72, 0.9, 0.76][index]
        width: Math.max(1.5, root.size * (index % 2 ? 0.04 : 0.055))
        height: width
        radius: width / 2
        x: root.size / 2 + Math.cos(ang) * dist - width / 2
        y: root.size / 2 + Math.sin(ang) * dist - height / 2
        color: root.cSparkleColour
        opacity: 0.5
        SequentialAnimation on opacity {
          running: Motion.bar && root.visible
          loops: Animation.Infinite
          PauseAnimation { duration: star.index * 330 }
          NumberAnimation { to: 1; duration: 700 + star.index * 90; easing.type: Easing.InOutSine }
          NumberAnimation { to: 0.1; duration: 900 + star.index * 110; easing.type: Easing.InOutSine }
        }
      }
    }

    Repeater {
      model: 2
      Item {
        id: eye
        required property int index
        // looking aside slides the eyes across the sphere and narrows them, as if it turned
        readonly property real eyeW: root.size * 0.125 * root.cEyeW * root.eW * (1 - Math.abs(root.eyeX) * 0.18)
        readonly property real eyeH: root.size * 0.34 * root.cEyeH * root.eH * (index === 0 ? root.eHL : root.eHR)
        width: eyeW
        height: eyeH
        x: body.width * (0.5 + (index === 0 ? -0.14 : 0.14) * root.cEyeGap) - eyeW / 2 + root.eyeX * root.size * 0.15
        y: body.height * (0.42 + root.eDy) - eyeH / 2 + root.eyeY * root.size * 0.1
        rotation: (index === 0 ? root.eRotL + root.cEyeTilt : root.eRotR - root.cEyeTilt) + root.eyeX * 12

        // the capsule; lids cut it from the top and the bottom, a blink squeezes it
        Item {
          id: pill
          anchors.fill: parent
          opacity: root.arcs || root.spirals ? 0 : 1
          visible: opacity > 0
          Behavior on opacity { enabled: Motion.bar; NumberAnimation { duration: 90 } }
          transform: Scale { origin.x: pill.width / 2; origin.y: pill.height / 2; yScale: Math.max(0.08, 1 - root.lidShown) }
          Item {
            id: cut
            clip: root.eTop > 0.005 || root.eBottom > 0.005
            width: pill.width
            y: pill.height * root.eTop
            height: Math.max(pill.width * 0.5, pill.height * (1 - root.eTop - root.eBottom))
            Rectangle {
              y: -cut.y
              width: pill.width
              height: pill.height
              radius: width / 2
              color: root.eyeColor
            }
          }
        }

        // ^ : shut with joy
        Shape {
          id: arc
          anchors.centerIn: parent
          width: eye.eyeH * 0.78
          height: eye.eyeH * 0.46
          rotation: -eye.rotation + (eye.index === 0 ? -10 : 10)
          opacity: root.arcs ? 1 : 0
          visible: opacity > 0
          Behavior on opacity { enabled: Motion.bar; NumberAnimation { duration: 110 } }
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            strokeColor: root.eyeColor
            strokeWidth: Math.max(1.5, eye.eyeW * 0.78)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
              centerX: arc.width / 2; centerY: arc.height
              radiusX: Math.max(1, arc.width / 2 - eye.eyeW * 0.4); radiusY: Math.max(1, arc.height - eye.eyeW * 0.4)
              startAngle: 180; sweepAngle: 180
            }
          }
        }

        // @ : dizzy, turning
        Shape {
          id: swirl
          anchors.centerIn: parent
          width: eye.eyeH * 0.7
          height: width
          opacity: root.spirals ? 1 : 0
          visible: opacity > 0
          Behavior on opacity { enabled: Motion.bar; NumberAnimation { duration: 110 } }
          preferredRendererType: Shape.CurveRenderer
          RotationAnimator on rotation {
            running: swirl.visible && Motion.bar
            loops: Animation.Infinite
            from: eye.index === 0 ? 0 : 360; to: eye.index === 0 ? 360 : 0
            duration: 900
          }
          ShapePath {
            strokeColor: root.eyeColor
            strokeWidth: Math.max(1.2, eye.eyeW * 0.42)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathPolyline {
              path: {
                const pts = [], n = 28, r = swirl.width / 2 - 1;
                for (let i = 0; i <= n; i++) {
                  const t = i / n, a = t * Math.PI * 4;
                  pts.push(Qt.point(swirl.width / 2 + Math.cos(a) * r * t, swirl.height / 2 + Math.sin(a) * r * t));
                }
                return pts;
              }
            }
          }
        }
      }
    }
  }
}
