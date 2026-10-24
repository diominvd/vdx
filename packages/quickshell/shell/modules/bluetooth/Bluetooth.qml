import QtQuick
import Quickshell
import qs.bar
import qs.components
import qs.config
import qs.kit

// Bar module: the name of the connected device (or the icon alone), green while one is connected.
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  readonly property string device: BluetoothService.mainDevice?.name ?? ""
  readonly property string name: device.length > BluetoothService.barMaxLength
    ? device.slice(0, BluetoothService.barMaxLength - 1) + Theme.ellipsis
    : device

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("bluetooth")
  Accessible.description: "Open Bluetooth devices and settings"

  Keys.onPressed: event => {
    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
    if (!event.isAutoRepeat) { popup.toggle(); }
    event.accepted = true;
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusControl
    color: "transparent"
    border.width: root.activeFocus ? 2 : 0
    border.color: Theme.foreground0
  }

  KitBarItem {
    id: label
    icon: BluetoothService.powered ? "bluetooth" : "bluetooth-off"
    text: BarLayout.faceText("bluetooth", BluetoothService.mainDevice ? root.name : "--")
    tint: BluetoothService.mainDevice ? Theme.accentFor("modules", Theme.green) : Theme.gray
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); popup.toggle(); }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "bluetooth"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    onShown: BluetoothService.popupShown()

    BluetoothPopup {
      id: content
      anchors.fill: parent
    }
  }
}
