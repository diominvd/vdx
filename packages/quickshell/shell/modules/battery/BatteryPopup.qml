import QtQuick
import qs.components
import qs.config
import qs.kit

// Battery: charge and health, then the power saver switch (the profile, the charge limit
// and the GPU mode are in Settings › Power).
KitFrame {
  id: root

  signal closeRequested()

  // Modules › Battery › Compact popup: no health, cycles and energy
  readonly property bool compact: ModuleSettings.get("battery", "compact", false)
  readonly property string timeLeft: BatteryService.minutesLeft < 0 ? "—"
    : Math.floor(BatteryService.minutesLeft / 60) + ":" + String(BatteryService.minutesLeft % 60).padStart(2, "0")
  readonly property string summary: !BatteryService.ready ? "CHECKING BATTERY"
    : BatteryService.statusError !== "" ? "BATTERY STATUS UNAVAILABLE"
    : !BatteryService.present ? "NO BATTERY FOUND"
    : BatteryService.charging ? "CHARGING · " + timeLeft + " TO " + BatteryService.threshold + "%"
    : BatteryService.discharging ? "DISCHARGING · " + timeLeft + " LEFT"
    : BatteryService.plugged ? "PLUGGED IN" + (BatteryService.limitSupported ? " · LIMIT " + BatteryService.threshold + "%" : "")
    : "IDLE"
  readonly property color levelColor: BatteryService.capacity <= BatteryService.critical ? Theme.red
    : BatteryService.charging ? Theme.green
    : BatteryService.saver ? Theme.yellow
    : Theme.green
  // ---- header ----
  KitHeader {
    icon: !BatteryService.present ? "battery-full" : BatteryService.saver ? "battery-saver" : BatteryService.charging ? "battery-bolt"
      : BatteryService.plugged ? "battery-plugged" : BatteryService.levelIcon
    iconColor: !BatteryService.present ? Theme.muted : BatteryService.capacity <= BatteryService.critical && !BatteryService.plugged ? Theme.red : Theme.foreground0
    title: "Battery"
    subtitle: root.summary

    KitBadge {
      anchors.verticalCenter: parent.verticalCenter
      text: !BatteryService.ready ? "…" : BatteryService.capacityLabel
      tint: BatteryService.ready && BatteryService.present ? root.levelColor : Theme.muted
    }

    // the power saver: a quiet profile, slower and cooler
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

  // ---- charge ----
  Column {
    width: parent.width
    spacing: Theme.gapMedium
    visible: BatteryService.present

    KitLabel {
      text: "CHARGE"
      value: BatteryService.power > 0 ? BatteryService.power.toFixed(1) + " W" : "IDLE"
    }

    KitBar {
      value: BatteryService.capacity / 100
      tint: root.levelColor
    }

    Item { visible: !root.compact; width: 1; height: 2 }

    KitInfo {
      visible: !root.compact
      label: "Health"
      value: BatteryService.healthLabel
      valueColor: BatteryService.energyDesign > 0
        ? Theme.qualityColor(BatteryService.health, 80, 60) : Theme.muted
    }

    KitInfo { visible: !root.compact; label: "Cycles"; value: BatteryService.cyclesLabel }

    KitInfo {
      visible: !root.compact
      label: "Energy"
      value: BatteryService.energyLabel
    }
  }

  KitLine { visible: BatteryService.present }

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
      root.closeRequested();
      ShellIpc.call("shell", "open", ["power"]);
    }
  }
}
