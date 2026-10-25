import QtQuick
import qs.config
import qs.kit

// A round icon button of the island's player: solid glyph, a soft disc on hover.
// In a `group` (an item with `hoverTarget`) the group draws the one disc instead.
Rectangle {
  id: root

  property string icon: ""
  property int iconSize: 20
  property var group: null
  property string accessibleName: ({
    "settings": "Open Shell Manager",
    "power": "Power options",
    "skip-back": "Previous track",
    "play": "Play",
    "pause": "Pause",
    "skip-forward": "Next track",
    "x": "Dismiss notification"
  }[icon] ?? icon)

  signal clicked()

  // Keep keyboard activation visibly pressed for as long as the key is held.
  property bool keyboardPressed: false
  readonly property bool pressed: area.pressed || keyboardPressed

  implicitWidth: iconSize + 14
  implicitHeight: iconSize + 14
  radius: Theme.pill(width)
  color: !group && (area.containsMouse || root.keyboardPressed) ? Theme.background1 : Theme.clear
  Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: "transparent"
    border.width: area.activeFocus ? Theme.focusRingWidth : 0
    border.color: Theme.focusRing
  }

  KitIcon {
    anchors.centerIn: parent
    name: root.icon
    size: root.iconSize
    solid: true
    scale: root.pressed ? 0.88 : 1
    Behavior on scale { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    Accessible.description: "Activate " + root.accessibleName.toLowerCase()
    cursorShape: Qt.PointingHandCursor
    onClicked: { forceActiveFocus(); root.clicked(); }
    onActiveFocusChanged: if (!activeFocus) root.keyboardPressed = false
    Keys.onPressed: event => {
      if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
      if (!event.isAutoRepeat) {
        root.keyboardPressed = true;
        root.clicked();
      }
      event.accepted = true;
    }
    Keys.onReleased: event => {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        root.keyboardPressed = false;
        event.accepted = true;
      }
    }
    // leaving only clears the group's target if it is still this button:
    // the next button's enter may come first
    onContainsMouseChanged: {
      if (!root.group) return;
      if (containsMouse) root.group.hoverTarget = root;
      else if (root.group.hoverTarget === root) root.group.hoverTarget = null;
    }
  }
}
