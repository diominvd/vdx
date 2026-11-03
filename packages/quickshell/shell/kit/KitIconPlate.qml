import QtQuick
import qs.config

// An icon on a plate one step above its surface: the face of an entry (a card, an
// entry's heading). `size` is the plate; the glyph takes about half of it.
Rectangle {
  id: root

  property string name: ""
  property color tint: Theme.foreground0
  property int size: Theme.controlHeight

  width: size
  height: size
  radius: Theme.radiusFor(size)
  color: Theme.fillOn(true)

  KitIcon {
    anchors.centerIn: parent
    name: root.name
    tint: root.tint
    size: Math.round(root.size / 2)
  }
}
