import QtQuick
import qs.config
import qs.kit
import qs.modules.bluetooth

// Bluetooth: the adapter (its name, visibility and pairing), the connected and paired
// devices (connect, trust, block) and the nearby ones (a scan finds them, a pair connects).
// Each group has the same order: its switch or state first, then the settings, then the facts.
KitColumn {
  id: root

  readonly property var bt: BluetoothService
  readonly property var adapter: bt.adapter

  readonly property var connected: bt.devices.filter(d => d.connected)
  readonly property var owned: bt.devices.filter(d => d.paired)
  property string selected: ""
  readonly property var chosen: owned.find(d => d.mac === selected) ?? owned[0] ?? null

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "bluetooth"
  readonly property string title: "Bluetooth"
  readonly property string subtitle: !bt.powered ? "OFF" : bt.mainDevice ? bt.mainDevice.name.toUpperCase() : "NOT CONNECTED"

  // groups for the Shell Manager's sidebar: a click scrolls to `y`
  readonly property var jumps: [
    { key: "adapter",   label: "Bluetooth", y: adapterGroup.y },
    { key: "connected", label: "Connected", y: root.connected.length > 0 ? connectedGroup.y : -2 },
    { key: "paired",    label: "Paired",    y: pairedGroup.y },
    { key: "nearby",    label: "Nearby",    y: nearbyGroup.y }
  ].filter(j => j.y > -2)

  spacing: Theme.gapGroup

  onVisibleChanged: if (visible) bt.popupShown()

  // ---- adapter ----
  KitLabel { id: adapterGroup; text: "BLUETOOTH"; value: bt.powered ? "ON" : "OFF" }

  KitRow {
    label: "Bluetooth"
    hint: "Off: nothing connects"

    KitSwitch {
      accessibleName: "Bluetooth"
      checked: bt.powered
      disabled: bt.toggling
      onToggled: bt.togglePower()
    }
  }

  KitRow {
    wide: true
    label: "Name"
    hint: "Shown to other devices"
    dimmed: !bt.powered

    KitInput {
      enabled: bt.powered
      text: root.adapter.alias
      placeholder: "name"
      onAccepted: bt.setAdapter(["--alias", text])
    }
  }

  KitRow {
    label: "Visible to others"
    hint: "Off: hidden"
    dimmed: !bt.powered

    KitSwitch {
      accessibleName: "Visible to others"
      checked: root.adapter.discoverable
      disabled: !bt.powered
      onToggled: bt.setAdapter(["--discoverable", root.adapter.discoverable ? "off" : "on"])
    }
  }

  KitRow {
    visible: root.adapter.discoverable
    wide: true
    label: "Visible for"
    hint: "Then hidden again"

    KitSegments {
      model: [{ label: "Forever", value: 0 }, { label: "2 min", value: 120 }, { label: "5 min", value: 300 }]
      current: root.adapter.timeout
      onPicked: value => bt.setAdapter(["--discoverable-timeout", String(value)])
    }
  }

  KitRow {
    label: "Pairable"
    hint: "Off: refuses new pairings"
    dimmed: !bt.powered

    KitSwitch {
      accessibleName: "Pairable"
      checked: root.adapter.pairable
      disabled: !bt.powered
      onToggled: bt.setAdapter(["--pairable", root.adapter.pairable ? "off" : "on"])
    }
  }

  KitLine {}

  // ---- connected devices: one row each ----
  KitLabel { id: connectedGroup; visible: root.connected.length > 0; text: "CONNECTED"; value: root.connected.length + " DEVICES" }

  Repeater {
    model: root.connected

    KitRow {
      required property var modelData

      label: modelData.name
      hint: modelData.battery !== null ? modelData.battery + " % battery" : "Connected"

      KitButton {
        width: Theme.buttonWidth
        text: "Disconnect"
        busy: bt.busyMac === modelData.mac
        disabled: bt.busyMac !== ""
        onClicked: bt.toggleDevice(modelData)
      }
    }
  }

  KitLine { visible: root.connected.length > 0 }

  // ---- paired devices ----
  KitLabel { id: pairedGroup; text: "PAIRED"; value: root.owned.length + " DEVICES" }

  KitSelect {
    visible: root.chosen !== null
    label: "Device"
    model: root.owned.map(d => ({ label: d.name, value: d.mac }))
    current: root.chosen?.mac ?? ""
    onPicked: value => root.selected = value
  }

  KitRow {
    visible: root.chosen !== null && !root.chosen.connected
    label: "Connection"
    hint: "Not connected"

    KitButton {
      width: Theme.buttonWidth
      text: "Connect"
      busy: bt.busyMac !== "" && bt.busyMac === root.chosen?.mac
      disabled: !bt.powered || bt.busyMac !== ""
      onClicked: bt.toggleDevice(root.chosen)
    }
  }

  KitRow {
    visible: root.chosen !== null
    label: "Connect automatically"
    hint: "Trusted: joins when near"

    KitSwitch {
      accessibleName: "Connect automatically"
      checked: root.chosen?.trusted ?? false
      onToggled: bt.setTrusted(root.chosen, !root.chosen.trusted)
    }
  }

  KitRow {
    visible: root.chosen !== null
    label: "Blocked"
    hint: "Refused; a connected one drops"

    KitSwitch {
      accessibleName: "Blocked"
      checked: root.chosen?.blocked ?? false
      onToggled: bt.setBlocked(root.chosen, !root.chosen.blocked)
    }
  }

  KitRow {
    visible: root.chosen !== null
    label: "Address"

    KitText { text: root.chosen?.mac ?? ""; color: Theme.foreground2 }
  }

  KitLine {}

  // ---- nearby ----
  KitLabel { id: nearbyGroup; text: "NEARBY"; value: bt.nearbyDevices.length + " FOUND" }

  KitRow {
    label: "Look for devices"
    hint: "Looks for 8 s"

    KitButton {
      width: Theme.buttonWidth
      text: "Rescan"
      busy: bt.scanning
      disabled: !bt.powered || bt.scanning
      onClicked: bt.scan()
    }
  }

  KitText {
    visible: bt.powered && bt.nearbyDevices.length === 0
    width: parent.width
    text: "Rescan finds devices nearby."
    color: Theme.muted
    wrapMode: Text.WordWrap
  }

  Repeater {
    model: bt.nearbyDevices

    KitRow {
      required property var modelData

      label: modelData.name
      hint: modelData.mac

      KitButton {
        width: Theme.buttonWidth
        text: "Pair"
        busy: bt.busyMac === modelData.mac
        disabled: !bt.powered || bt.busyMac !== ""
        onClicked: bt.toggleDevice(modelData)
      }
    }
  }

  KitGrouper {}
}
