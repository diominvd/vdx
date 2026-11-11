import QtQuick
import qs.config
import qs.kit

// A direct page link in the Shell Manager's sidebar. `entry` is the section
// ({value, label, icon}); `current` is the open page.
Rectangle {
  id: row

  property var entry
  property string current: ""
  readonly property bool active: entry.value === current

  signal picked()

  height: Theme.navigationHeight
  radius: Theme.radiusControl
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: entry.label
  Accessible.description: active ? "Current page" : ""
  Accessible.onPressAction: picked()
  Keys.onReturnPressed: picked()
  Keys.onSpacePressed: picked()
  border.width: activeFocus ? Theme.focusWidth : 0
  border.color: Theme.focusRing
  color: active ? Theme.pickFill : area.containsMouse || activeFocus ? Theme.controlHover : Theme.clear
  Behavior on color { enabled: Motion.pages; ColorAnimation { duration: Motion.quick } }

  KitIconTile {
    id: icon
    visible: ShellSettings.menuIcons
    anchors { left: parent.left; leftMargin: ShellSettings.iconTiles ? Theme.gapSmall : Theme.gapLoose; verticalCenter: parent.verticalCenter }
    name: row.entry.icon
    active: row.active
    hovered: area.containsMouse
    tint: row.active ? Theme.foreground0 : Theme.foreground2
    glyph: 16
  }

  KitText {
    anchors { left: ShellSettings.menuIcons ? icon.right : parent.left; leftMargin: Theme.gapLoose; right: parent.right; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
    text: row.entry.label
    elide: Text.ElideRight
    color: row.active ? Theme.foreground0 : Theme.foreground2
    font.weight: row.active ? Theme.pickWeight : Font.Normal
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: row.active ? Qt.ArrowCursor : Qt.PointingHandCursor
    onClicked: row.picked()
  }
}
