import QtQuick
import qs.config
import qs.kit

// A round icon button of the island's player: solid glyph, a soft disc on hover.
// In a `group` (an item with `hoverTarget`) the group draws the one disc instead.
// Material: a tonal disc at rest too (`tonal: false` keeps it bare).
Rectangle {
  id: root

  property string icon: ""
  property int iconSize: 20
  property color iconTint: Theme.foreground0
  property var group: null
  property bool tonal: true
  property bool filled: false              // Material: the one main control (play), filled with Theme.primary
  readonly property bool primary: filled && Theme.material && !group

  signal clicked()
  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: icon
  Accessible.onPressAction: clicked()
  Keys.onSpacePressed: clicked()
  Keys.onReturnPressed: clicked()

  implicitWidth: Math.max(Theme.controlHeight, iconSize + 14)
  implicitHeight: implicitWidth
  radius: Theme.pill(width)
  color: primary ? (area.containsMouse ? Theme.mix(Theme.primary, Theme.inkOn(Theme.primary), 0.08) : Theme.primary)
       : !group && (area.containsMouse || activeFocus) ? Theme.controlHover
       : !group && tonal && Theme.material ? Theme.controlFill : Theme.clear
  border.width: activeFocus ? Theme.focusWidth : 0
  border.color: Theme.focusRing
  Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

  KitIcon {
    anchors.centerIn: parent
    name: root.icon
    size: root.iconSize
    solid: true
    tint: root.primary ? Theme.inkOn(Theme.primary) : root.iconTint
    scale: area.pressed ? 0.88 : 1
    Behavior on scale { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
    // leaving only clears the group's target if it is still this button:
    // the next button's enter may come first
    onContainsMouseChanged: {
      if (!root.group) return;
      if (containsMouse) root.group.hoverTarget = root;
      else if (root.group.hoverTarget === root) root.group.hoverTarget = null;
    }
  }
}
