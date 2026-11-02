import QtQuick
import qs.components
import qs.config
import qs.kit

// Battery status and health, following the same header, label and info-row pattern as other popups.
KitFrame {
  id: root

  signal closeRequested()

  readonly property bool compact: ModuleSettings.get("battery", "compact", false)
  readonly property string timeLeft: BatteryService.minutesLeft < 0 ? "—"
    : Math.floor(BatteryService.minutesLeft / 60) + ":" + String(BatteryService.minutesLeft % 60).padStart(2, "0")
  readonly property string status: !BatteryService.ready ? "CHECKING BATTERY"
    : BatteryService.statusError !== "" ? "BATTERY STATUS UNAVAILABLE"
    : !BatteryService.present ? "NO BATTERY FOUND"
    : BatteryService.charging ? "CHARGING"
    : BatteryService.discharging ? "ON BATTERY"
    : BatteryService.plugged ? "PLUGGED IN" : "IDLE"
  readonly property color levelColor: BatteryService.capacity <= BatteryService.critical ? Theme.red
    : BatteryService.charging ? Theme.green
    : BatteryService.saver ? Theme.yellow : Theme.green

  KitHeader {
    icon: !BatteryService.present ? "battery-full"
      : BatteryService.saver ? "battery-saver"
      : BatteryService.charging ? "battery-bolt"
      : BatteryService.plugged ? "battery-plugged" : BatteryService.levelIcon
    iconColor: !BatteryService.present ? Theme.muted
      : BatteryService.capacity <= BatteryService.critical && !BatteryService.plugged ? Theme.red
      : BatteryService.saver ? Theme.yellow
      : BatteryService.charging ? Theme.green : Theme.foreground0
    title: "Battery"
    subtitle: root.status
    subtitleColor: BatteryService.capacity <= BatteryService.critical && BatteryService.discharging ? Theme.red
      : BatteryService.charging ? Theme.green
      : BatteryService.saver ? Theme.yellow : Theme.muted

    KitSwitch {
      anchors.verticalCenter: parent.verticalCenter
      visible: BatteryService.profiles.length > 0
      accessibleName: "Power saver"
      checked: BatteryService.saver
      disabled: BatteryService.busy !== null || (BatteryService.plugged && !BatteryService.saver)
      onToggled: {
        if (BatteryService.plugged && !BatteryService.saver) return;
        BatteryService.setSaver(!BatteryService.saver);
      }
    }
  }

  KitLine {}

  Column {
    width: parent.width
    spacing: Theme.gapMedium
    visible: BatteryService.present

    KitLabel {
      text: "CHARGE"
      value: BatteryService.capacityLabel
      valueColor: root.levelColor
    }

    KitBar {
      value: BatteryService.capacity / 100
      tint: root.levelColor
    }

    KitInfo {
      visible: BatteryService.charging || BatteryService.discharging
      label: BatteryService.charging ? "Time to " + BatteryService.threshold + "%"
        : "Time remaining"
      value: root.timeLeft
    }

    KitInfo {
      label: "Voltage"
      value: BatteryService.voltage > 0 ? BatteryService.voltage.toFixed(2) + " V" : "—"
    }

    KitInfo {
      label: "Power"
      value: BatteryService.power > 0 ? BatteryService.power.toFixed(1) + " W" : "—"
      valueColor: BatteryService.charging ? Theme.green : Theme.foreground0
    }

    KitInfo {
      visible: BatteryService.plugged
      label: "Charge limit"
      value: BatteryService.threshold + "%"
    }
  }

  KitLine { visible: BatteryService.present && !root.compact }

  Column {
    visible: BatteryService.present && !root.compact
    width: parent.width
    spacing: Theme.gapMedium

    KitLabel { text: "BATTERY HEALTH" }

    KitInfo {
      label: "Condition"
      value: BatteryService.healthLabel
      valueColor: BatteryService.energyDesign > 0
        ? Theme.qualityColor(BatteryService.health, 80, 60) : Theme.muted
    }

    KitInfo { label: "Cycles"; value: BatteryService.cyclesLabel }
    KitInfo { label: "Energy"; value: BatteryService.energyLabel }
  }

  KitText {
    width: parent.width
    visible: BatteryService.ready && !BatteryService.present && BatteryService.statusError === ""
    text: "No battery was found on this computer."
    color: Theme.muted
    wrapMode: Text.WordWrap
  }

  KitText {
    width: parent.width
    visible: !BatteryService.ready
    text: "Checking battery status…"
    color: Theme.muted
    wrapMode: Text.WordWrap
  }

  KitText {
    width: parent.width
    visible: BatteryService.error !== ""
    text: BatteryService.error
    color: Theme.red
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSize - 1
  }

  KitLine { visible: BatteryService.error !== "" }

  KitButton {
    width: parent.width
    icon: "sliders"
    text: "Open settings"
    onClicked: {
      root.closeRequested()
      ShellIpc.call("shell", "open", ["power"])
    }
  }
}
