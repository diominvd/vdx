import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config
import "steer.js" as Steer
import "mind.js" as Mind

// Kimmy's head: where it is, what it wants, how it feels, what it mumbles. No drawing
// here; the window draws the ball at (px, py), lifted by `air`, and shows the words.
//
// It is built on what it wants and how it feels, not on a timeline:
//   moods       energy, affection, curiosity, grumpy (mind.js): slow, drift back to the
//               temper's own values over minutes, pushed by what happens, and they pick
//               every reply: the same poke gets a giggle or a huff
//   memory      this session only: how much it played (tired and content), how much it
//               was stroked (clingy), how often it was ignored (sulks longer)
//   need        rises while nobody pays it attention; above a soft limit each second
//               carries a chance that it goes to the pointer: never the same minute twice
//   touch       a press gives under the finger; a click is a poke; a double click a
//               trick; a hold is being held (it dozes off, settles or squirms out); a
//               drag carries it (it hangs and swings, enjoys it or panics); let go fast
//               and it is thrown: it flies, bounces off the walls, rolls over, rights
//               itself, shakes off and says what it thought of that; strokes over it
//               (back and forth) make it purr
//   play        at the pointer it orbits, chases, dashes, pounces when the pointer
//               stops, stalks up behind a moving one and says "boo", hides behind a
//               screen edge and peeks, begs for another throw
//   the world   Hyprland's own events (no polling): a window opens (it looks there and
//               hops), closes (waves), takes the focus (a glance), the workspace changes
// Every move has a beginning and an end: eyes first, a gather, the go, an overshoot,
// a settle. Timing comes from distributions, picks never repeat back to back.
//
// The pointer is asked of Hyprland on a timer that is slow at home and stops with the
// setting "Watch the pointer". Frames run only while it moves, is carried or flies.
Item {
  id: root

  required property var ball
  required property real screenX
  required property real screenY
  required property real screenW
  required property real screenH
  required property point home
  required property real petR
  property string screenName: ""       // the screen it is on now
  property var screens: []              // every screen: {name, x, y, w, h}, layout pixels
  property bool windowReady: false      // the window is the whole screen: it may leave home
  property bool follow: true
  property bool speech: true
  property string temper: "playful"     // calm | playful | clingy

  // ---- tuning ----
  readonly property real runSpeed: 520
  readonly property real playSpeed: 300
  readonly property real homeSpeed: 380
  readonly property real safeGap: 12    // the least between its edge and the pointer
  readonly property real needRate: temper === "clingy" ? 1 / 25 : 1 / 50      // per second
  readonly property real flickPx: 170   // a pointer jump between two looks that startles
  readonly property real liftPx: 16     // how high it hangs when picked up
  readonly property real throwSpeed: 460 // px/s at release above which it is thrown, not put down
  readonly property real gravity: 2600

  // ---- where it is ----
  property real px: home.x
  property real py: home.y
  property real vx: 0
  property real vy: 0
  property real tx: home.x
  property real ty: home.y
  property real air: 0                    // px above the ground: carried, a leap, a throw
  property real vz: 0
  property real maxSpeed: playSpeed
  property bool moving: false
  // home | windup | out | pester | roam | back | nap | held | flying | dazed
  property string doing: "home"
  property string act: ""
  // the window grows when the ball is touched, not when the pointer comes near: a resize on hover made it jump
  readonly property bool wantFull: doing !== "home" || touching
  property real runPhase: 0
  property real wanderT: 0
  property real doingFor: 0             // s in this `doing`
  onDoingChanged: doingFor = 0

  // ---- the pointer ----
  property real cx: -1
  property real cy: -1
  property real lastCx: -1
  property real lastCy: -1
  property bool cursorOn: false
  property real cursorIdle: 0           // s the pointer has held still
  property real cSpeed: 0               // px/s, smoothed
  property real cDirX: 1                // where it last went, a unit vector
  property real cDirY: 0
  property real napX: 0
  property real napY: 0
  property real orbitAngle: 0

  // ---- what it wants and how it feels ----
  // what it remembers from other days (CompanionMemory): friends feel warmer than strangers
  CompanionMemory { id: mem; onReady: root.meet() }
  // ---- the mood of the day ----
  // It wakes up in some mood and keeps it for a few hours: lazy, cheery, grumpy, clingy,
  // curious, playful. A friend cannot be the same all day, every day.
  readonly property var dayMoods: ({
    playful: { shift: { energy: 0.12, curiosity: 0.08, grumpy: -0.04 }, w: 3, said: "dayPlayful" },
    lazy:    { shift: { energy: -0.22, curiosity: -0.1 }, w: 2, said: "dayLazy" },
    cheery:  { shift: { affection: 0.12, grumpy: -0.08, energy: 0.05 }, w: 3, said: "dayCheery" },
    grumpy:  { shift: { grumpy: 0.25, affection: -0.1 }, w: 1, said: "dayGrumpy" },
    clingy:  { shift: { affection: 0.2, energy: -0.05 }, w: 2, said: "dayClingy" },
    curious: { shift: { curiosity: 0.22 }, w: 2, said: "dayCurious" }
  })
  readonly property real moodHours: 6
  function rollMood(announce) {
    const names = Object.keys(dayMoods);
    // the closer you are, the less often it wakes up grumpy
    const ws = names.map(n => dayMoods[n].w * (n === "grumpy" ? Math.max(0.2, 1.2 - mem.bond * 1.4) : 1));
    let r = Math.random() * ws.reduce((a, b) => a + b, 0), pick = names[0];
    for (let i = 0; i < names.length; i++) { r -= ws[i]; if (r <= 0) { pick = names[i]; break; } }
    mem.setMood(pick);
    const d = dayMoods[pick].shift;
    for (const k in d) m[k] = Math.max(0, Math.min(1, m[k] + d[k] * 0.8));
    ball.energy = m.energy;
    if (announce) later(300, function() { root.say(dayMoods[pick].said, true); });
  }
  function checkMood() {
    if (mem.moodAt === 0 || !dayMoods[mem.mood] || Date.now() - mem.moodAt > moodHours * 3600000) rollMood(mem.moodAt !== 0);
  }

  // ---- how close it feels ----
  // The bond grows over weeks; each step it crosses is a small event and opens something:
  // a stranger is shy and keeps its distance, a friend comes to sit by you, a best friend
  // does not startle at your hand.
  readonly property int stage: mem.bond >= 0.8 ? 3 : mem.bond >= 0.5 ? 2 : mem.bond >= 0.3 ? 1 : 0
  function checkStage() {
    if (stage > mem.stage) {
      mem.setStage(stage);
      later(500, function() {
        root.ball.express(stage >= 3 ? "glee" : "happy", 2400);
        root.ball.emote("heart");
        root.say(stage >= 3 ? "stageBest" : stage === 2 ? "stageFriend" : "stageKnow", true);
      });
    } else if (stage < mem.stage) mem.setStage(stage);
  }
  onStageChanged: if (mem.loaded) checkStage()

  function base() {
    const b = Mind.baseFor(temper);
    b.affection = Math.max(0, Math.min(1, b.affection + (mem.bond - 0.3) * 0.35));
    b.grumpy = Math.max(0, b.grumpy - (mem.bond - 0.3) * 0.12);
    const d = dayMoods[mem.mood];
    if (d) for (const k in d.shift) b[k] = Math.max(0, Math.min(1, b[k] + d.shift[k]));
    return b;
  }
  property var m: Mind.baseFor(temper)
  property real need: 0.45
  property real attention: 0.5
  property real lowFor: 0               // s the attention has been low
  property real pesterLeft: 0
  property real actLeft: 0
  property real sleepLeft: 0
  property real shyCooldown: 0
  property real played: 0               // fades: lots of play lately → tired and content
  property real petted: 0               // fades: stroked a lot lately → clingy
  property int ignored: 0               // sulks in a row
  property real sulkLeft: 0             // s it still sulks at home
  property bool begging: false          // it liked the throw: the next act asks for another
  property var recentActs: []
  property var recentSaid: []
  property double speechAfter: 0
  readonly property bool sulking: sulkLeft > 0

  signal said(string text)
  // it hops over to another monitor: the window moves there, then rebase()
  signal crossRequest(string name, real gx, real gy)

  // ---- things to do a little later: a queue, so a plan can have several beats ----
  property var queue: []
  Timer {
    id: laterTimer
    onTriggered: {
      const now = Date.now() + 4;
      const due = root.queue.filter(q => q.at <= now);
      root.queue = root.queue.filter(q => q.at > now);
      for (const q of due) q.fn();
      root.schedule();
    }
  }
  function later(ms, fn) { queue.push({ at: Date.now() + ms, fn: fn }); schedule(); }
  function cancelPlans() { queue = []; laterTimer.stop(); }
  function schedule() {
    if (!queue.length) { laterTimer.stop(); return; }
    let next = queue[0].at;
    for (const q of queue) next = Math.min(next, q.at);
    laterTimer.interval = Math.max(1, next - Date.now());
    laterTimer.restart();
  }

  // ---- the voice ----
  // force: a reply to something, said now. Otherwise only when it has been quiet a while.
  // Either way some kinds are often left unsaid; a pick is never one of the last dozen.
  function say(kind, force) {
    if (!speech) return;
    const list = Steer.phrases[kind];
    if (!list) return;
    const now = Date.now();
    if (!force && now < speechAfter) return;
    const quiet = Steer.quiet[kind] ?? 0.15;
    if (Math.random() < (force ? quiet * 0.5 : quiet)) return;
    const text = Mind.pickFresh(list, recentSaid);
    recentSaid = recentSaid.concat([text]).slice(-12);
    speechAfter = now + Mind.jitter(7000, 0.4);
    said(text);
  }

  function setGoal(x, y, speed) {
    tx = Steer.clamp(x, petR, screenW - petR);
    ty = Steer.clamp(y, petR, screenH - petR);
    maxSpeed = speed;
    moving = true;
  }
  // past the edge a little: only to hide
  function setGoalFree(x, y, speed) {
    tx = Steer.clamp(x, -petR * 0.6, screenW + petR * 0.6);
    ty = Steer.clamp(y, petR, screenH + petR * 0.6);
    maxSpeed = speed;
    moving = true;
  }
  function look(x, y, ms) {
    const dx = x - px, dy = y - py, d = Math.max(1, Math.hypot(dx, dy));
    ball.lookAt(dx / d, dy / d * 0.8, ms);
  }
  function nudge(kind, amount) { Mind.nudge(m, kind, amount); ball.energy = m.energy; mem.moment(kind); }
  // held, flying or getting over it: the world waits
  readonly property bool bodyBusy: doing === "held" || doing === "flying" || doing === "dazed"

  // ---- the pointer: asked of Hyprland ----
  // hyprctl answers "x, y" in layout pixels; a stale HYPRLAND_INSTANCE_SIGNATURE in the
  // shell's environment (a session restarted under it) falls back to the newest instance.
  Process {
    id: cursorProc
    command: ["sh", "-c", "hyprctl cursorpos 2>/dev/null || HYPRLAND_INSTANCE_SIGNATURE=$(ls -t \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr\" | head -1) hyprctl cursorpos 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = text.match(/(-?\d+)\s*,\s*(-?\d+)/);
        if (m) root.onCursor(parseInt(m[1], 10) - root.screenX, parseInt(m[2], 10) - root.screenY);
      }
    }
  }
  Timer {
    id: poll
    running: root.follow && Motion.bar && !root.touching
    repeat: true
    triggeredOnStart: true
    interval: root.doing !== "home" ? 90 : root.ball.asleep ? 1500 : 300
    onTriggered: if (!cursorProc.running) cursorProc.running = true
  }

  function onCursor(x, y) {
    const jump = lastCx < 0 ? 0 : Math.hypot(x - lastCx, y - lastCy);
    const span = poll.interval / 1000;
    cursorIdle = jump < 5 ? cursorIdle + span : 0;
    cSpeed = cSpeed * 0.55 + (jump / span) * 0.45;
    if (jump > 3) { cDirX = cDirX * 0.5 + (x - lastCx) / jump * 0.5; cDirY = cDirY * 0.5 + (y - lastCy) / jump * 0.5; const n = Math.max(0.01, Math.hypot(cDirX, cDirY)); cDirX /= n; cDirY /= n; }
    lastCx = x; lastCy = y;
    cx = x; cy = y;
    const wasOn = cursorOn;
    cursorOn = x >= 0 && y >= 0 && x <= screenW && y <= screenH;
    const there = Steer.screenAt(screens, x + screenX, y + screenY);
    cursorScreen = there ? there.name : "";
    if (bodyBusy) return;
    const dx = x - px, dy = y - py, d = Math.hypot(dx, dy);

    // the eyes: the pointer's direction, nearer means more turned; going home, ahead;
    // sulking, anywhere but at you
    let gx = dx, gy = dy, gd = d;
    if (doing === "back") { gx = tx - px; gy = ty - py; gd = Math.hypot(gx, gy); }
    ball.pointerNear = follow;
    if (gd > 1) {
      const strength = Math.min(1, gd / (petR * 3));
      const away = sulking ? -0.8 : 1;
      ball.pointerX = gx / gd * strength * away;
      ball.pointerY = gy / gd * strength * (sulking ? 0.3 : 1);
    }

    if (doing === "tag") { if (cursorOn && d < petR * 1.1) tagCaught(); else if (cursorOn && d < 360) tagFlee(d); return; }
    if (d < 110 && cursorOn) { passed = 0; if (doing === "pester") attention = Math.min(1, attention + 0.04); }
    if (cursorOn && !wasOn && doing === "home" && !ball.asleep && !sulking) { ball.react("happy"); say("glad"); }

    // a slow hand coming close: it leans toward it, then looks up at it
    if (cursorOn && doing === "home" && !ball.asleep && !ball.dozing && !sulking && Date.now() > coaxAfter) {
      const c = Steer.coax(d, cSpeed, -(cDirX * dx + cDirY * dy) / Math.max(1, d), petR);
      if (c > 0.35) {
        coaxAfter = Date.now() + 2600;
        ball.tilt = (dx >= 0 ? 1 : -1) * (3 + c * 4);
        ball.lookAt(dx / Math.max(1, d), dy / Math.max(1, d) * 0.8, 1200);
        if (Math.random() < 0.3) ball.express("curious", 900);
      }
    }
    // a flick past it: it startles and shies off a little
    if (cursorOn && jump > flickPx * (stage === 0 ? 0.65 : stage >= 3 ? 1.5 : 1) && d < 260 && shyCooldown <= 0 && doing !== "cross" && doing !== "windup" && doing !== "nap" && act !== "stalk") {
      shyCooldown = 7;
      ball.react("surprised");
      say("shy", true);
      if (doing !== "home") { const p = Steer.standOff(px, py, cx, cy, 170); setGoal(p.x, p.y, runSpeed); act = "retreat"; actLeft = 1.4; }
    }
    if (doing === "nap" && Math.hypot(x - napX, y - napY) > 140) wakeNap();
    else if (ball.dozing && doing === "nap" && jump > 30) { ball.rouse(); doing = "pester"; act = "peek"; actLeft = 2; }
    // hidden behind an edge: the pointer came looking
    if (doing === "pester" && act === "hide" && !moving && d < 240) peekaboo();
  }
  property real passed: 0
  property double coaxAfter: 0

  // ---- frames: only while something moves ----
  FrameAnimation {
    running: root.windowReady && (root.moving || root.doing === "held" && root.dragging || root.doing === "flying" || root.air > 0 || root.vz > 0)
    onTriggered: {
      const dt = Math.min(frameTime, 0.05);
      if (root.doing === "held") root.dragStep(dt);
      else if (root.doing === "flying") root.flyStep(dt);
      else root.runStep(dt);
    }
  }

  function runStep(dt) {
    // a leap: the body goes up and comes down, whatever the feet do
    if (air > 0 || vz > 0) {
      vz -= gravity * dt;
      air = Math.max(0, air + vz * dt);
      if (air === 0) { if (vz < -150) ball.land(Math.min(0.8, -vz / 900)); vz = 0; }
      ball.lift = air;
    }
    if (!moving) return;
    wanderT += dt;
    followTarget(dt);
    // not a ruler line: it swings to one side and the other, and its speed breathes
    const goal = Steer.swing(px, py, tx, ty, wanderT * 1.4, doing === "back" ? 18 : act === "stalk" || act === "pounce" ? 6 : 55);
    const pace = maxSpeed * (0.8 + 0.2 * Math.sin(wanderT * 0.9 + 1.3)) * (0.65 + m.energy * 0.55);
    const r = Steer.step(px, py, vx, vy, goal.x, goal.y, dt, pace, 6, 8);
    px = r.x; py = r.y; vx = r.vx; vy = r.vy;
    const speed = Math.hypot(r.vx, r.vy);
    runPhase += dt * speed / 26;
    ball.speedFrac = Math.min(1, speed / runSpeed);
    ball.lean = Steer.clamp(r.vx / runSpeed * 18, -18, 18);
    ball.bounce = speed > 40 && air === 0 && !ball.sneaking ? Math.abs(Math.sin(runPhase)) * petR * 0.3 * Math.min(1, speed / 200) : 0;
    arrived(Math.hypot(tx - px, ty - py), speed);
  }

  // targets that move with the pointer are recomputed every frame
  function followTarget(dt) {
    if (doing === "out") {
      const p = Steer.standOff(cx, cy, px, py, petR + safeGap + 44);
      setGoal(p.x, p.y, runSpeed);
    } else if (doing === "pester") {
      if (act === "orbit") {
        orbitAngle += dt * (1.1 + 0.8 * Math.sin(wanderT * 0.6));
        const p = Steer.orbit(cx, cy, petR + safeGap + 46 + 14 * Math.sin(wanderT), orbitAngle);
        setGoal(p.x, p.y, playSpeed + 120);
      } else if (act === "follow") {
        const p = Steer.standOff(cx, cy, px, py, petR + safeGap + 60);
        setGoal(p.x, p.y, runSpeed - 100);
      } else if (act === "stalk") {
        // behind the pointer, where it is not looking, slowly
        setGoal(cx - cDirX * 130, cy - cDirY * 130, 150 + m.energy * 60);
      }
    }
  }

  function stopHere() {
    moving = false;
    vx = 0; vy = 0;
    ball.speedFrac = 0; ball.lean = 0; ball.bounce = 0;
  }

  // it does not stop dead: a squat on arrival, harder the faster it came
  function settle(fast) { ball.land(0.25 + Math.min(0.5, fast / 900)); }

  property real roamPause: 0
  property real hesitateIn: 2 + Math.random() * 2
  property bool leaping: false
  property point pounceAt: Qt.point(0, 0)
  function arrived(dist, speed) {
    // a long way, and it stops to look, now and then
    if ((doing === "out" || doing === "back") && dist > 260 && speed > 200) {
      hesitateIn -= 1 / 60;
      if (hesitateIn <= 0) {
        hesitateIn = 2.5 + Math.random() * 3;
        if (Math.random() < 0.45) { pauseAndLook(); return; }
      }
    }
    if (doing === "cross" && crossPlan !== null && dist < 10 && speed < 60) { atEdge(); return; }
    // the pointer went to another monitor while it chased: it follows
    if ((doing === "out" || doing === "pester") && cursorScreen !== "" && cursorScreen !== screenName && !cursorOn) {
      if (startCross(cursorScreen, "out")) return;
    }
    if (doing === "out" && Math.hypot(cx - px, cy - py) < petR + safeGap + 90) {
      settle(speed);
      doing = "pester";
      attention = 0.5;
      lowFor = 0;
      pesterLeft = (temper === "clingy" ? 40 + Math.random() * 40 : 25 + Math.random() * 30) * (0.6 + m.affection * 0.8);
      ball.react("happy");
      say("pester", true);
      nextAct();
    } else if (doing === "back" && dist < 3 && speed < 12) {
      px = home.x; py = home.y;
      settle(speed);
      stopHere();
      arriveHome();
    } else if (doing === "roam" && dist < 10 && speed < 40) {
      settle(speed);
      stopHere();
      if (visit !== null) { inspect(); return; }
      const r = Math.random();
      ball.react(r < 0.4 ? "curious" : r < 0.7 ? "happy" : "mischief");
      if (Math.random() < 0.5) say("idle");
      roamPause = Mind.jitter(1.6, 0.5);
    } else if (doing === "pester" && (act === "dash" || act === "retreat") && dist < 8 && speed < 60) {
      settle(speed);
      actLeft = Math.min(actLeft, 0.3);
    } else if (doing === "pester" && act === "pounce" && leaping && dist < 10 && air === 0) {
      leaping = false;
      stopHere();
      settle(400);
      const caught = Math.hypot(cx - pounceAt.x, cy - pounceAt.y) < 70;
      if (caught) { ball.express("glee", 1100); say("caught", true); played += 0.5; nudge("play"); }
      else { ball.express("sad", 1000); say("missed", true); }
      actLeft = Mind.jitter(1.3, 0.3);
    } else if (doing === "pester" && act === "hide" && dist < 6 && speed < 40) {
      stopHere();
      ball.express("mischief", 9000);
      ball.lookAt(0, 0, 0);
    }
  }

  function arriveHome() {
    doing = "home";
    exploring = false; visit = null;
    need = 0;
    const tired = played > 2.5 || m.energy < 0.4;
    if (sulking) { ball.sulk = 1; return; }
    ball.sulk = 0;
    if (tired) {
      ball.express(played > 2.5 ? "purr" : "sleepy", 1400);
      say(played > 2.5 ? "played" : "yawn", true);
      ball.getSleepy(Mind.jitter(played > 2.5 ? 6000 : 10000, 0.25));
      sleepLeft = 120 + Math.random() * 180;
    } else if (Math.random() < 0.5) { say("home"); ball.wave(); }
  }

  // stands still a moment on the way, looking at the pointer, then goes on
  function pauseAndLook() {
    const was = moving;
    const resume = doing;
    stopHere();
    ball.react("curious");
    later(Mind.jitter(700, 0.3), function() {
      if (root.doing === resume) { root.moving = was; if (resume === "back") root.setGoal(root.home.x, root.home.y, root.homeSpeed * (root.ball.sulk > 0.3 ? 0.6 : 1)); }
    });
  }

  // ---- acts at the pointer ----
  function nextAct() {
    ball.sneaking = false;
    leaping = false;
    const last = act;
    let a = last === "dash" ? "retreat" : Mind.pickWeighted(Mind.actWeights(m, cSpeed, cursorIdle, begging), recentActs.slice(-2));
    begging = false;
    recentActs = recentActs.concat([a]).slice(-4);
    act = a;
    if (a === "orbit") { orbitAngle = Math.atan2(py - cy, px - cx); actLeft = Mind.jitter(4, 0.3); ball.react("mischief"); }
    else if (a === "follow") { actLeft = Mind.jitter(5, 0.35); }
    else if (a === "dash") {
      stopHere();
      look(cx, cy, 600);
      ball.crouch();
      ball.react("mischief");
      actLeft = 2.4;
      later(Mind.jitter(380, 0.2), function() {
        if (root.doing !== "pester" || root.act !== "dash") return;
        const p = Steer.standOff(root.cx, root.cy, root.px, root.py, root.petR + root.safeGap + 2);
        root.setGoal(p.x, p.y, root.runSpeed + 160);
      });
    } else if (a === "retreat") {
      const ang = Math.random() * Math.PI * 2;
      setGoal(cx + Math.cos(ang) * 220, cy + Math.sin(ang) * 220, runSpeed);
      actLeft = 1.8;
      say("pester");
    } else if (a === "peek") {
      stopHere();
      actLeft = Mind.jitter(3, 0.35);
      ball.react("mischief");
    } else if (a === "pounce") {
      // eyes lock on, the butt wiggles, then the leap to where the pointer was
      stopHere();
      look(cx, cy, 1600);
      ball.express("focus", 1700);
      actLeft = 4;
      if (Math.random() < 0.3) say("ready", true);
      later(Mind.jitter(380, 0.3), function() { if (root.act === "pounce") root.ball.ready(); });
      later(Mind.jitter(950, 0.2), function() {
        if (root.doing !== "pester" || root.act !== "pounce") return;
        root.pounceAt = Qt.point(root.cx, root.cy);
        const p = Steer.standOff(root.cx, root.cy, root.px, root.py, root.petR + 6);
        root.ball.squash = -0.4;
        root.setGoal(p.x, p.y, root.runSpeed + 420);
        root.vz = 380 + Math.random() * 120;
        root.air = 0.1;
        root.leaping = true;
        root.actLeft = 2.5;
      });
    } else if (a === "stalk") {
      ball.sneaking = true;
      ball.express("focus", 9000);
      actLeft = Mind.jitter(6, 0.3);
      say("stalk");
    } else if (a === "hide") {
      const s = Mind.hideSpot(px, py, screenW, screenH, petR);
      setGoalFree(s.x, s.y, runSpeed);
      actLeft = Mind.jitter(8, 0.3);
      say("hide");
    } else if (a === "beg") {
      stopHere();
      look(cx, cy, 2500);
      ball.express("happy", 1200);
      actLeft = Mind.jitter(6, 0.25);
    } else {
      stopHere();
      actLeft = 1.2;
      ball.react("happy");
    }
  }

  // found behind its edge: out it pops
  function peekaboo() {
    ball.jolt();
    ball.express("glee", 900);
    say("peekaboo", true);
    act = "retreat";
    const ang = Math.atan2(py - cy, px - cx) + (Math.random() - 0.5);
    setGoal(screenW / 2 + (cx - screenW / 2) * 0.3 + Math.cos(ang) * 120, screenH / 2 + Math.sin(ang) * 120, runSpeed + 60);
    actLeft = 1.6;
  }

  // ---- touch ----
  // A press gives under the finger at once. What it becomes is told by what follows:
  // moved > 6 px → carried; held 0.28 s → held; let go before → a poke; a second
  // press at once → a trick.
  property bool touching: false
  property bool dragging: false
  property bool hovering: false
  property bool slipped: false          // it wriggled out of the hand: the rest of this press is nothing
  property bool swallowUp: false        // the release of a double click
  property real gpx: 0                  // the hand, screen pixels
  property real gpy: 0
  property real downX: 0
  property real downY: 0
  property double downAt: 0
  property real hangX: 0
  property real hangY: 0
  property string heldFrom: "home"
  property var samples: []
  property real agitation: 0
  property real carried: 0              // s carried this time
  property bool shaken: false
  property bool panicSaid: false
  property bool funSaid: false
  property bool wasAsleep: false
  property real holdS: 0
  property string holdMood: ""
  property var pokes: []

  function touchDown(x, y) {
    if (doing === "tag") tagCaught();
    touching = true;
    dragging = false;
    slipped = false;
    downAt = Date.now();
    downX = x; downY = y; gpx = x; gpy = y;
    samples = [{ x: x, y: y, t: downAt }];
    wasAsleep = ball.asleep || ball.dozing;
    ball.pressIn();
    if (Motion.bar) holdWait.restart();
  }
  Timer { id: holdWait; interval: 280; onTriggered: if (root.touching && !root.dragging) root.beginHold() }

  function touchMove(x, y) {
    if (!touching || slipped) return;
    gpx = x; gpy = y;
    samples.push({ x: x, y: y, t: Date.now() });
    if (samples.length > 10) samples.shift();
    if (!dragging && Motion.bar && Math.hypot(x - downX, y - downY) > 6) beginDrag();
  }

  function takeHold() {
    cancelPlans();
    exploring = false; visit = null;
    if (doing !== "held") heldFrom = doing === "flying" || doing === "dazed" ? "pester" : doing;
    doing = "held";
    act = "";
    ball.sneaking = false;
    ball.busy = true;
    leaping = false;
    holdS = 0;
    holdMood = "";
  }

  function beginDrag() {
    holdWait.stop();
    const midAir = doing === "flying";
    takeHold();
    dragging = true;
    hangX = px - gpx; hangY = py - gpy;
    if (!midAir) { vx = 0; vy = 0; }
    vz = 0;
    agitation = 0; carried = 0; shaken = false; panicSaid = false; funSaid = false;
    ball.rouse();
    ball.squeeze(false);
    ball.rolling = false;
    ball.rightItself();
    if (midAir) { ball.express("glee", 700); say("caughtMe", true); }
    else if (wasAsleep) { ball.express("panic", 900); say("grabbedAsleep", true); nudge("shaken", 0.5); }
    else { ball.express("surprised", 450); say("grabbed"); }
    nudge("carry");
  }

  function beginHold() {
    takeHold();
    stopHere();
    ball.squeeze(true);
    if (!wasAsleep) { look(gpx, gpy - petR * 3, 900); }
  }
  // being held still: after a moment it makes up its mind about it
  Timer {
    interval: 250
    repeat: true
    running: root.touching && root.doing === "held" && !root.dragging && !root.slipped
    onTriggered: root.holdTick(0.25)
  }
  function holdTick(dt) {
    holdS += dt;
    if (holdMood === "" && holdS >= 0.9) {
      holdMood = Mind.holdReply(m, wasAsleep, Math.random());
      if (holdMood === "doze") {
        if (!wasAsleep) { ball.express("doze", 60000); say("doze", true); }
        nudge("stroke", 0.5);
      } else if (holdMood === "content") { ball.express("purr", 60000); ball.slowBlink(); say("handOk"); nudge("stroke", 0.4); }
      else { ball.express("offended", 60000); say("squirm", true); }
      squirmAt = holdS + Mind.jitter(0.5, 0.3);
      slipAt = holdS + Mind.jitter(2.4, 0.3);
    }
    if (holdMood === "squirm") {
      if (holdS >= squirmAt) { ball.wave(); ball.squash = 0.5; squirmAt = holdS + Mind.jitter(0.7, 0.35); }
      if (holdS >= slipAt) slipOut();
    } else if (holdMood === "content" && holdS > 6 && m.energy < 0.6) { holdMood = "doze"; ball.express("doze", 60000); }
  }
  property real squirmAt: 0
  property real slipAt: 0
  // out of the hand with a pop, a little way off, pleased with itself
  function slipOut() {
    slipped = true;
    ball.squeeze(false);
    ball.busy = false;
    ball.express("smug", 1600);
    say("slip", true);
    nudge("poke", 0.5);
    const ang = Math.random() * Math.PI * 2;
    doing = heldFrom === "home" ? "back" : "pester";
    act = "retreat";
    if (heldFrom === "home") { setGoal(home.x, home.y, homeSpeed); }
    else setGoal(px + Math.cos(ang) * 120, py + Math.sin(ang) * 90, runSpeed);
    vz = 360; air = 0.1;
    actLeft = 1.6;
  }

  function touchUp(x, y) {
    if (!touching) return;
    touching = false;
    holdWait.stop();
    if (swallowUp) { swallowUp = false; return; }
    if (slipped) { slipped = false; return; }
    if (dragging) { dragging = false; release(); return; }
    if (doing === "held") { putDown(); return; }
    poke();
  }

  // held and let go where it is
  function putDown() {
    ball.squeeze(false);
    ball.busy = false;
    if (holdMood === "doze") {
      if (heldFrom === "home") { doing = "home"; ball.sleepNow(); sleepLeft = 60 + Math.random() * 120; }
      else { doing = "nap"; napX = gpx; napY = gpy; ball.relax(); ball.drowsy = 0.7; ball.getSleepy(2500); }
      return;
    }
    ball.relax();
    if (holdMood === "content" || holdMood === "") { if (Math.random() < 0.6) ball.slowBlink(); }
    if (heldFrom === "home") doing = "home";
    else { doing = "pester"; act = "peek"; actLeft = 1.5; pesterLeft = Math.max(pesterLeft, 6); }
  }

  // ---- carried ----
  property real dragMoodIn: 0
  function dragStep(dt) {
    carried += dt;
    // it hangs below the hand: the grab point slides to its top
    const k0 = Math.min(1, dt * 3);
    hangX += (0 - hangX) * k0;
    hangY += (petR * 0.35 - hangY) * k0;
    const gx = gpx + hangX, gy = gpy + hangY;
    // a spring with give: it trails the hand and swings past it
    const ax = (gx - px) * 240 - vx * 16, ay = (gy - py) * 240 - vy * 16;
    const ovx = vx, ovy = vy;
    vx += ax * dt; vy += ay * dt;
    const rc = reach(px, py);
    px = Steer.clamp(px + vx * dt, rc.x0 - petR * 0.5, rc.x1 + petR * 0.5);
    py = Steer.clamp(py + vy * dt, rc.y0 - petR * 0.5, rc.y1 + petR * 0.5);
    agitation = Mind.agitate(agitation, vx - ovx, vy - ovy, dt);
    const sx = px - gpx, sy = py - gpy;
    ball.lean = Steer.clamp(-Math.atan2(sx, Math.max(4, sy)) * 57.3 * 0.85, -42, 42);
    ball.flowX = Steer.clamp(Math.abs(vx) / 6000 - Math.abs(vy) / 11000, -0.12, 0.2);
    ball.flowY = Steer.clamp(Math.abs(vy) / 6000 - Math.abs(vx) / 11000, -0.12, 0.2);
    air += (liftPx - air) * Math.min(1, dt * 10);
    ball.lift = air;
    dragMoodIn -= dt;
    if (dragMoodIn > 0) return;
    dragMoodIn = 0.22;
    const speed = Math.hypot(vx, vy);
    if (agitation > 0.9) {
      shaken = true;
      ball.express("panic", 700);
      if (!panicSaid) { panicSaid = true; say("panic", true); }
    } else if (speed > 380 && !shaken) {
      const fun = m.energy > 0.3 && m.grumpy < 0.55;
      ball.express(fun ? "glee" : "surprised", 500);
      if (!funSaid && fun) { funSaid = true; say("carryFun"); }
    } else if (speed < 120 && carried > 0.6 && ball.held !== "panic") {
      if (m.affection > 0.55 && !shaken) ball.express("purr", 600);
      else { ball.relax(); look(gpx, gpy - petR * 4, 400); }
    }
  }

  // ---- thrown ----
  property var fl: ({})
  property bool flyThrown: false
  property real flySpeed: 0
  property int walls: 0
  property real turns: 0
  function release() {
    ball.busy = true;
    ball.flowX = 0; ball.flowY = 0; ball.lean = 0;
    const v = Mind.velocity(samples, Date.now(), 90, 70);
    let sp = Math.hypot(v.vx, v.vy);
    const cap = 3200;
    if (sp > cap) { v.vx *= cap / sp; v.vy *= cap / sp; sp = cap; }
    flyThrown = sp > throwSpeed;
    flySpeed = sp;
    walls = 0; turns = 0;
    fl = { x: px, y: py, vx: flyThrown ? v.vx : vx * 0.3, vy: flyThrown ? v.vy : vy * 0.3, z: air, vz: flyThrown ? Math.min(720, sp * 0.3) : 0 };
    doing = "flying";
    ball.rolling = true;
    if (flyThrown) {
      const fun = m.energy > 0.35 && m.grumpy < 0.5;
      ball.express(fun ? "glee" : "panic", 4000);
      ball.sound("whee");
      say("thrown", true);
    }
  }
  function flyStep(dt) {
    const rc = reach(fl.x, fl.y);
    const ev = Mind.fly(fl, dt, { x0: rc.x0, x1: rc.x1, y0: rc.y0, y1: rc.y1 });
    px = fl.x; py = fl.y; air = fl.z;
    ball.lift = air;
    const turn = fl.vx * dt / petR * 57.3 * (fl.z > 0 ? 0.5 : 1);
    ball.roll += turn;
    turns += Math.abs(turn) / 360;
    if (ev.wall > 220) {
      walls++;
      ball.wallHit(ev.side, Math.min(0.8, ev.wall / 1400));
      if (ev.wall > 700) { ball.express(m.grumpy > 0.5 ? "offended" : "surprised", 450); say("bonk", walls === 1); }
    }
    if (ev.ground > 0) ball.land(Math.min(0.8, ev.ground / 800));
    if (fl.done) landed();
  }
  function landed() {
    rehome();
    vx = 0; vy = 0; vz = 0; air = 0;
    ball.lift = 0;
    ball.rolling = false;
    ball.rightItself();
    doing = "dazed";
    const imp = Mind.impact(flySpeed, walls, turns);
    const reply = flyThrown ? Mind.throwReply(m, imp, Math.random()) : shaken ? "dizzy" : "settle";
    later(Mind.jitter(420, 0.25), function() {
      if (root.doing !== "dazed") return;
      if (reply === "dizzy") {
        root.ball.express("dizzy", 1800);
        root.say("dizzy", true);
        root.nudge("shaken", 0.6);
        root.later(Mind.jitter(1900, 0.2), root.recover);
      } else if (reply === "delighted") {
        root.ball.shakeOff();
        root.later(720, function() { root.ball.express("glee", 1200); root.ball.hopBy(0.32); root.say("again", true); });
        root.nudge("throwFun");
        root.played += 1;
        root.begging = true;
        root.later(Mind.jitter(1900, 0.2), root.recover);
      } else if (reply === "grumpy") {
        root.ball.shakeOff();
        root.later(720, function() { root.ball.express("offended", 2200); root.say("grump", true); });
        root.nudge("throwBad");
        root.later(Mind.jitter(2300, 0.2), root.recover);
      } else {
        if (root.carried > 1.2) root.ball.shakeOff();
        else root.ball.lookAt(Math.random() < 0.5 ? -0.8 : 0.8, 0.2, 600);
        if (root.carried > 0.5) root.say("dropped");
        root.later(Mind.jitter(1000, 0.25), root.recover);
      }
    });
  }
  // after it got over it: play on, go home, or rest
  function recover() {
    if (doing !== "dazed") return;
    ball.busy = false;
    const near = Math.hypot(px - home.x, py - home.y) < petR * 1.5;
    const plan = m.grumpy > 0.55 ? "home" : Mind.afterLand(m, played, Math.random());
    if (near && plan !== "play") { doing = "back"; setGoal(home.x, home.y, homeSpeed * 0.5); return; }
    if (plan === "play" && cursorOn && follow) {
      doing = "pester"; attention = 0.7; lowFor = 0;
      pesterLeft = Mind.jitter(18, 0.3);
      nextAct();
    } else if (plan === "rest") { say("played", true); goBack(); }
    else if (m.grumpy > 0.55) { ball.sulk = 0.6; doing = "back"; act = ""; setGoal(home.x, home.y, homeSpeed * 0.6); }
    else goBack();
  }

  // ---- a click ----
  function poke() {
    const now = Date.now();
    pokes = pokes.filter(t => now - t < 6000).concat([now]);
    need = Math.max(0, need - 0.4);
    attention = Math.min(1, attention + 0.4);
    lowFor = 0;
    if (ball.asleep || ball.dozing) {
      ball.rouse();
      ball.jolt();
      ball.express("surprised", 700);
      later(Mind.jitter(600, 0.2), function() {
        if (root.m.grumpy > 0.35) { root.ball.express("sleepy", 1500); root.say("woken", true); }
        else { root.ball.express("curious", 1200); root.say("wake", true); }
      });
      if (doing === "nap") wakeNap();
      return;
    }
    if (doing === "back") { doing = "pester"; pesterLeft = 8; act = "peek"; actLeft = 2; attention = 0.8; stopHere(); }
    else if (doing === "pester") pesterLeft += 6;
    ball.jolt();
    ball.express("surprised", 420);
    if (!Motion.bar) { replyPoke(); return; }
    pokeReplyAt = Mind.jitter(430, 0.2);
    pokeReplyTimer.restart();
  }
  property int pokeReplyAt: 430
  Timer { id: pokeReplyTimer; interval: root.pokeReplyAt; onTriggered: root.replyPoke() }
  function replyPoke() {
    if (bodyBusy) return;
    if (sulking) { ball.express("offended", 1500); ball.lookAt(cx < px ? 0.9 : -0.9, 0.1, 1500); say("huff", true); return; }
    const r = Mind.pokeReply(m, pokes.length, Math.random());
    if (r === "playful") {
      ball.express(Math.random() < 0.5 ? "happy" : "mischief", 1100);
      ball.hopBy(0.24);
      say("pokePlay", true);
      nudge("pokeFun");
      // an invitation: a playful one at home may take it as "let's play"
      if (doing === "home" && temper !== "calm" && m.energy > 0.55 && Math.random() < 0.35) later(Mind.jitter(700, 0.3), function() { if (root.doing === "home") root.decideToGo(); });
    } else if (r === "offended") {
      ball.express("offended", 1500);
      ball.lookAt(cx < px ? 0.9 : -0.9, 0.1, 1300);
      ball.tilt = cx < px ? 6 : -6;
      say("pokeMad", true);
      nudge("poke");
    } else if (r === "dizzy") {
      ball.express("dizzy", 1500);
      say("dizzy", true);
      nudge("poke", 0.5);
    } else {
      ball.rollEyes();
      say("meh", true);
    }
  }

  // ---- a double click: a trick ----
  property string lastTrick: ""
  function trick() {
    pokeReplyTimer.stop();
    swallowUp = touching;
    if (bodyBusy || ball.asleep) return;
    const k = Mind.trickKind(m, lastTrick, Math.random());
    if (k === "refuse") { ball.rollEyes(); say("refuse", true); return; }
    lastTrick = k;
    ball.trick(k);
    played += 0.4;
    nudge("trick");
    later(k === "flip" ? 560 : 760, function() { root.say("trick", true); });
  }

  // ---- strokes ----
  property var strokeX: ({})
  property var strokeY: ({})
  property var beats: []
  property double hoverAt: 0
  property bool trustShown: false
  function hover(on) {
    hovering = on;
    if (on) { hoverAt = Date.now(); trustShown = false; hoverCheck.restart(); }
    else {
      hoverCheck.stop();
      // stroked a lot and left: it wants more
      if (petted > 2.5 && !bodyBusy && !ball.asleep && Date.now() - (beats[beats.length - 1] ?? 0) < 2500) {
        ball.express("sad", 1000);
        say("clingy", true);
        if (doing === "pester") { act = "follow"; actLeft = Mind.jitter(4, 0.3); }
      }
    }
  }
  // the pointer rests on it without stroking: it looks up and gives a slow blink
  Timer {
    id: hoverCheck
    interval: 2400
    onTriggered: {
      if (!root.hovering || root.touching || root.bodyBusy || root.ball.asleep) return;
      if (root.sulking) { root.ball.lookAt(-0.9, 0.1, 1500); root.say("huff"); return; }
      if (!root.trustShown && root.m.affection > 0.35) { root.trustShown = true; root.ball.slowBlink(); }
    }
  }
  function strokeAt(x, y) {
    if (touching || bodyBusy) return;
    const t = Date.now();
    const min = petR * 0.55;
    const b = Mind.stroke(strokeX, x, t, min) || Mind.stroke(strokeY, y, t, min);
    if (!b) return;
    beats = beats.filter(s => t - s < 2000).concat([t]);
    if (beats.length < 2) return;           // one pass is a pass, two are a stroke
    stroked(b);
  }
  function stroked(dir) {
    petted += 0.25;
    nudge("stroke");
    need = Math.max(0, need - 0.15);
    attention = Math.min(1, attention + 0.15);
    lowFor = 0;
    ignored = 0;
    ball.squash = 0.18;
    ball.tiltNow = dir * 7;
    tiltHome.restart();
    if (ball.asleep) return;                // purrs in its sleep: nothing else
    if (sulking) {
      if (beats.length >= 3) { sulkLeft = 0; ball.sulk = 0; ball.express("happy", 1200); say("forgive", true); }
      return;
    }
    ball.express(petted > 4 && m.energy < 0.5 ? "doze" : "purr", 1500);
    if (petted > 4 && m.energy < 0.5 && doing === "home" && !ball.dozing) { say("melt", true); ball.getSleepy(Mind.jitter(9000, 0.2)); }
    else say("purr");
    if (doing === "pester") pesterLeft += 1.5;
    else if (doing === "back") { doing = "pester"; act = "peek"; actLeft = 3; pesterLeft = 8; stopHere(); }
  }
  Timer { id: tiltHome; interval: 220; onTriggered: root.ball.tiltNow = 0 }

  // ---- the world: Hyprland's own events, no polling ----
  property double worldAfter: 0
  property double glanceAfter: 0
  property double refreshedAt: 0
  property var rects: ({})              // last known window centres by address, screen pixels
  Connections {
    target: Hyprland
    enabled: Motion.bar && root.follow
    function onRawEvent(event) { root.onWorld(event.name, event.data); }
  }
  // what you are doing: it knows the kind of program in front of you and has a word about
  // it, once in a good while per kind (a friend comments, it does not narrate)
  readonly property var appKinds: ({
    terminal: ["kitty", "alacritty", "foot", "wezterm", "ghostty", "konsole", "xterm"],
    editor: ["code", "code-oss", "nvim", "neovide", "jetbrains", "zed", "sublime"],
    browser: ["firefox", "chromium", "brave", "zen", "google-chrome", "librewolf", "vivaldi"],
    chat: ["telegram", "discord", "vesktop", "element", "signal", "slack"],
    game: ["steam", "lutris", "heroic", "minecraft", "dota2", "cs2"],
    video: ["mpv", "vlc", "celluloid"],
    notes: ["obsidian", "logseq", "joplin"]
  })
  property var appSaid: ({})
  property double countedAt: 0
  function noticeApp(addr) {
    const wantSay = speech && Date.now() >= speechAfter && Math.random() <= 0.5;
    if (!wantSay && Date.now() - countedAt < 20000) return;
    later(350, function() {
      const a = String(addr).replace(/^0x/, "");
      const list = Hyprland.toplevels.values;
      for (let i = 0; i < list.length; i++) {
        if (String(list[i].address).replace(/^0x/, "") !== a) continue;
        const cls = String(list[i].lastIpcObject?.class ?? "").toLowerCase();
        for (const kind in root.appKinds) {
          if (!root.appKinds[kind].some(n => cls.includes(n))) continue;
          const now = Date.now();
          if (now - root.countedAt > 20000) { root.countedAt = now; mem.count(kind); }
          if (!wantSay) return;
          if (now - (root.appSaid[kind] ?? 0) < 25 * 60000 || root.bodyBusy || root.ball.asleep) return;
          root.appSaid[kind] = now;
          root.lastApp = kind;
          root.smartSay("хозяин открыл " + (root.appRu[kind] ?? kind), "app_" + kind, true);
          if (kind === "game") root.ball.express("glee", 1500);
          else if (kind === "video") root.ball.lookAt(0, -0.3, 1500);
          return;
        }
        return;
      }
    });
  }

  function windowAt(addr) {
    const a = String(addr).replace(/^0x/, "");
    const list = Hyprland.toplevels.values;
    for (let i = 0; i < list.length; i++) {
      const t = list[i];
      if (String(t.address).replace(/^0x/, "") !== a) continue;
      const o = t.lastIpcObject;
      if (!o || !o.at || !o.size) return null;
      const p = { x: o.at[0] + o.size[0] / 2 - screenX, y: o.at[1] + o.size[1] / 2 - screenY };
      rects[a] = p;
      return p;
    }
    return null;
  }
  function onScreen(p) { return p && p.x >= 0 && p.y >= 0 && p.x <= screenW && p.y <= screenH; }
  readonly property var worldNames: ["openwindow", "closewindow", "activewindowv2", "workspacev2", "fullscreen", "urgent", "configreloaded", "monitoraddedv2", "monitorremoved", "movewindowv2"]
  function onWorld(name, data) {
    if (!worldNames.includes(name)) return;
    if (bodyBusy || ball.asleep || ball.dozing || doing === "nap") return;
    const now = Date.now();
    const addr = String(data).split(",")[0];
    if (name === "openwindow") {
      if (now < worldAfter || Math.random() > 0.35 + m.curiosity * 0.6) return;
      worldAfter = now + 2500;
      nudge("world");
      Hyprland.refreshToplevels();
      refreshedAt = now;
      later(240, function() {
        const p = root.windowAt(addr);
        if (root.onScreen(p)) root.look(p.x, p.y, 1600); else root.ball.lookAt(0, 0.4, 1000);
        root.later(Mind.jitter(220, 0.3), function() { root.ball.hopBy(0.2 + root.m.curiosity * 0.15); root.say("newWindow"); });
      });
    } else if (name === "closewindow") {
      if (now < worldAfter || Math.random() > 0.3 + m.affection * 0.5) return;
      worldAfter = now + 2500;
      const p = rects[addr.replace(/^0x/, "")];
      if (onScreen(p)) look(p.x, p.y, 1300);
      later(Mind.jitter(260, 0.3), function() { root.ball.wave(); root.say("closeWindow"); });
    } else if (name === "activewindowv2") {
      noticeApp(addr);
      if (now < glanceAfter || Math.random() > 0.4 + m.curiosity * 0.5) return;
      glanceAfter = now + 1400;
      // a stale position is fine for a glance; ask again now and then, never on a timer
      if (now - refreshedAt > 4000) { Hyprland.refreshToplevels(); refreshedAt = now; }
      later(120, function() {
        const p = root.windowAt(addr);
        if (root.onScreen(p)) { root.look(p.x, p.y, 1100); if (Math.random() < 0.3) root.ball.blinkSoon(); }
      });
    } else if (name === "fullscreen") {
      if (now < worldAfter) return;
      worldAfter = now + 2500;
      const on = String(data).trim() === "1";
      ball.react("surprised");
      if (on) { ball.lookAt(0, -0.4, 900); later(900, function() { root.ball.slowBlink(); }); }
      else ball.hopBy(0.15);
      say(on ? "fullscreen" : "windowed");
    } else if (name === "urgent") {
      if (now < worldAfter) return;
      worldAfter = now + 3000;
      ball.react("surprised");
      ball.wave();
      later(500, function() { root.ball.hopBy(0.25); root.say("urgent", true); });
    } else if (name === "configreloaded") {
      if (now < worldAfter) return;
      worldAfter = now + 3000;
      ball.shakeOff();
      say("reload");
    } else if (name === "monitoraddedv2" || name === "monitorremoved") {
      worldAfter = now + 3000;
      ball.react("surprised");
      ball.lookAt(0.9, 0, 900);
      say(name === "monitorremoved" ? "monitorGone" : "monitorNew", true);
    } else if (name === "movewindowv2") {
      if (now < glanceAfter || Math.random() > 0.3 + m.curiosity * 0.4) return;
      glanceAfter = now + 2000;
      ball.lookAt(Math.random() < 0.5 ? -0.7 : 0.7, 0, 700);
      if (Math.random() < 0.3) ball.blinkSoon();
    } else if (name === "workspacev2") {
      if (now < worldAfter) return;
      worldAfter = now + 2000;
      ball.react("surprised");
      ball.lookAt(Math.random() < 0.5 ? -0.9 : 0.9, -0.1, 700);
      later(700, function() { root.ball.lookAt(0, 0, 400); });
      if (Math.random() < 0.4 + m.curiosity * 0.3) say("workspace");
    }
  }

  // ---- thinking, twice a second ----
  Timer {
    interval: 500
    running: true
    repeat: true
    onTriggered: root.tick(0.5)
  }

  function tick(dt) {
    doingFor += dt;
    shyCooldown = Math.max(0, shyCooldown - dt);
    passed += dt;
    Mind.drift(m, base(), dt, 240);
    played = Mind.fade(played, dt, 240);
    petted = Mind.fade(petted, dt, 300);
    if (ball.asleep) m.energy = Math.min(1, m.energy + 0.003 * dt);
    else if (doing !== "home") m.energy = Math.max(0, m.energy - 0.0012 * dt);
    ball.energy = m.energy;
    // a release that never came (the window went away under the hand)
    if (doing === "held" && !touching && !slipped) { if (dragging) { dragging = false; release(); } else putDown(); }
    if (doing === "dazed" && doingFor > 6) { ball.busy = false; goBack(); }
    if (!Motion.bar || !follow) return;
    if (bodyBusy) return;

    if (doing === "home") {
      if (sulkLeft > 0) { sulkLeft = Math.max(0, sulkLeft - dt); ball.sulk = sulkLeft > 0 ? 1 : 0; return; }
      if (ball.asleep) {
        need = 0;
        if (Math.random() < 0.05) ball.twitch();
        if (Math.random() < 0.18) ball.emote("z");
        if (Math.random() < 0.012) { dreamed = true; say("dream", true); }
        sleepLeft -= dt;
        if (sleepLeft <= 0) { ball.rouse(); nudge("sleep"); say(dreamed ? "wakeDream" : "wake", true); dreamed = false; }
        return;
      }
      if (temper === "calm" || ball.dozing) return;
      need = Math.min(1, need + needRate * dt * (0.6 + Math.random() * 0.8) * (0.6 + m.affection * 0.8 + Math.min(1, petted * 0.15)) * (0.55 + mem.bond * 0.9));
      const hazard = Math.max(0, need - 0.35) * 0.45 * (temper === "clingy" ? 2 : 1) * (0.4 + m.energy);
      if (Math.random() < hazard * dt) { decideToGo(); return; }
      homeLife(dt);
    } else if (doing === "pester") {
      pesterLeft -= dt;
      actLeft -= dt;
      attention = Math.max(0, attention - 0.035 * dt);
      lowFor = attention < 0.12 ? lowFor + dt : 0;
      if (cursorIdle > 18 && !ball.dozing && act !== "hide") { nap(); return; }
      if (lowFor > 7 * (1 - m.grumpy * 0.4)) { sulkHome(); return; }
      if (pesterLeft <= 0) { goBack(); return; }
      if (act === "stalk" && Math.hypot(cx - px, cy - py) < 150 && cursorIdle > 0.5) { boo(); return; }
      if (act === "beg" && Math.random() < 0.35) { ball.hopBy(0.2 + Math.random() * 0.12); look(cx, cy, 1200); if (Math.random() < 0.3) say("beg"); }
      if (act === "hide" && actLeft <= 0 && !moving) { act = "follow"; actLeft = Mind.jitter(3, 0.3); say("peekaboo"); return; }
      if (actLeft <= 0) nextAct();
    } else if (doing === "tag") {
      tagLeft -= dt;
      if (!cursorOn) { goBack(); return; }
      if (tagLeft <= 0) tagWon();
    } else if (doing === "roam") {
      if (cursorOn && cursorIdle < 2 && !(exploring && Math.hypot(cx - px, cy - py) > 260)) { exploring = false; visit = null; doing = "out"; ball.react("surprised"); say("glad", true); setGoal(cx, cy, runSpeed); return; }
      if (!moving) {
        roamPause -= dt;
        if (roamPause <= 0) { if (roamLeft <= 0) { exploring = false; visit = null; goBack(); } else nextRoam(); }
      }
    } else if (doing === "nap") {
      say("zzz");
      if (ball.asleep && Math.random() < 0.06) ball.twitch();
    }
  }

  // ---- the model's word ----
  // While there is internet (and it is allowed) a line now and then comes from a free
  // opencode model instead of the canned ones; see CompanionWit. Falls back to canned.
  CompanionWit { id: wit }
  property string extraFacts: ""                // the machine's state, from CompanionPulse
  property string lastApp: ""
  readonly property var dayMoodRu: ({ playful: "игривое", lazy: "ленивое", cheery: "весёлое", grumpy: "ворчливое", clingy: "ласковое", curious: "любопытное" })
  readonly property var appRu: ({ terminal: "терминал", editor: "редактор кода", browser: "браузер", chat: "мессенджер", game: "игру", video: "видео", notes: "заметки" })
  function factsLine(topic) {
    const h = new Date().getHours();
    const part = h >= 5 && h < 12 ? "утро" : h < 18 ? "день" : h < 23 ? "вечер" : "ночь";
    const sat = Math.round((Date.now() - mem.sessionStart) / 60000);
    return topic + ". Сейчас " + part + ", хозяин за компьютером уже " + sat + " мин. Твоё настроение сегодня "
      + (dayMoodRu[mem.mood] ?? "обычное") + ", вы знакомы " + Math.max(1, mem.dayNumber) + " дн."
      + (extraFacts !== "" ? " " + extraFacts : "");
  }
  // say something about the moment: from the model when it can, else the canned `fallback`
  function smartSay(topic, fallback, force) {
    if (!speech) return;
    if (!wit.ask(factsLine(topic), function(text) {
      if (root.bodyBusy || root.ball.asleep || root.touching) return;
      root.sayText(text);
      root.ball.express("curious", 700);
    })) { if (fallback) say(fallback, force); }
  }

  // ---- meeting again ----
  // It knows how long you were away and what day of knowing each other it is.
  function sayText(text) { if (speech) { speechAfter = Date.now() + Mind.jitter(7000, 0.4); said(text); } }
  property double breakAt: 90 * 60000
  function meet() {
    checkMood();
    checkStage();
    m.affection = Math.max(m.affection, base().affection);
    const away = mem.away, h = new Date().getHours();
    later(2500, function() {
      if (root.doing !== "home" || root.touching) return;
      if (mem.firstMeeting) {
        root.ball.wave(); root.ball.express("curious", 1500); root.say("meet", true);
      } else if (away > 72) {
        root.m.affection = Math.min(1, root.m.affection + 0.2);
        root.ball.express("glee", 2200); root.ball.hopBy(0.35); root.say("missedLong", true);
        if (root.cursorOn) root.later(1600, function() { if (root.doing === "home") { root.doing = "out"; root.setGoal(root.cx, root.cy, root.runSpeed); } });
      } else if (away > 10) {
        root.ball.wave();
        if (!wit.ask(root.factsLine("хозяин вернулся к компьютеру после " + Math.round(away) + " ч отсутствия"), function(t) { if (root.doing === "home") root.sayText(t); }))
          root.say(h >= 5 && h < 11 ? "morning" : h >= 23 || h < 5 ? "late" : "back", true);
      } else if (away > 0.25) {
        root.ball.wave(); root.say("hello", true);
      }
      const fav = mem.favourite();
      if (mem.newDay && fav.n >= 25 && fav.share > 0.35 && Math.random() < 0.5) root.later(6500, function() { root.say("fav_" + fav.kind, true); });
      const d = mem.dayNumber;
      if (mem.newDay && (d === 7 || d === 30 || d === 100 || d === 365)) {
        root.later(4200, function() { root.sayText("мы вместе уже " + d + " " + (d === 7 ? "дней, неделя!" : "дней")); root.ball.express("proud", 2000); });
      } else if (mem.newDay && mem.days >= 5 && Math.abs(h - mem.usualHour) >= 5) {
        root.later(4200, function() { root.say("offHour", true); });
      }
    });
  }

  // at home with nothing to do it is not a statue: it watches the pointer, mutters,
  // gets bored, sighs, wants a word; each in its own time, with a rest after each
  property bool dreamed: false
  property real lifeRest: 6
  function homeLife(dt) {
    lifeRest -= dt;
    if (lifeRest > 0 || touching || hovering) return;
    lifeRest = Mind.jitter(9, 0.5);
    // a friend notices you have sat a long time
    const sat = Date.now() - mem.sessionStart;
    if (sat > breakAt && breakAt > 0) {
      breakAt += 90 * 60000;
      ball.yawn();
      say(sat > 4 * 3600000 ? "longSit" : "pause", true);
      return;
    }
    checkMood();
    if (stage >= 1 && cursorOn && Date.now() > tagAfter && m.energy > 0.5 && m.affection > 0.45 && !sulking && Math.random() < 0.06) { invite(); return; }
    // a friend does not wait to be called: it comes over when you have sat still a while
    if (stage >= 2 && cursorOn && cursorIdle > 10 && !ball.asleep && Math.random() < 0.12 + (stage - 2) * 0.1) { decideToGo(); return; }
    // curious and rested: it goes to see what is on the screen (now and then, not on a clock)
    if (follow && Motion.bar && m.curiosity > 0.45 && m.energy > 0.4 && !sulking && Math.random() < 0.07) { explore(); return; }
    const r = Math.random();
    if (r < 0.25 && cursorOn) { look(cx, cy, 1400); if (Math.random() < 0.4) ball.slowBlink(); }
    else if (r < 0.45) smartSay("тебе нечем заняться, ты просто сидишь рядом с хозяином" + (lastApp !== "" ? ", перед ним недавно была программа: " + (appRu[lastApp] ?? lastApp) : ""), "idle");
    else if (r < 0.58 && m.energy < 0.4) { ball.yawn(); say("tired"); }
    else if (r < 0.7 && m.affection > 0.5) { ball.express("happy", 1000); say("love"); }
    else if (r < 0.82 && m.energy > 0.55) { ball.ready(); later(600, function() { root.ball.hopBy(0.3); }); }
    else if (r < 0.92 && !cursorOn) { ball.rollEyes(); }
    else { ball.land(0.3); ball.slowBlink(); }
  }

  // crept up behind the pointer: boo!
  function boo() {
    ball.sneaking = false;
    ball.hopBy(0.55);
    ball.express("glee", 900);
    say("boo", true);
    played += 0.4;
    act = "hop";
    actLeft = 1.4;
    stopHere();
  }

  // ---- another monitor ----
  // It runs to the edge, stands on it looking across, gathers, and hops over; the window
  // follows it there (CompanionWindow.crossTo) and it lands inside the other screen and
  // goes on with what it was doing.
  property string crossName: ""
  property string afterCross: ""        // out | roam | back: what it does on the other side
  property var crossPlan: null
  function screenByName(n) { for (const s of screens) if (s.name === n) return s; return null; }
  function otherScreens() { return screens.filter(s => s.name !== screenName); }

  function startCross(name, then) {
    const cur = screenByName(screenName), other = screenByName(name);
    if (!cur || !other || cur === other) return false;
    crossName = name;
    afterCross = then;
    crossPlan = Steer.edgeExit(cur, other, py + screenY, px + screenX, petR);
    doing = "cross";
    ball.sneaking = false;
    act = "";
    setGoalFree(crossPlan.ex - screenX + (crossPlan.side === "right" ? petR * 0.4 : crossPlan.side === "left" ? -petR * 0.4 : 0),
                crossPlan.ey - screenY + (crossPlan.side === "bottom" ? petR * 0.4 : crossPlan.side === "top" ? -petR * 0.4 : 0), runSpeed * 0.8);
    return true;
  }

  // Carried or thrown over the edge it does not stop there: the screen's walls open where
  // another monitor lies behind them, the ball goes on (CompanionWindow draws the part
  // that is over there in a ghost window) and the window follows it only when it lands.
  function reach(lx, ly) {
    return Steer.reachBounds({ x: screenX, y: screenY, w: screenW, h: screenH }, otherScreens(), lx, ly, petR);
  }
  // it came down on another monitor: the window moves there, under the ghost, nothing else changes
  function rehome() {
    const gx = px + screenX, gy = py + screenY;
    if (gx >= screenX && gx < screenX + screenW && gy >= screenY && gy < screenY + screenH) return;
    for (const s of otherScreens()) {
      if (gx >= s.x && gy >= s.y && gx < s.x + s.w && gy < s.y + s.h) { afterCross = ""; crossRequest(s.name, gx, gy); return; }
    }
  }

  // at the edge: a look across, a gather, a hop
  function atEdge() {
    if (crossPlan === null) return;
    stopHere();
    const plan = crossPlan;
    crossPlan = null;
    look(plan.nx - screenX, plan.ny - screenY, 900);
    ball.react("curious");
    later(Mind.jitter(450, 0.3), function() {
      if (root.doing !== "cross") return;
      root.ball.crouch();
      root.later(320, function() {
        if (root.doing !== "cross") return;
        root.crossRequest(root.crossName, plan.nx, plan.ny);
      });
    });
  }

  // the window is on the other screen now: the pet's place is rebuilt there
  function rebase(gx, gy) {
    px = gx - screenX;
    py = gy - screenY;
    tx = px; ty = py;
    if (doing !== "cross") return;
    stopHere();
    ball.land(0.55);
    ball.react("happy");
    const then = afterCross;
    afterCross = "";
    later(350, function() {
      if (root.doing !== "cross") return;
      if (then === "out" && root.cursorOn) { root.doing = "out"; root.setGoal(root.cx, root.cy, root.runSpeed); }
      else if (then === "back") root.goBack();
      else { root.doing = "roam"; root.roamLeft = 4 + Math.floor(Math.random() * 4); root.nextRoam(); }
    });
  }

  // ---- on its own: with no pointer on its screen it explores ----
  property string cursorScreen: ""
  property real roamLeft: 0
  // ---- tag ----
  // "Catch me!": it invites you, then runs from the pointer; touch it with the pointer
  // before the time is up. Caught, it is delighted and wants more; not caught, it is proud.
  property real tagLeft: 0
  property double tagAfter: 0
  property double tagStep: 0
  function invite() {
    ball.wave();
    ball.express("mischief", 1400);
    say("tagInvite", true);
    tagAfter = Date.now() + 15 * 60000;
    later(1300, function() { root.startTag(); });
  }
  function startTag() {
    if (doing !== "home" || !cursorOn) return;
    doing = "tag";
    act = "";
    tagLeft = 20 + m.energy * 10;
    tagAfter = Date.now() + 15 * 60000;
    ball.sneaking = false;
    ball.react("curious");
  }
  function tagFlee(d) {
    const now = Date.now();
    if (now < tagStep) return;
    tagStep = now + 230;
    const away = Math.atan2(py - cy, px - cx) + (Math.random() - 0.5) * 1.4;
    const margin = petR * 1.6;
    let x = Steer.clamp(px + Math.cos(away) * 280, margin, screenW - margin);
    let y = Steer.clamp(py + Math.sin(away) * 280, margin, screenH - margin);
    // cornered: it darts across the screen, past the pointer
    if (Math.hypot(x - px, y - py) < 90) { x = margin + Math.random() * (screenW - margin * 2); y = margin + Math.random() * (screenH - margin * 2); }
    setGoal(x, y, runSpeed + 90);
    if (Math.random() < 0.08) ball.hopBy(0.12);
  }
  function tagCaught() {
    stopHere();
    ball.land(0.5);
    ball.express("glee", 1800);
    say("tagCaught", true);
    played += 1;
    nudge("play");
    doing = "pester";
    act = "peek";
    actLeft = 1.8;
    pesterLeft = 8;
    attention = 0.8;
    begging = true;
  }
  function tagWon() {
    ball.express("proud", 2200);
    say("tagWon", true);
    nudge("play", 0.5);
    later(1800, function() { if (root.doing === "tag") root.goBack(); });
    tagLeft = 99999;     // waits for the line above
  }

  // ---- exploring the screen ----
  // A curious one walks over to the windows you have open: stands on a title edge, peers
  // over a side, looks in, and has a word about what it sees. Not on a timer: now and then
  // when it is curious and nothing else is going on.
  property bool exploring: false
  property var visit: null              // {kind, x, y, cx, cy, cls} the window it is going to
  property string lastVisited: ""
  function windowSpots() {
    const out = [];
    const mon = Hyprland.monitors.values.find(mo => mo.name === screenName);
    const active = mon?.lastIpcObject?.activeWorkspace?.id;
    const list = Hyprland.toplevels.values;
    for (let i = 0; i < list.length; i++) {
      const o = list[i].lastIpcObject;
      if (!o || !o.at || !o.size || o.hidden || o.mapped === false) continue;
      if (active !== undefined && o.workspace?.id !== active) continue;
      const l = o.at[0] - screenX, t = o.at[1] - screenY, w = o.size[0], h = o.size[1];
      const cx = l + w / 2, cy = t + h / 2;
      if (cx < 0 || cy < 0 || cx > screenW || cy > screenH || w < 120 || h < 80) continue;
      out.push({ addr: String(list[i].address), l: l, t: t, w: w, h: h, cx: cx, cy: cy, cls: String(o.class ?? "").toLowerCase() });
    }
    return out;
  }
  function explore() {
    if (doing !== "home" || exploring) return;
    Hyprland.refreshToplevels();
    refreshedAt = Date.now();
    later(400, function() {
      if (root.doing !== "home" || root.touching) return;
      if (root.windowSpots().length === 0) return;
      root.exploring = true;
      root.doing = "windup";
      root.ball.react("curious");
      root.look(root.screenW / 2, root.screenH / 2, 900);
      root.later(Mind.jitter(600, 0.3), function() {
        if (root.doing !== "windup") return;
        root.doing = "roam";
        root.roamLeft = 3 + Math.floor(Math.random() * 3);
        root.roamPause = 0;
        root.nextRoam();
      });
    });
  }
  // the next window: a title edge to stand on, or a side to peer over
  function nextVisit() {
    const spots = windowSpots().filter(w => w.addr !== lastVisited);
    if (spots.length === 0) return false;
    const w = Steer.pick(spots);
    lastVisited = w.addr;
    const r = Math.random();
    let kind = "top", x = 0, y = 0;
    if (r < 0.6) { x = w.l + petR + Math.random() * Math.max(1, w.w - petR * 2); y = w.t - petR * 0.8; }
    else if (r < 0.8) { kind = "left"; x = w.l - petR * 0.5; y = w.t + petR + Math.random() * Math.max(1, w.h - petR * 2); }
    else { kind = "right"; x = w.l + w.w + petR * 0.5; y = w.t + petR + Math.random() * Math.max(1, w.h - petR * 2); }
    visit = { kind: kind, cx: w.cx, cy: w.cy, cls: w.cls };
    setGoal(Steer.clamp(x, petR, screenW - petR), Steer.clamp(y, petR, screenH - petR), playSpeed + Math.random() * 100);
    roamLeft -= 1;
    return true;
  }
  // it is there: a look into the window, a peer, a word
  function inspect() {
    const v = visit;
    visit = null;
    look(v.cx, v.cy, 1800);
    ball.tilt = v.kind === "left" ? -7 : v.kind === "right" ? 7 : 0;
    ball.express("curious", 1500);
    later(900, function() { root.ball.slowBlink(); });
    let kindName = "";
    for (const k in appKinds) if (appKinds[k].some(n => v.cls.includes(n))) { kindName = k; break; }
    later(1100, function() {
      if (kindName !== "" && Math.random() < 0.7) root.say("app_" + kindName, true);
      else root.say("explore", true);
      if (Math.random() < 0.4) root.ball.hopBy(0.15);
    });
    roamPause = Mind.jitter(3.2, 0.3);
  }

  function nextRoam() {
    if (exploring && Math.random() < 0.85 && nextVisit()) return;
    const others = otherScreens();
    if (others.length > 0 && Math.random() < 0.28 && startCross(Steer.pick(others.map(s => s.name)), "roam")) return;
    const margin = petR * 2;
    setGoal(margin + Math.random() * (screenW - margin * 2), margin + Math.random() * (screenH * 0.7 - margin), playSpeed + Math.random() * 120);
    roamLeft -= 1;
  }

  // it looks at the pointer, says so, gathers, and goes; the window grows meanwhile
  function decideToGo() {
    doing = "windup";
    look(cx, cy, 900);
    ball.react("curious");
    say("bored", true);
    later(Mind.jitter(500, 0.3), function() {
      if (root.doing !== "windup") return;
      root.ball.crouch();
      root.later(380, function() {
        if (root.doing !== "windup") return;
        root.hesitateIn = 2 + Math.random() * 2;
        if (root.cursorOn) { root.doing = "out"; root.setGoal(root.cx, root.cy, root.runSpeed); }
        else if (root.cursorScreen !== "" && root.cursorScreen !== root.screenName && root.startCross(root.cursorScreen, "out")) { /* off to the other monitor */ }
        else { root.doing = "roam"; root.roamLeft = 5 + Math.floor(Math.random() * 5); root.nextRoam(); }
      });
    });
  }

  function goBack() {
    doing = "back";
    act = "";
    ball.sneaking = false;
    ball.busy = false;
    say("back", true);
    setGoal(home.x, home.y, homeSpeed);
  }

  // nobody answered: it says so and goes home slowly, head low; the more often, the longer it sulks
  function sulkHome() {
    doing = "back";
    act = "";
    ball.sneaking = false;
    ball.sulk = 1;
    ignored++;
    nudge("ignored");
    sulkLeft = Math.min(120, Mind.jitter(18, 0.3) * (1 + ignored * 0.8));
    ball.express("sad", 1600);
    say("sulk", true);
    setGoal(home.x, home.y, homeSpeed * 0.6);
  }

  function nap() {
    doing = "nap";
    napX = cx; napY = cy;
    stopHere();
    ball.getSleepy(7000);
    say("yawn", true);
  }

  function wakeNap() {
    ball.rouse();
    ball.react("surprised");
    say("surprised", true);
    doing = "pester";
    attention = 0.6;
    lowFor = 0;
    pesterLeft = 10 + Math.random() * 15;
    act = "follow";
    actLeft = 4;
  }

  // a mumble now and then, whatever it is doing, coloured by how it feels
  Timer {
    interval: 9000
    running: root.speech && Motion.bar
    repeat: true
    onTriggered: {
      interval = Mind.jitter(12000, 0.45) * (1.6 - root.m.energy);
      if (root.bodyBusy) return;
      if (root.ball.asleep) { root.say("zzz"); return; }
      if (root.sulking) { root.say("huff"); return; }
      const hour = new Date().getHours();
      const r = Math.random();
      if (root.doing === "home" && hour < 5 && r < 0.3) root.say("late");
      else if (root.m.grumpy > 0.5 && r < 0.5) root.say("grumble");
      else if (root.m.affection > 0.7 && r < 0.4) root.say("love");
      else if (root.m.energy < 0.3 && r < 0.5) root.say("tired");
      else root.say(root.doing === "home" ? "idle" : root.doing === "out" || root.doing === "windup" ? "out" : "pester");
    }
  }

  // hello, once
  Timer { interval: 1800; running: root.speech; onTriggered: root.say("hello", true) }

  // home moves (side, size): follow it while it sits there
  onHomeChanged: if (doing === "home") { px = home.x; py = home.y; tx = px; ty = py; }

  // off: it goes home and stays
  onFollowChanged: if (!follow) { ball.pointerNear = false; if (doing !== "home" && !bodyBusy) goBack(); }
}
