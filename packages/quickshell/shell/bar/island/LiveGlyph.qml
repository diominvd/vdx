import QtQuick
import qs.config
import qs.kit

// The glyph of a live activity, Material 3 style: a tonal circle (the activity's colour at a
// low strength) with the icon in that colour, as the avatar of a notification line is drawn.
Rectangle {
  id: root

  property string name: ""
  property color tint: Theme.foreground1
  property int size: 18
  property string glowTarget: "live"
  default property alias content: slot.data      // a drawing of its own instead of the icon (a ring)

  anchors.verticalCenter: parent ? parent.verticalCenter : undefined
  width: size
  height: size
  radius: Theme.pill(height)
  color: Theme.mix(Theme.background0, tint, 0.22)

  KitIcon {
    anchors.centerIn: parent
    visible: root.name !== ""
    name: root.name
    size: Math.round(root.size * 0.66)
    tint: root.tint
    glowTarget: root.glowTarget
  }
  Item { id: slot; anchors.centerIn: parent; width: parent.width; height: parent.height }
}
