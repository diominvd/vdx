import QtQuick
import qs.config

// Put inside a list's row: a row that is new to `seen` (KitSeen) fades in and
// grows a little into place. Takes no room, so a Column or Row skips it. The
// row must not bind its own opacity.
Item {
  id: root

  property Item target: parent
  property KitSeen seen
  property string key

  width: 0
  height: 0

  ParallelAnimation {
    id: appear
    NumberAnimation { target: root.target; property: "opacity"; from: 0; to: 1; duration: Motion.normal; easing.type: Motion.easing }
    NumberAnimation { target: root.target; property: "scale"; from: Motion.lively ? 0.94 : 1; to: 1; duration: Motion.normal; easing.type: Motion.spring; easing.overshoot: Motion.overshoot }
  }

  Component.onCompleted: if (seen && key !== "" && seen.arrived(key)) appear.start()
}
