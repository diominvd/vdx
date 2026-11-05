import QtQuick
import qs.config

// A small status tag for a header ("1 NEW", "2 NEARBY"): a coloured square
// and small-caps text — no frame, so it never reads as a button.
Row {
  id: root

  property string text: ""
  property color tint: Theme.foreground2

  spacing: Theme.gapSmall

  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: 6
    height: 6
    radius: Theme.pill(height)
    color: root.tint

  }

  KitText {
    anchors.verticalCenter: parent.verticalCenter
    text: root.text
    color: root.tint
    font.pixelSize: Theme.fontSize - 2
    font.letterSpacing: 1
  }
}
