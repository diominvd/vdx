import QtQuick
import qs.config

// Shared progress treatment for every live activity: one height, radius,
// track colour and a short eased fill update.
Rectangle {
  id: root

  property real value: 0
  property color tint: Theme.blue

  implicitWidth: 70
  implicitHeight: 4
  height: implicitHeight
  radius: Theme.pill(height)
  color: Theme.background3

  Rectangle {
    width: parent.width * Math.max(0, Math.min(1, root.value))
    height: parent.height
    radius: parent.radius
    color: root.tint
    Behavior on width {
      enabled: Motion.controls
      NumberAnimation { duration: Motion.quick; easing.type: Motion.easing }
    }
  }
}
