import QtQuick
import Quickshell
import qs.components
import qs.config

// A setting kept on another Shell Manager page, shown where it is also looked
// for: the label names it, the hint says where it is (`In <Page> › <Group>`).
// The whole row is the button (a chevron on the right): `shell open <target>`
// (e.g. "notifications", "appearance:accent"), or an app's window: `app` is its
// IPC target ("files" → `files toggle`).
Item {
  id: root

  property string label: ""
  property string hint: ""
  property string target: ""
  property string app: ""

  width: parent ? parent.width : 0
  implicitHeight: row.implicitHeight

  Rectangle {
    anchors { fill: parent; margins: -Theme.gapWide }   // the whole row of its KitGrouper box
    radius: Theme.radiusCard
    color: area.pressed || area.keyboardPressed ? Theme.background3 : area.containsMouse ? Theme.background2 : Theme.clear
    border.width: area.activeFocus ? 2 : 0
    border.color: Theme.foreground0

    Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
  }

  KitRow {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    label: root.label
    hint: root.hint

    KitIcon {
      name: "chevron-down"
      rotation: -90
      tint: Theme.foreground2
      size: Theme.fontSize + 1
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    activeFocusOnTab: true
    property bool keyboardPressed: false
    onActiveFocusChanged: if (!activeFocus) keyboardPressed = false
    Accessible.role: Accessible.Button
    Accessible.name: root.label
    Accessible.description: root.hint
    cursorShape: Qt.PointingHandCursor
    function activate() {
      forceActiveFocus();
      if (root.app !== "") ShellIpc.call(root.app, "toggle");
      else ShellIpc.call("shell", "open", [root.target]);
    }
    onClicked: activate()
    Keys.onPressed: event => {
      if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
      if (!event.isAutoRepeat) {
        keyboardPressed = true;
        activate();
      }
      event.accepted = true;
    }
    Keys.onReleased: event => {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        keyboardPressed = false;
        event.accepted = true;
      }
    }
  }
}
