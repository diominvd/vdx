import QtQuick
import qs.components
import qs.config
import qs.kit

// The Bluetooth list: the connection (the main device, its battery), the devices
// connected, paired and nearby (a scan finds the new ones), and the scan in the footer.
Column {
  id: root
  // rows already on show: a new one eases in (KitAppear)
  property KitSeen seen: KitSeen {}
  readonly property var main: BluetoothService.mainDevice
  readonly property var battery: main ? main.battery : null

  spacing: Theme.gapGroup

  // ---- header ----
  KitHeader {
    icon: BluetoothService.powered ? "bluetooth" : "bluetooth-off"
    iconColor: BluetoothService.mainDevice ? Theme.foreground0 : Theme.muted
    title: "Bluetooth"
    subtitle: !BluetoothService.powered ? "OFF"
      : BluetoothService.mainDevice ? "CONNECTED"
      : "NOT CONNECTED"

    KitBadge {
      anchors.verticalCenter: parent.verticalCenter
      visible: BluetoothService.powered
      text: BluetoothService.devices.length + (BluetoothService.devices.length === 1 ? " DEVICE" : " DEVICES")
      tint: Theme.muted
    }

    KitSwitch {
      accessibleName: "Bluetooth"
      anchors.verticalCenter: parent.verticalCenter
      checked: BluetoothService.powered
      disabled: BluetoothService.toggling
      onToggled: BluetoothService.togglePower()
    }
  }

  KitLine {}

  KitText {
    width: parent.width
    visible: BluetoothService.error !== ""
    text: BluetoothService.error
    color: Theme.red
    wrapMode: Text.WordWrap
  }

  KitLabel {
    visible: !BluetoothService.powered && BluetoothService.error === ""
    text: "BLUETOOTH IS OFF"
  }

  KitText {
    width: parent.width
    visible: BluetoothService.powered && BluetoothService.error === "" && BluetoothService.devices.length === 0
    text: "No devices yet. Rescan finds the ones nearby."
    color: Theme.muted
    wrapMode: Text.WordWrap
  }

  // ---- connection ----
  Column {
    width: parent.width
    visible: root.main !== null
    spacing: Theme.gapLoose

    KitLabel { text: "CONNECTION" }

    Item {
      width: parent.width
      height: deviceName.implicitHeight

      KitText {
        id: deviceName
        width: Math.max(0, parent.width - deviceBattery.implicitWidth - 12)
        text: root.main?.name ?? ""
        elide: Text.ElideRight
      }

      KitText {
        id: deviceBattery
        anchors.right: parent.right
        text: root.battery !== null ? root.battery + " %" : "Connected"
        color: root.battery !== null ? Theme.qualityColor(root.battery, 60, 25) : Theme.muted
        font.pixelSize: Theme.fontSize - 1
      }
    }

    KitBar {
      visible: root.battery !== null
      value: (root.battery ?? 0) / 100
      tint: Theme.qualityColor(root.battery ?? 0, 60, 25)
    }
  }

  KitLine { visible: root.main !== null }

  // ---- devices ----
  Flickable {
    width: parent.width
    visible: BluetoothService.powered && BluetoothService.devices.length > 0
    height: Math.min(contentHeight, 30 * Theme.visibleRows)
    contentHeight: list.implicitHeight
    interactive: contentHeight > height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: list
      width: parent.width
      spacing: Theme.gapGroup

      Column {
        id: connected
        width: parent.width
        visible: BluetoothService.connectedDevices.length > 0
        spacing: Theme.gapMedium

        KitLabel { text: "CONNECTED (" + BluetoothService.connectedDevices.length + ")" }

        Repeater {
          model: BluetoothService.connectedDevices
          DeviceRow {
            id: connectedRow
            width: connected.width
            KitAppear { target: connectedRow; seen: root.seen; key: connectedRow.modelData.mac }
          }
        }
      }

      Column {
        id: paired
        width: parent.width
        visible: BluetoothService.pairedDevices.length > 0
        spacing: Theme.gapMedium

        KitLabel { text: "PAIRED (" + BluetoothService.pairedDevices.length + ")" }

        Repeater {
          model: BluetoothService.pairedDevices
          DeviceRow {
            id: pairedRow
            width: paired.width
            KitAppear { target: pairedRow; seen: root.seen; key: pairedRow.modelData.mac }
          }
        }
      }

      Column {
        id: nearby
        width: parent.width
        visible: BluetoothService.nearbyDevices.length > 0
        spacing: Theme.gapMedium

        KitLabel { text: "NEARBY (" + BluetoothService.nearbyDevices.length + ")" }

        Repeater {
          model: BluetoothService.nearbyDevices
          DeviceRow {
            id: nearbyRow
            width: nearby.width
            KitAppear { target: nearbyRow; seen: root.seen; key: nearbyRow.modelData.mac }
          }
        }
      }
    }
  }

  KitLine {}

  // ---- actions ----
  KitText {
    width: parent.width
    visible: BluetoothService.actionError !== ""
    text: BluetoothService.actionError
    color: Theme.red
    wrapMode: Text.WordWrap
  }

  Row {
    spacing: Theme.gapMedium

    KitButton {
      icon: "refresh"
      text: "Rescan"
      busy: BluetoothService.scanning
      disabled: !BluetoothService.powered || BluetoothService.scanning
      onClicked: BluetoothService.scan()
    }
  }
}
