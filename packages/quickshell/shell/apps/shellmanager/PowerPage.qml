import QtQuick
import qs.config
import qs.kit
import qs.modules.battery

// Power: the platform profile, the charge limit and the GPU mode (they were the Battery
// module's popup only). The writes are the service's, the same as the popup's.
Column {
  id: root
  readonly property Item previewItem: null

  readonly property string icon: "zap"
  readonly property string title: "Power"
  readonly property string description: "Power profile, battery charge limit and GPU mode."
  readonly property var jumps: []

  readonly property bool changed: false
  function reset() {}

  spacing: Theme.sectionGap

  // hardware that cannot change: said once, the rows stay away
  KitNotice {
    shown: BatteryService.ready && !BatteryService.present && BatteryService.profiles.length === 0
    icon: "info"
    title: "This computer has nothing to set here"
    text: "No battery and no power profiles were found: the charge limit and the profile are hidden."
  }

  Column {
    width: parent.width
    spacing: Theme.sectionGap
    visible: BatteryService.profiles.length > 0

    KitLabel { text: "PROFILE" }
    KitRow {
      label: "Power profile"
      hint: BatteryService.saver ? "Saver: quiet and slow" : "The one in use now"
      wide: true
      KitSegments {
        model: BatteryService.profiles.map(p => ({ label: p.charAt(0).toUpperCase() + p.slice(1), value: p }))
        current: BatteryService.profile
        onPicked: value => BatteryService.setProfile(value)
      }
    }
    KitGrouper {}
  }

  KitLine { visible: BatteryService.present && BatteryService.limitSupported && BatteryService.profiles.length > 0 }

  Column {
    width: parent.width
    spacing: Theme.sectionGap
    visible: BatteryService.present && BatteryService.limitSupported

    KitLabel { text: "CHARGE" }
    KitRow {
      label: "Charge limit"
      hint: "The battery stops charging here"
      wide: true
      KitSegments {
        model: BatteryService.limits.map(v => ({ label: v + "%", value: v }))
        current: BatteryService.threshold
        onPicked: value => BatteryService.setThreshold(value)
      }
    }
    KitGrouper {}
  }

  KitLine { visible: BatteryService.gpuMode !== "" }

  Column {
    id: gpu
    width: parent.width
    spacing: Theme.sectionGap
    visible: BatteryService.gpuMode !== ""

    // supergfxctl reports "Unknown" when nothing is pending
    readonly property string gpuNext: BatteryService.gpuPending === "Unknown" ? "" : BatteryService.gpuPending
    readonly property bool gpuPending: gpuNext !== "" && gpuNext !== BatteryService.gpuMode
      && !/no action/i.test(BatteryService.gpuAction)

    KitLabel { text: "GRAPHICS" }
    KitRow {
      label: "GPU"
      hint: gpu.gpuPending ? (BatteryService.gpuAction || "Reboot required").toLowerCase().replace(/^./, c => c.toUpperCase()) : "Graphics mode"
      wide: true
      KitSegments {
        model: [
          { label: "Integrated", value: "Integrated" },
          { label: "Hybrid",     value: "Hybrid" }
        ]
        current: gpu.gpuNext || BatteryService.gpuMode
        onPicked: value => BatteryService.setGpuMode(value)
      }
    }
    KitGrouper {}
  }

  KitLine { visible: BatteryService.present }

  // the action itself is the lock app's (apps/lock/Lock.qml reads ModuleSettings "power" › lid)
  Column {
    width: parent.width
    spacing: Theme.sectionGap
    visible: BatteryService.present

    KitLabel { text: "LID" }
    KitSelect {
      width: parent.width
      label: "Lid closed"; hint: "Anything but Suspend is handled by the shell"
      model: [{ label: "Suspend", value: "suspend" }, { label: "Lock", value: "lock" }, { label: "Lock and hibernate", value: "hibernate" },
              { label: "Shut down", value: "poweroff" }, { label: "Do nothing", value: "nothing" }]
      current: ModuleSettings.get("power", "lid", "suspend")
      onPicked: value => ModuleSettings.set("power", "lid", value)
    }
    KitGrouper {}
  }

  KitGrouper {}
}
