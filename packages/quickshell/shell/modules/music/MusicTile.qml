import QtQuick
import qs.config
import qs.kit

// A tile of the library: an icon in its square, the name and a small-caps line under
// it, a note playing on the one that plays, a spinner on the one starting; a click on it.
Rectangle {
  id: root

  property string icon: "music"
  property color iconTint: Theme.foreground2
  property string text: ""
  property string caption: ""
  property bool current: false
  property bool busy: false

  signal clicked()

  height: 52
  radius: Theme.radiusCard
  color: current ? Theme.background3 : area.containsMouse ? Theme.background2 : Theme.background1
  Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

  Rectangle {
    id: badge
    anchors { left: parent.left; leftMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
    width: 32
    height: 32
    radius: Theme.radiusControl
    color: root.current ? Theme.background1 : Theme.background0

    KitIcon {
      anchors.centerIn: parent
      name: root.icon
      tint: root.iconTint
      size: Theme.iconSmall + 2
    }
  }

  Column {
    anchors { left: badge.right; leftMargin: Theme.gapLoose; right: mark.left; rightMargin: Theme.gapMedium
              verticalCenter: parent.verticalCenter }
    spacing: Theme.gapHair

    KitText {
      width: parent.width
      text: root.text
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: root.current || area.containsMouse ? Theme.foreground0 : Theme.foreground2
      Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.normal; easing.type: Motion.easing } }
      font.weight: root.current ? Font.ExtraBold : Font.DemiBold
    }

    KitText {
      width: parent.width
      visible: text !== ""
      text: root.caption.toUpperCase()
      elide: Text.ElideRight
      color: Theme.muted
      font.pixelSize: Theme.fontSize - 3
      font.letterSpacing: 1
    }
  }

  Item {
    id: mark
    anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
    width: root.busy || root.current ? 14 : 0
    height: 14

    KitSpinner {
      anchors.centerIn: parent
      visible: root.busy
    }

    KitIcon {
      anchors.centerIn: parent
      visible: root.current && !root.busy
      name: "volume"
      tint: Theme.foreground0
      size: Theme.iconSmall
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
