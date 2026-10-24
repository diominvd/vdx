import QtQuick
import qs.config
import qs.kit

// A row of MusicMenu: the label on the left, a muted
// note on the right, a hover fill. `danger` reds the label (a removal),
// `disabled` greys it and ignores the click.
Item {
  id: root

  property string label: ""
  property string note: ""
  property bool danger: false
  property bool disabled: false
  property bool keyboardPressed: false

  signal activated()

  width: parent ? parent.width : 0
  implicitHeight: labelText.implicitHeight + 2 * Theme.gapTight
  activeFocusOnTab: !disabled
  Accessible.role: Accessible.Button
  Accessible.name: root.label
  Accessible.description: root.note
  onActiveFocusChanged: if (!activeFocus) keyboardPressed = false
  onDisabledChanged: if (disabled) keyboardPressed = false

  Keys.onPressed: event => {
    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
    if (!event.isAutoRepeat && !disabled) {
      keyboardPressed = true;
      activated();
    }
    event.accepted = true;
  }
  Keys.onReleased: event => {
    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
    keyboardPressed = false;
    event.accepted = true;
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusControl
    color: root.keyboardPressed ? Theme.background3
      : !root.disabled && (area.containsMouse || root.activeFocus) ? Theme.controlHover : Theme.clear
    border.width: root.activeFocus ? Math.max(2, Theme.frameWidth) : 0
    border.color: Theme.foreground0
    Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    enabled: !root.disabled
    cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
    onClicked: root.activated()
  }

  KitText {
    id: labelText
    anchors {
      left: parent.left; leftMargin: Theme.gapMedium
      right: noteText.left; rightMargin: Theme.gapMedium
      verticalCenter: parent.verticalCenter
    }
    text: root.label
    elide: Text.ElideRight
    color: root.disabled ? Theme.muted : root.danger ? Theme.red : Theme.foreground0
    font.weight: Font.DemiBold
  }

  KitText {
    id: noteText
    anchors { right: parent.right; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
    text: root.note
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 2
  }
}
