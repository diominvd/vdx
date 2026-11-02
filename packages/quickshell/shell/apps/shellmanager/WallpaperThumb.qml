import QtQuick
import qs.config
import qs.kit
import Quickshell.Widgets

// One wallpaper picture in the Shell Manager: a 16:9 crop, framed like the
// colour swatches (thicker frame and a check when it is the one in use).
ClippingRectangle {
  radius: Theme.radiusCard
  id: root

  property string source: ""       // file path
  property bool active: false

  signal clicked()

  width: 96
  height: 54
  color: Theme.background1
  border.width: active || area.containsMouse ? Theme.ring : Theme.hairline
  border.color: active || area.containsMouse ? Theme.foreground2 : Theme.background3
  Behavior on border.color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

  Image {
    anchors { fill: parent; margins: root.border.width }
    source: root.source === "" ? "" : "file://" + root.source
    sourceSize: Qt.size(192, 108)
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
  }

  // the check sits on a background square so it reads on any picture
  Rectangle {
    radius: Theme.pill(height)
    visible: root.active
    anchors { right: parent.right; bottom: parent.bottom; margins: Theme.gapHair }
    width: 18
    height: 18
    color: Theme.background0

    KitIcon { anchors.centerIn: parent; name: "check"; size: 12; tint: Theme.green }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
