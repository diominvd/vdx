import QtQuick
import qs.config
import qs.kit

// Battery: charge and health, then the power settings (saver, charge limit,
// platform profile, GPU mode).
KitFrame {
  id: root

  readonly property string timeLeft: BatteryService.minutesLeft < 0 ? "—"
    : Math.floor(BatteryService.minutesLeft / 60) + ":" + String(BatteryService.minutesLeft % 60).padStart(2, "0")
  readonly property string summary: BatteryService.charging ? "CHARGING · " + timeLeft + " TO " + BatteryService.threshold + "%"
    : BatteryService.discharging ? "DISCHARGING · " + timeLeft + " LEFT"
    : BatteryService.plugged ? "PLUGGED IN" + (BatteryService.limitSupported ? " · LIMIT " + BatteryService.threshold + "%" : "")
    : "IDLE"
  readonly property color levelColor: BatteryService.capacity <= BatteryService.critical ? Theme.red
    : BatteryService.capacity <= BatteryService.warning ? Theme.yellow : Theme.green
  // supergfxctl reports "Unknown" when nothing is pending
  readonly property string gpuNext: BatteryService.gpuPending === "Unknown" ? "" : BatteryService.gpuPending
  readonly property bool gpuPending: gpuNext !== "" && gpuNext !== BatteryService.gpuMode
    && !/no action/i.test(BatteryService.gpuAction)
  readonly property var selects: [limit, profile, gpu]

  // At most one select open at a time.
  function collapseOthers(open) {
    for (const s of selects) if (s !== open) s.expanded = false;
  }

  // ---- header ----
  KitHeader {
    icon: BatteryService.saver ? "battery-saver" : BatteryService.charging ? "battery-bolt"
      : BatteryService.plugged ? "battery-plugged" : BatteryService.levelIcon
    iconColor: BatteryService.capacity <= BatteryService.critical && !BatteryService.plugged ? Theme.red : Theme.foreground0
    title: "Battery"
    subtitle: root.summary

    KitBadge {
      anchors.verticalCenter: parent.verticalCenter
      text: BatteryService.capacity + "%"
      tint: root.levelColor
    }
  }

  KitLine {}

  // ---- charge ----
  Column {
    width: parent.width
    spacing: Theme.gapMedium

    KitLabel {
      text: "CHARGE"
      value: BatteryService.power > 0 ? BatteryService.power.toFixed(1) + " W" : "IDLE"
    }

    KitBar {
      value: BatteryService.capacity / 100
      tint: root.levelColor
    }

    Item { width: 1; height: 2 }

    KitInfo {
      label: "Health"
      value: BatteryService.health + "%"
      valueColor: Theme.qualityColor(BatteryService.health, 80, 60)
    }

    KitInfo { label: "Cycles"; value: String(BatteryService.cycles) }

    KitInfo {
      label: "Energy"
      value: BatteryService.energy.toFixed(1) + " / " + BatteryService.energyDesign.toFixed(1) + " Wh"
    }
  }

  KitLine {}

  // ---- power settings ----
  Column {
    width: parent.width
    spacing: Theme.gapLoose

    KitLabel { text: "POWER" }

    KitRow {
      visible: BatteryService.profiles.includes(BatteryService.saverProfile)
      label: "Power saver"
      hint: "Quiet profile, longer battery"

      KitSwitch {
        accessibleName: "Power saver"
        checked: BatteryService.saver
        onToggled: BatteryService.setSaver(!BatteryService.saver)
      }
    }

    KitSelect {
      id: limit
      visible: BatteryService.limitSupported
      label: "Charge limit"
      hint: "Stop charging at"
      model: BatteryService.limits.map(v => ({ label: v + "%", value: v }))
      current: BatteryService.threshold
      busy: model.some(c => c.value === BatteryService.busy)
      onPicked: value => BatteryService.setThreshold(value)
      onExpandedChanged: if (expanded) root.collapseOthers(limit)
    }

    KitSelect {
      id: profile
      label: "Profile"
      hint: "Platform profile"
      model: BatteryService.profiles.map(p => ({ label: p, value: p }))
      current: BatteryService.profile
      busy: model.some(c => c.value === BatteryService.busy)
      onPicked: value => BatteryService.setProfile(value)
      onExpandedChanged: if (expanded) root.collapseOthers(profile)
    }

    KitSelect {
      id: gpu
      visible: BatteryService.gpuMode !== ""
      label: "GPU"
      hint: root.gpuPending ? (BatteryService.gpuAction || "Reboot required").toLowerCase().replace(/^./, c => c.toUpperCase()) : "Graphics mode"
      hintColor: root.gpuPending ? Theme.orange : Theme.muted
      model: [
        { label: "Integrated", value: "Integrated" },
        { label: "Hybrid",     value: "Hybrid" }
      ]
      current: root.gpuNext || BatteryService.gpuMode
      busy: model.some(c => c.value === BatteryService.busy)
      onPicked: value => BatteryService.setGpuMode(value)
      onExpandedChanged: if (expanded) root.collapseOthers(gpu)
    }
  }

  KitText {
    width: parent.width
    visible: BatteryService.error !== ""
    text: BatteryService.error
    color: Theme.red
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSize - 1
  }
}
