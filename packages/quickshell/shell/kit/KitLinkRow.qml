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
    // Match the exact insets KitGrouper uses for this row, so the hover fill
    // lands on the card's edge instead of poking past it.
    anchors {
      fill: parent
      leftMargin: -Theme.groupInset
      rightMargin: -Theme.groupInset
      topMargin: -Theme.settingsRowInset
      bottomMargin: -Theme.settingsRowInset
    }
    radius: Theme.radiusCard
    color: area.containsMouse ? Theme.background2 : Theme.clear

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
    cursorShape: Qt.PointingHandCursor
    onClicked: root.app !== "" ? ShellIpc.call(root.app, "toggle") : ShellIpc.call("shell", "open", [root.target])
  }
}
