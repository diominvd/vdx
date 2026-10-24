import QtQuick
import qs.config
import qs.kit

// A checkbox for the package lists: a square outline; a check when picked, a
// bar when only some of a group are (`partial`). A control: its frame and fill
// follow Appearance › Controls.
Rectangle {
  id: root

  property bool checked: false
  property bool partial: false
  property string accessibleName: qsTr("Select package")
  signal toggled()

  width: 16
  height: 16
  radius: Math.min(Theme.radiusControl, 4)
  color: checked || partial ? Theme.background3 : Theme.controlFill
  border.width: activeFocus ? 2 : Theme.frameWidth
  border.color: activeFocus ? Theme.foreground0 : checked || partial ? Theme.foreground0 : Theme.muted

  activeFocusOnTab: enabled
  Accessible.role: Accessible.CheckBox
  Accessible.name: accessibleName
  Accessible.checked: checked
  Accessible.description: partial ? qsTr("Partially selected") : checked ? qsTr("Selected") : qsTr("Not selected")

  Keys.onPressed: event => {
    if (event.key !== Qt.Key_Space && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) return;
    if (!event.isAutoRepeat && enabled) toggled();
    event.accepted = true;
  }

  KitIcon {
    anchors.centerIn: parent
    visible: root.checked && !root.partial
    name: "check"
    solid: false
    size: 12
    tint: Theme.foreground0
  }

  Rectangle {
    anchors.centerIn: parent
    visible: root.partial
    width: 8
    height: 2
    color: Theme.foreground0
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: {
      if (!root.enabled) return;
      root.forceActiveFocus();
      root.toggled();
    }
  }
}
