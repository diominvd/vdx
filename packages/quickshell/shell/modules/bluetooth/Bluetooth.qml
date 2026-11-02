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

  KitBarItem {
    id: label
    icon: BluetoothService.powered ? "bluetooth" : "bluetooth-off"
    text: BarLayout.faceText("bluetooth", BluetoothService.mainDevice ? root.name : "--")
    tint: BluetoothService.mainDevice ? Theme.green : Theme.gray
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.toggle()
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
