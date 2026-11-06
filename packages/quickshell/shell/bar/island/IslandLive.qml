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
  readonly property real travel: Theme.islandHeight * 0.6

  // two faces take turns: `front` is the shown one; `t` runs 0 → 1 while a step slides
  property int front: 0
  property real t: 0
  property bool sliding: false
  readonly property Item frontFace: front === 0 ? faceA : faceB
  readonly property Item backFace: front === 0 ? faceB : faceA

  clip: sliding        // only while a step slides
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
  // the other activities that run besides the shown one: a "+3" plate after the chip
  readonly property int others: kind === "" ? 0 : Math.max(0, IslandService.activities.length - 1)
  readonly property int moreWidth: others > 0 ? Math.max(chipHeight, more.implicitWidth + 2 * Theme.gapLoose) : 0
  implicitWidth: kind === "" ? 0 : target + (others > 0 ? edge + moreWidth : 0)
  implicitHeight: Theme.islandHeight
  width: implicitWidth
  height: implicitHeight
  visible: kind !== "" || opacity > 0
  opacity: kind === "" ? 0 : 1
  Behavior on opacity { enabled: Motion.island; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
  property real target: sizedFace.implicitWidth + sizedFace.leadPad + sizedFace.trailPad
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

  onKindChanged: {
    slide.stop();
    sliding = false;
    // nothing before or nothing after: no slide, the face just is
    if (kind === "" || frontFace.kind === "" || !Motion.island) {
      frontFace.kind = kind;
      backFace.kind = "";
      place();
      return;
    }
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

  // a click pages to the next one, as the wheel does
  Rectangle {
    visible: root.others > 0
    x: root.target + root.edge
    anchors.verticalCenter: parent.verticalCenter
    width: root.moreWidth
    height: root.chipHeight
    radius: root.chipRadius
    color: Theme.background1

    KitText {
      id: more
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

  IslandLiveFace { id: faceA; coverSize: root.coverSize; badgeRadius: root.badgeRadius; chipHeight: root.chipHeight; chipRadius: root.chipRadius; inset: root.inset; inputEnabled: !root.sliding && !root.moving }
  IslandLiveFace { id: faceB; coverSize: root.coverSize; badgeRadius: root.badgeRadius; chipHeight: root.chipHeight; chipRadius: root.chipRadius; inset: root.inset; inputEnabled: !root.sliding && !root.moving }

  Component.onCompleted: { faceA.kind = kind; place(); }

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
