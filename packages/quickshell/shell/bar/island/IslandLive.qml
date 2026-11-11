import QtQuick
import qs.apps.auth
import qs.bar
import qs.components
import qs.config
import qs.kit
import qs.modules.focus

// The pill's live slot: the running activity (IslandService.live), only while
// something runs. The wheel pages through them: the shown one slides up and
// fades while the next comes in from below (back: the other way), inside the
// pill's height.
Item {
  id: root

  property string screen: ""
  readonly property string kind: IslandService.liveFor(screen)
  readonly property var notice: kind === "notice" ? IslandService.noticeItem : null
  property bool ready: false
  readonly property real travel: Theme.islandHeight * 0.6

  // two faces take turns: `front` is the shown one; `t` runs 0 → 1 while a step slides
  property int front: 0
  property real t: 0
  property bool sliding: false
  readonly property Item frontFace: front === 0 ? faceA : faceB
  readonly property Item backFace: front === 0 ? faceB : faceA

  clip: true          // contain text while the chip grows or changes activity
  // the activity sits in a chip of its own, always whole: concentric with the
  // pill — the same gap (`edge`) to the pill's rim above and below, its corners
  // the pill's less that gap; a cover inside sits `inset` from the chip's rim
  readonly property int edge: 4
  readonly property int inset: 3
  readonly property int chipHeight: Theme.islandHeight - 2 * edge
  readonly property int chipRadius: Math.max(0, Math.min(Theme.barRadiusFor(Theme.islandHeight), Theme.islandRadius) - edge)
  readonly property int coverSize: chipHeight - 2 * inset
  readonly property int badgeRadius: Math.max(0, chipRadius - inset)
  // the chip's side paddings come from the face, by what stands at its ends
  // (IslandLiveFace.leadPad / trailPad): the same optical gap as above and below
  readonly property Item sizedFace: sliding ? backFace : frontFace
  // the slot's width is moving: the island follows it as it goes, without a glide of its own
  readonly property bool moving: targetAnim.running
  // the other activities that run besides the shown one (Bar › Live › Behaviour): a "+3" plate after
  // the chip, or a column of dots (one per activity, the shown one lit, as many as fit the
  // chip's height) at the chip's left or right, or on a plate of their own
  readonly property int others: kind === "" ? 0 : Math.max(0, IslandService.activities.length - 1)
  readonly property bool dotted: ShellSettings.liveMore === "dots"
  readonly property string dotsAt: ShellSettings.liveDotsAt
  readonly property bool apart: others > 0 && (!dotted || dotsAt === "apart")     // a plate after the chip
  readonly property bool dotsIn: others > 0 && dotted && dotsAt !== "apart"       // dots inside the chip
  readonly property int dotSize: 5
  readonly property int dotGap: 4
  readonly property int dotCount: Math.min(IslandService.activities.length, Math.max(2, Math.floor((chipHeight - 8 + dotGap) / (dotSize + dotGap))))
  readonly property int dotLit: Math.min(dotCount - 1, Math.max(0, IslandService.activities.indexOf(kind)))
  readonly property int dotsWidth: dotsIn ? dotSize + Theme.gapMedium + 2 : 0
  readonly property int dotsShift: dotsAt === "left" ? dotsWidth : 0                // the face makes room at the left
  readonly property int moreWidth: !apart ? 0 : dotted ? dotSize + 2 * Theme.gapMedium : Math.max(chipHeight, more.implicitWidth + 2 * Theme.gapLoose)
  implicitWidth: kind === "" ? 0 : target + (apart ? edge + moreWidth : 0)
  implicitHeight: Theme.islandHeight
  width: implicitWidth
  height: implicitHeight
  visible: kind !== "" || opacity > 0
  opacity: kind === "" ? 0 : 1
  Behavior on opacity { enabled: Motion.island; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
  property real target: dotsWidth + sizedFace.implicitWidth + sizedFace.leadPad + sizedFace.trailPad
  Behavior on target { enabled: Motion.island; NumberAnimation { id: targetAnim; duration: Motion.normal; easing.type: Motion.easing } }

  function place() {
    const dir = IslandService.liveDirection(root.screen);
    if (!sliding) {
      frontFace.anchors.verticalCenterOffset = 0; frontFace.opacity = 1;
      backFace.opacity = 0;
      return;
    }
    frontFace.anchors.verticalCenterOffset = -dir * travel * t; frontFace.opacity = 1 - t;
    backFace.anchors.verticalCenterOffset = dir * travel * (1 - t); backFace.opacity = t;
  }
  onTChanged: place()

  onKindChanged: Qt.callLater(syncFace)
  onNoticeChanged: Qt.callLater(syncFace)

  function syncFace() {
    if (!ready) return;
    const incoming = sliding ? backFace : frontFace;
    if (incoming.kind === kind && (kind !== "notice" || incoming.notice === notice)) return;
    slide.stop();
    // A newer message can arrive before the previous transition finishes.
    if (sliding) {
      frontFace.kind = "";
      frontFace.notice = null;
      front = 1 - front;
    }
    sliding = false;
    // nothing before or nothing after: no slide, the face just is
    if (kind === "" || frontFace.kind === "" || !Motion.island) {
      frontFace.notice = notice;
      frontFace.kind = kind;
      backFace.kind = "";
      backFace.notice = null;
      place();
      return;
    }
    backFace.notice = notice;
    backFace.kind = kind;
    t = 0;
    sliding = true;
    slide.start();
  }

  NumberAnimation {
    id: slide
    target: root
    property: "t"
    from: 0
    to: 1
    duration: Motion.normal
    easing.type: Motion.easing
    onFinished: {
      root.sliding = false;
      root.frontFace.kind = "";
      root.frontFace.notice = null;
      root.front = 1 - root.front;
      root.place();
    }
  }

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: root.target
    height: root.chipHeight
    radius: root.chipRadius
    color: Theme.background1
  }

  // the "+3" plate, or the dots' own plate; a click pages to the next one, as the wheel does
  Rectangle {
    visible: root.apart
    x: root.target + root.edge
    anchors.verticalCenter: parent.verticalCenter
    width: root.moreWidth
    height: root.chipHeight
    radius: root.chipRadius
    color: Theme.background1

    KitText {
      id: more
      visible: !root.dotted
      anchors.centerIn: parent
      text: "+" + root.others
      color: Theme.muted
      font.pixelSize: Theme.fontSize - 1
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: IslandService.liveStep(1, root.screen)
    }
  }

  // the dots: inside the chip at its left or right, or centred on their plate
  Item {
    visible: root.others > 0 && root.dotted
    anchors.verticalCenter: parent.verticalCenter
    x: root.dotsAt === "left" ? Theme.gapMedium
     : root.dotsAt === "right" ? root.target - root.dotSize - Theme.gapMedium
     : root.target + root.edge + (root.moreWidth - root.dotSize) / 2
    width: root.dotSize
    height: dots.height

    Column {
      id: dots
      spacing: root.dotGap

      Repeater {
        model: root.dotCount

        Rectangle {
          required property int index
          width: root.dotSize
          height: root.dotSize
          radius: width / 2
          color: index === root.dotLit ? Theme.foreground0 : Theme.dim
          Behavior on color { enabled: Motion.island; ColorAnimation { duration: Motion.quick } }
        }
      }
    }

    MouseArea {
      anchors { fill: parent; margins: -Theme.gapSmall }
      cursorShape: Qt.PointingHandCursor
      onClicked: IslandService.liveStep(1, root.screen)
    }
  }

  IslandLiveFace { id: faceA; coverSize: root.coverSize; badgeRadius: root.badgeRadius; chipHeight: root.chipHeight; chipRadius: root.chipRadius; inset: root.inset; shift: root.dotsShift; inputEnabled: !root.sliding && !root.moving }
  IslandLiveFace { id: faceB; coverSize: root.coverSize; badgeRadius: root.badgeRadius; chipHeight: root.chipHeight; chipRadius: root.chipRadius; inset: root.inset; shift: root.dotsShift; inputEnabled: !root.sliding && !root.moving }

  Component.onCompleted: { ready = true; syncFace(); place(); }

  // the wheel pages; a click opens what the activity is about (IslandService.liveTarget:
  // the module's popup, else its options); on a notification it brings its
  // app up; a middle click plays or pauses the music, dismisses a notification; a right click
  // opens the activity's own options in the Shell Manager (as on a bar module)
  readonly property bool clickable: kind === "notice" || kind === "volume" || kind === "focus" && ShellSettings.liveFocusClick || IslandService.liveTarget[kind] !== undefined
  MouseArea {
    // Let the task face's pause and stop controls receive their own clicks.
    z: -1
    anchors.fill: parent
    acceptedButtons: Qt.RightButton | (root.clickable ? Qt.LeftButton | Qt.MiddleButton : Qt.NoButton)
    cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: mouse => {
      // Keep wheel paging live while the face or pill is animating, but don't
      // let a click land on a face whose identity is still changing.
      if (root.sliding || root.moving) return;
      if (mouse.button === Qt.RightButton) {
        if (ShellSettings.liveRightSettings) ShellIpc.call("shell", "open", ["live:" + root.kind]);
      } else if (root.kind === "notice") {
        // a click brings the app up (else the centre), a middle click dismisses
        if (mouse.button === Qt.LeftButton) IslandService.activate(IslandService.noticeItem);
        IslandService.dismissLiveNotice();
      } else if (root.kind === "update" && mouse.button === Qt.LeftButton && (RootService.pending || RootService.running)) {
        IslandService.requested("root", Hypr.focusedScreen?.name ?? "");
      } else if (root.kind === "focus") {
        if (ShellSettings.liveFocusClick) FocusService.toggle();     // no popup behind it: a click ends the mode (Bar › Live › Focus)
      } else if (mouse.button === Qt.MiddleButton) { if (root.kind === "music" || root.kind === "media") IslandService.toggleLive(root.kind); }
      else if (root.kind === "volume") BarLayout.openModule(IslandService.osdKind === "brightness" ? "brightness" : "audio");
      else BarLayout.openModule(IslandService.liveTarget[root.kind]);
    }
    onWheel: w => IslandService.liveStep(w.angleDelta.y < 0 ? 1 : -1, root.screen)
  }
}
