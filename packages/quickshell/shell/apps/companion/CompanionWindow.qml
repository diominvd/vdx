import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config

// Kimmy: a white ball with eyes, a pet that lives beside the bar. One window on one
// screen, never a copy per monitor.
//
// At home the window is a small box at the screen's top corner, in the bar's row. When
// Kimmy goes out (CompanionBrain) the window becomes the whole screen, click-through
// except for Kimmy itself, and shrinks again when it is back; so a resting pet costs a
// small surface, not a full-screen one. Where the ball is comes from the brain in
// screen pixels; the window turns that into its own coordinates by its real size.
PanelWindow {
  id: root

  required property var modelData
  // the screen it is on: where it was made, then wherever it hops to
  property string screenName: modelData.name
  readonly property var scr: Quickshell.screens.find(s => s.name === screenName) ?? modelData
  screen: scr

  // ---- the settings ----
  readonly property bool onRight: ModuleSettings.get("companion", "side", "right") === "right"
  readonly property string sizeName: ModuleSettings.get("companion", "size", "medium")
  readonly property int box: sizeName === "small" ? 32 : sizeName === "large" ? 56 : 42
  // ---- its look ----
  CompanionStyle { id: lookStyle }
  readonly property bool follow: ModuleSettings.get("companion", "follow", true)

  // ---- the places ----
  readonly property real sw: scr.width
  readonly property real sh: scr.height
  readonly property real homeX: onRight ? sw - Theme.edgeMargin - box / 2 : Theme.edgeMargin + box / 2
  readonly property real homeY: Math.max(box / 2 + 2, (Theme.island ? Theme.islandTop + Theme.islandHeight / 2 : Theme.barHeight / 2))
  readonly property int dockW: 260
  readonly property int dockH: Math.round(homeY + box / 2 + 80)

  // a moment after it is back the window shrinks, so the last steps are not cut
  readonly property bool expanded: brain.wantFull || shrinkWait.running
  Timer { id: shrinkWait; interval: 700 }
  Connections {
    target: brain
    function onWantFullChanged() { if (!brain.wantFull) shrinkWait.restart(); }
  }

  // -1: the window starts at the screen's corner even under the bar's reserved strip (it
  // used to sit 40 px low, so the ball was not where the brain thought it was)
  exclusionMode: ExclusionMode.Ignore
  color: Theme.clear
  WlrLayershell.namespace: "companion"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  anchors { top: true; bottom: expanded; left: expanded || !onRight; right: expanded || onRight }
  implicitWidth: expanded ? sw : dockW
  implicitHeight: expanded ? sh : dockH

  // the window's own corner, in screen pixels, by what it really is now
  readonly property bool full: width >= sw - 1 && height >= sh - 1
  readonly property real originX: full || !onRight ? 0 : sw - width
  readonly property real originY: 0

  // not before the window has its real size and the settings (home) are known: no jump at start
  readonly property bool sized: ShellSettings.loaded && (full || (width === dockW && height === dockH))
  // latched: only the very start waits; a resize later (hover, back home) must not hide the ball
  property bool placed: false
  onSizedChanged: if (sized) placed = true

  // the window is being resized: hover on the ball goes false and true again on its own, and
  // each flip would resize it again (the ball jumped about the corner)
  property bool settling: false
  onWidthChanged: { settling = true; settle.restart() }
  onHeightChanged: { settling = true; settle.restart(); }
  Timer {
    id: settle
    interval: 260
    onTriggered: { root.settling = false; ball.pointerOver = touch.containsMouse; brain.hover(touch.containsMouse); }
  }

  mask: Region { item: hit }

  CompanionBrain {
    id: brain
    ball: ball
    screenX: root.scr.x
    screenY: root.scr.y
    screenName: root.screenName
    screens: Quickshell.screens.map(s => ({ name: s.name, x: s.x, y: s.y, w: s.width, h: s.height }))
    onCrossRequest: (name, gx, gy) => { root.screenName = name; brain.rebase(gx, gy); }
    screenW: root.sw
    screenH: root.sh
    home: Qt.point(root.homeX, root.homeY)
    petR: root.box / 2
    windowReady: root.full
    follow: root.follow
    speech: ModuleSettings.get("companion", "speech", true)
    temper: ModuleSettings.get("companion", "temper", "playful")
    extraFacts: pulse.line
    onSaid: text => { bubble.show(text); voice.babble(text); }
  }

  CompanionPulse { id: pulse; brain: brain; ball: ball }
  CompanionSound { id: voice }
  Connections { target: ball; function onSound(name) { voice.play(name); } function onEmote(kind) { signs.spawn(kind); } }

  // ---- signs over its head ----
  // heart, note, spark ...: a glyph floats up from above the ball and fades. Made when needed
  // and gone when done; not in the mask.
  Item {
    id: signs
    readonly property var glyphs: ({
      heart: { t: "\u2665", c: "#ff5c7a" }, note: { t: "\u266a", c: "#5cc8ff" }, spark: { t: "\u2726", c: "#ffd45c" },
      tear: { t: "\ud83d\udca7", c: "#5cc8ff" }, bang: { t: "!", c: "#ff9a3c" }, ask: { t: "?", c: "#c8c8d0" },
      z: { t: "z", c: "#e8e8f0" }, anger: { t: "\ud83d\udca2", c: "#ff5c5c" }, sweat: { t: "\ud83d\udca7", c: "#8fd8ff" } })
    property double lastAt: 0
    function spawn(kind) {
      const g = glyphs[kind];
      const now = Date.now();
      if (!g || !Motion.bar || now - lastAt < 350 || !root.placed) return;
      lastAt = now;
      const side = Math.random() < 0.5 ? -1 : 1;
      puff.createObject(signs, { glyph: g.t, tint: g.c, x0: pet.x + pet.width / 2 + side * root.box * 0.3, y0: root.petTop - 4 });
    }
    Component {
      id: puff
      Text {
        id: sign
        property string glyph
        property color tint
        property real x0
        property real y0
        text: glyph
        color: tint
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(root.box * 0.42)
        font.bold: true
        style: Text.Outline
        styleColor: "#cc000000"
        x: x0 - width / 2
        y: y0 - height
        opacity: 0
        scale: 0.5
        ParallelAnimation {
          running: true
          NumberAnimation { target: sign; property: "y"; to: sign.y0 - sign.height - root.box * 0.7; duration: 1300; easing.type: Easing.OutCubic }
          NumberAnimation { target: sign; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack }
          SequentialAnimation {
            NumberAnimation { target: sign; property: "opacity"; to: 1; duration: 160 }
            PauseAnimation { duration: 650 }
            NumberAnimation { target: sign; property: "opacity"; to: 0; duration: 480 }
            ScriptAction { script: sign.destroy() }
          }
        }
      }
    }
  }

  // ---- Kimmy ----
  // `pet` is the ground spot (the shadow stays there); `hit` is the ball, lifted when it
  // is carried or flies, and it is the only part of the window that takes the pointer.
  Item {
    id: pet
    // between two screens the window is being remade: the ball waits for the new size
    visible: root.placed && !(brain.doing === "cross" && !root.full)
    width: root.box
    height: root.box
    x: brain.px - root.originX - width / 2
    y: brain.py - root.originY - height / 2

    // the shadow stays on the ground while the ball is over it: smaller and fainter the higher
    readonly property real up: brain.air + ball.bounce - ball.hopY
    Rectangle {
      readonly property real far: Math.min(1, pet.up / (root.box * 2))
      width: root.box * 0.7 * (1 - far * 0.55)
      height: root.box * 0.12 * (1 - far * 0.3)
      radius: height / 2
      x: (parent.width - width) / 2
      y: parent.height * 0.93
      color: "#000000"
      visible: lookStyle.shadowOn
      opacity: 0.2 * (1 - far * 0.7)
    }

    CompanionBall {
      id: ball
      anchors.centerIn: parent
      size: Math.round(root.box * 0.92)
      style: lookStyle
    }
  }

  Item {
    id: hit
    // a child of the window, not of `pet`: the mask follows an item's own geometry only, so a
    // parent that moved (the ball running, thrown) left the mask behind and the ball ungrabbable
    x: pet.x
    y: pet.y - brain.air
    width: root.box
    height: root.box
    visible: pet.visible

    MouseArea {
      id: touch
      anchors.fill: parent
      hoverEnabled: true
      preventStealing: true
      cursorShape: brain.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
      // the pointer in screen pixels (not the ball's own: the ball moves under it)
      function screenAt(m) { const p = touch.mapToItem(null, m.x, m.y); return Qt.point(p.x + root.originX, p.y + root.originY); }
      // while the window changes size the pointer seems to leave and come back: no verdict until it settles
      onContainsMouseChanged: { if (root.settling) return; ball.pointerOver = containsMouse; brain.hover(containsMouse); }
      onPressed: m => { const p = screenAt(m); brain.touchDown(p.x, p.y); }
      onPositionChanged: m => {
        const p = screenAt(m);
        if (pressed) { brain.touchMove(p.x, p.y); return; }
        brain.strokeAt(p.x, p.y);
        // the eyes look up at a pointer resting on it
        if (!brain.bodyBusy) { ball.pointerX = (m.x - width / 2) / width * 1.4; ball.pointerY = (m.y - height / 2) / height * 1.4 - 0.5; }
      }
      onReleased: m => { const p = screenAt(m); brain.touchUp(p.x, p.y); }
      onCanceled: brain.touchUp(brain.gpx, brain.gpy)
      onDoubleClicked: brain.trick()
    }
  }

  // the ball's centre is over this window's own screen (not yet over the next one)
  readonly property bool centreHere: brain.px >= 0 && brain.px <= sw && brain.py >= 0 && brain.py <= sh

  // ---- over the edge ----
  // A ball carried or thrown past the screen's edge is cut by it: each other screen it
  // reaches gets a click-through window of its own that draws the same ball there, so the
  // move is one piece. It is made only while the ball is over that screen; after the
  // window has moved house it stays a moment, until the real one is drawn on that screen.
  readonly property string ghostNames: {
    const r = box / 2 + 4, gx = brain.px + scr.x, gy = brain.py + scr.y;
    const names = [];
    if (!placed && !lingering.running) return "";
    // all of it on its own screen: nothing to show elsewhere (monitors may overlap in the layout)
    const inside = gx - r >= scr.x && gx + r <= scr.x + sw && gy - r >= scr.y && gy + r <= scr.y + sh;
    if (inside && !lingering.running) return "";
    for (const s of Quickshell.screens) {
      if ((s.name !== screenName || lingering.running) && gx + r > s.x && gx - r < s.x + s.width && gy + r > s.y && gy - r < s.y + s.height) names.push(s.name);
    }
    return names.join(",");
  }
  Timer { id: lingering; interval: 450 }
  onScreenNameChanged: if (placed) lingering.restart()

  Variants {
    model: root.ghostNames === "" ? [] : Quickshell.screens.filter(s => root.ghostNames.split(",").includes(s.name))

    PanelWindow {
      id: ghost
      required property var modelData
      screen: modelData
      exclusionMode: ExclusionMode.Ignore
      color: Theme.clear
      mask: Region {}
      WlrLayershell.namespace: "companion-ghost"
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      anchors { top: true; bottom: true; left: true; right: true }

      Item {
        x: brain.px + root.scr.x - ghost.modelData.x - root.box / 2
        y: brain.py + root.scr.y - ghost.modelData.y - root.box / 2
        width: root.box
        height: root.box
        Rectangle {
          readonly property real far: Math.min(1, (brain.air + ball.bounce - ball.hopY) / (root.box * 2))
          width: root.box * 0.7 * (1 - far * 0.55)
          height: root.box * 0.12 * (1 - far * 0.3)
          radius: height / 2
          x: (parent.width - width) / 2
          y: parent.height * 0.93
          color: "#000000"
          opacity: 0.2 * (1 - far * 0.7)
        }
        CompanionBall {
          id: twin
          anchors.centerIn: parent
          size: ball.size
          style: ball.style
          energy: ball.energy; drowsy: ball.drowsy; sulk: ball.sulk; busy: ball.busy
          speedFrac: ball.speedFrac; lean: ball.lean; bounce: ball.bounce; lift: ball.lift
          flowX: ball.flowX; flowY: ball.flowY; sneaking: ball.sneaking
          roll: ball.roll; rolling: ball.rolling; mood: ball.mood
        }
      }

      // the words, when the ball is over this screen
      Rectangle {
        readonly property real pcx: brain.px + root.scr.x - ghost.modelData.x
        readonly property real ptop: brain.py + root.scr.y - ghost.modelData.y - root.box / 2 - brain.air + ball.hopY
        readonly property bool here: pcx >= 0 && pcx <= ghost.width && ptop + root.box / 2 >= 0 && ptop + root.box / 2 <= ghost.height
        readonly property bool below: ptop - height - 8 < 0
        width: bubble.width
        height: bubble.height
        x: Math.max(4, Math.min(ghost.width - width - 4, pcx - width / 2))
        y: below ? ptop + root.box + 6 : ptop - height - 6
        radius: height / 2
        color: "#f7f7f8"
        border.color: "#d3d3d8"
        border.width: 1
        opacity: bubble.opacity
        visible: opacity > 0 && here
        Text {
          anchors.centerIn: parent
          text: bubble.words.slice(0, bubble.typed)
          color: "#1b1b1d"
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize
        }
      }
    }
  }

  // the ball and its words follow it; `hit` is the mask so a lifted ball still takes the pointer
  readonly property real petTop: pet.y - brain.air + ball.hopY

  // ---- what it mumbles ----
  // not in the mask: it is only seen, never hit
  Rectangle {
    id: bubble
    property string words: ""
    property int typed: 0
    property var rest: []
    // the words come out a letter at a time, like muttering, not a sign switched on; a
    // line with "|" comes in two bubbles, the second after a beat
    function show(text) {
      const parts = text.split("|");
      rest = parts.slice(1);
      put(parts[0]);
    }
    function put(text) { words = text; typed = Motion.bar ? 0 : text.length; fade.restart(); if (Motion.bar) typer.restart(); }
    Timer { id: typer; interval: 55; repeat: true; onTriggered: { bubble.typed++; if (bubble.typed >= bubble.words.length) stop(); } }
    Timer {
      id: nextPart
      interval: 900 + Math.random() * 500
      onTriggered: if (bubble.rest.length) { const t = bubble.rest[0]; bubble.rest = bubble.rest.slice(1); bubble.put(t); }
    }

    readonly property real wantX: pet.x + pet.width / 2 - width / 2
    readonly property bool below: root.petTop - height - 8 < 0
    x: Math.max(4, Math.min(root.width - width - 4, wantX))
    y: below ? root.petTop + pet.height + 6 : root.petTop - height - 6
    width: ruler.implicitWidth + 18
    height: label.implicitHeight + 10
    radius: height / 2
    color: "#f7f7f8"
    border.color: "#d3d3d8"
    border.width: 1
    opacity: 0
    // its words follow the ball: over the edge they show on the other screen (the ghost's bubble)
    visible: opacity > 0 && root.centreHere

    Text {
      id: ruler
      visible: false
      text: bubble.words
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
    }
    Text {
      id: label
      anchors.centerIn: parent
      text: bubble.words.slice(0, bubble.typed)
      color: "#1b1b1d"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
    }

    SequentialAnimation {
      id: fade
      NumberAnimation { target: bubble; property: "opacity"; to: 1; duration: Motion.bar ? 120 : 1 }
      PauseAnimation { duration: (bubble.rest.length ? 700 : 1500) + bubble.words.length * 60 }
      ScriptAction { script: if (bubble.rest.length) nextPart.restart() }
      NumberAnimation { target: bubble; property: "opacity"; to: bubble.rest.length ? 1 : 0; duration: Motion.bar ? 360 : 1 }
    }
  }

  IpcHandler {
    target: "companion"
    function poke(): void { brain.poke(); }
    function explore(): void { brain.explore(); }
    function tag(): void { brain.invite(); }
  }
}
