import QtQuick
import qs.config

// Popup header: an icon, a bold title and a small-caps subtitle with " · "
// between its parts; badges / buttons / a switch on the right (children).
// `page`: a window page's own header — in Strict a large title, no icon; its `description`
// is the tooltip of an info mark beside the title.
Item {
  id: root

  property string icon: ""               // kit/icons name
  property color iconColor: Theme.foreground0
  property string title: ""
  property string subtitle: ""
  property string crumb: ""                 // a page: the sidebar group it sits in (BAR)
  property string description: ""           // a page: one or two lines on what it is for
  property color subtitleColor: Theme.muted
  property bool page: false
  property bool logo: false                 // the shell's logo (kit/logo.png) instead of the icon
  readonly property bool large: page
  readonly property Item kitCaption: caption
  readonly property bool isKitHeader: true       // KitFrame: stands on the surface, never in a section
  // Material: the icon sits in a tonal circle of its colour
  readonly property bool m3: Theme.material && !large

  readonly property bool stackedActions: page && actionRow.implicitWidth + 140 + Theme.gapMedium > width
  default property alias actions: actionRow.data

  width: parent ? parent.width : 0
  implicitHeight: stackedActions ? caption.implicitHeight + Theme.gapMedium + actionRow.height : Math.max(caption.implicitHeight, actionRow.height, m3 && icon.visible ? icon.height : 0)

  Item {
    id: icon
    anchors { left: parent.left; verticalCenter: caption.verticalCenter }
    visible: !root.large
    width: !visible ? 0 : root.logo ? 34 : root.m3 ? Theme.controlHeight : 30
    height: root.m3 ? Theme.controlHeight : 24

    Rectangle {
      visible: root.m3
      anchors.fill: parent
      radius: Theme.radiusFor(height)
      color: Theme.tonal(root.iconColor, 0.2)
    }

    Image {
      visible: root.logo
      anchors.verticalCenter: parent.verticalCenter
      width: 28; height: 28
      source: root.logo ? Qt.resolvedUrl("logo.png") : ""
      sourceSize: Qt.size(56, 56)
      smooth: true
    }

    KitIcon {
      visible: !root.logo
      anchors.verticalCenter: parent.verticalCenter
      anchors.horizontalCenter: root.m3 ? parent.horizontalCenter : undefined
      name: root.icon
      tint: root.iconColor
      size: root.m3 ? Theme.iconLarge - 4 : Theme.iconLarge
    }
  }

  Column {
    id: caption
    // A shared header height must not leave unused space below the caption.
    y: root.stackedActions ? 0 : root.m3 ? (root.height - height) / 2 : Math.max(0, root.height - height)
    anchors {
      left: icon.right; leftMargin: icon.visible ? (root.m3 ? Theme.gapWide : Theme.gapMedium) : 0
      right: root.stackedActions ? parent.right : actionRow.left; rightMargin: !root.stackedActions && actionRow.width > 0 ? 10 : 0
    }
    spacing: root.large ? Theme.gapHair : 3

    KitText {
      width: parent.width
      visible: root.large && root.crumb !== ""
      text: root.crumb
      color: Theme.muted
      font.pixelSize: Theme.fontSize - 3
      font.letterSpacing: 1
    }

    Row {
      width: parent.width
      spacing: Theme.gapWide

      KitText {
        width: Math.min(implicitWidth, parent.width - (descTip.visible ? descTip.width + parent.spacing : 0))
        text: root.title
        elide: Text.ElideRight
        font.pixelSize: Theme.fontSize + (root.large ? 9 : 3)
        font.weight: root.large ? Font.Medium : Font.DemiBold
      }

      // a page: what it is for, in a tooltip
      KitTip {
        id: descTip
        visible: root.large && root.description !== ""
        anchors.verticalCenter: parent.verticalCenter
        size: Theme.fontSize + 3
        text: root.description
      }
    }

    KitText {
      width: parent.width
      visible: root.subtitle !== ""
      text: root.subtitle
      color: root.subtitleColor
      elide: Text.ElideRight
      font.pixelSize: Theme.fontSize - 2
      font.letterSpacing: 0.6
    }
  }

  Row {
    id: actionRow
    anchors.right: parent.right
    y: root.stackedActions ? caption.implicitHeight + Theme.gapMedium : caption.y + (caption.implicitHeight - height) / 2
    spacing: Theme.gapMedium
  }
}
