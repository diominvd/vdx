import QtQuick
import qs.config
import qs.kit

// An icon-only button for a Shell Manager sidebar action.
Rectangle {
  id: button

  property string icon: ""
  property string label: ""
  property bool active: false

  signal clicked()

  width: Theme.navigationHeight + Theme.gapMedium
  height: width
  radius: Theme.radiusControl
  Accessible.role: Accessible.Button
  Accessible.name: label
  color: active ? Theme.pickFill : area.containsMouse ? Theme.controlHover : Theme.clear
  Behavior on color { enabled: Motion.pages; ColorAnimation { duration: Motion.quick } }

  KitIcon {
    anchors.centerIn: parent
    name: button.icon
    size: 18
    tint: button.active ? Theme.foreground0 : Theme.foreground2
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
