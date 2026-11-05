import QtQuick
import qs.config

// A tuning dial: a major tick for each station with minor ticks between, the
// stations sliding under a fixed marker. Drag to tune (the station is switched
// on release), a click on a tick or the wheel moves it by one.
Item {
  id: root

  property int count: 0                        // stations
  property int current: 0                      // the one on air (or the last one)
  property color tint: Theme.yellow
  signal tuned(int index)

  readonly property real stationWidth: 64
  readonly property int sub: 5                  // ticks to a station
  readonly property real tuning: Math.max(0, Math.min(count - 1, shown))   // the station under the marker, between two while it slides
  property real shown: current

  implicitHeight: 48
  clip: true
  onCurrentChanged: if (!dragging) shown = current
  property bool dragging: false                // the pointer is carrying the dial: it follows without gliding
  Behavior on shown { enabled: Motion.controls && !root.dragging; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }

  function settle(index) {
    const i = Math.max(0, Math.min(count - 1, index));
    shown = i;
    if (i !== current) tuned(i);
  }

  Repeater {
    model: root.count > 0 ? (root.count - 1) * root.sub + 1 : 0
    Rectangle {
      required property int index
      readonly property bool major: index % root.sub === 0
      readonly property real at: index / root.sub
      readonly property real cx: root.width / 2 + (at - root.shown) * root.stationWidth
      visible: cx > -4 && cx < root.width + 4
      x: cx - width / 2
      anchors.verticalCenter: parent.verticalCenter
      width: 2
      height: major ? 26 : 14
      radius: 1
      color: major ? Theme.foreground2 : Theme.background3
      // fades out towards both edges
      opacity: Math.max(0.15, 1 - Math.abs(cx - root.width / 2) / (root.width / 2))
    }
  }

  // the marker
  Rectangle {
    anchors.centerIn: parent
    width: 3
    height: 38
    radius: 1.5
    color: root.tint
  }

  MouseArea {
    id: drag
    property real startX: 0
    property real startShown: 0
    property bool moved: false
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onPressed: mouse => { startX = mouse.x; startShown = root.shown; moved = false; }
    onCanceled: root.dragging = false
    onPositionChanged: mouse => {
      if (!pressed) return;
      if (Math.abs(mouse.x - startX) > 4) moved = true;
      if (moved) root.dragging = true;
      if (moved) root.shown = Math.max(0, Math.min(root.count - 1, startShown - (mouse.x - startX) / root.stationWidth));
    }
    onReleased: mouse => {
      root.dragging = false;            // before the settling: the dial glides to the station
      if (moved) root.settle(Math.round(root.shown));
      else root.settle(Math.round(root.shown + (mouse.x - root.width / 2) / root.stationWidth));
    }
    onWheel: w => {
      root.shown = Math.max(0, Math.min(root.count - 1, Math.round(root.shown) + (w.angleDelta.y < 0 ? 1 : -1)));
      wheelTimer.restart();
    }
  }
  // the wheel steps fast: the station is switched when it rests
  Timer { id: wheelTimer; interval: 350; onTriggered: root.settle(Math.round(root.shown)) }
}
