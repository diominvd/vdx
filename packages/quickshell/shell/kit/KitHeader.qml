import QtQuick
import qs.config

// Popup header: an icon, a bold title and a small-caps subtitle with " · "
// between its parts; badges / buttons / a switch on the right (children).
Item {
  id: root

  property string icon: ""               // kit/icons name
  property color iconColor: Theme.foreground0
  property string title: ""
  property string subtitle: ""
  property color subtitleColor: Theme.muted

  default property alias actions: actionRow.data

  width: parent ? parent.width : 0
  implicitHeight: Math.max(caption.implicitHeight, actionRow.height)

  Item {
    id: icon
    anchors { left: parent.left; verticalCenter: caption.verticalCenter }
    width: 30
    height: 24

    KitIcon {
      anchors.verticalCenter: parent.verticalCenter
      name: root.icon
      tint: root.iconColor
      size: Theme.iconLarge
    }
  }

  Column {
    id: caption
    anchors {
      left: icon.right; leftMargin: Theme.gapMedium
    }
    // Action buttons can consume most of a compact header; never give the
    // title/subtitle column a negative width when the popup narrows.
    width: Math.max(0, root.width - icon.width - Theme.gapMedium - actionRow.width - (actionRow.width > 0 ? 10 : 0))
    spacing: 3

    KitText {
      width: parent.width
      text: root.title
      elide: Text.ElideRight
      font.pixelSize: Theme.fontSize + 3
      font.weight: Font.ExtraBold
    }

    KitText {
      width: parent.width
      visible: root.subtitle !== ""
      text: root.subtitle
      color: root.subtitleColor
      elide: Text.ElideRight
      font.pixelSize: Theme.fontSize - 2
      font.letterSpacing: 1
    }
  }

  Row {
    id: actionRow
    anchors { right: parent.right; verticalCenter: caption.verticalCenter }
    spacing: Theme.gapMedium
  }
}
