import QtQuick
import qs.config
import qs.kit

// A scrolling minute ruler. A fixed number of ticks stays readable while the
// visible range follows the selected value across the full duration.
Item {
  id: root

  property int value: 15
  property int from: 1
  property int to: 1440
  property int majorEvery: 10
  property int visibleTicks: 60
  property color tint: Theme.orange
  property real dragStartX: 0
  property int dragStartValue: 1
  signal moved(int value)

  readonly property int ticks: visibleTicks + 1
  readonly property int firstValue: Math.max(from, Math.min(to - visibleTicks, value - Math.floor(visibleTicks / 2)))
  readonly property real step: width / visibleTicks

  implicitHeight: 44

  function setAt(x) {
    const v = Math.max(from, Math.min(to, firstValue + Math.round(x / step)));
    if (v !== value) moved(v);
  }
  function setDragged(x) {
    const v = Math.max(from, Math.min(to, dragStartValue + Math.round((x - dragStartX) / step)));
    if (v !== value) moved(v);
  }

  Repeater {
    model: root.ticks
    Rectangle {
      required property int index
      readonly property int minute: root.firstValue + index
      readonly property bool major: minute % root.majorEvery === 0
      x: index * root.step + (root.step - width) / 2
      y: major ? 14 : 18
      width: 2
      height: root.height - y
      radius: width / 2
      color: minute <= root.value && minute >= root.from ? root.tint : Theme.background3
      Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
    }
  }
  Repeater {
    model: root.ticks
    KitText {
      required property int index
      readonly property int minute: root.firstValue + index
      visible: minute % root.majorEvery === 0
      x: Math.max(0, Math.min(root.width - width, index * root.step - width / 2))
      y: 0
      text: minute > 0 && minute % 60 === 0 ? (minute / 60) + "h" : String(minute)
      color: minute <= root.value ? root.tint : Theme.muted
      font.pixelSize: Theme.fontSize - 3
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onPressed: mouse => { root.dragStartX = mouse.x; root.dragStartValue = root.value; root.setAt(mouse.x); }
    onPositionChanged: mouse => { if (pressed) root.setDragged(mouse.x); }
    onWheel: w => {
      const v = Math.max(root.from, Math.min(root.to, root.value + (w.angleDelta.y > 0 ? 1 : -1)));
      if (v !== root.value) root.moved(v);
    }
  }
}
