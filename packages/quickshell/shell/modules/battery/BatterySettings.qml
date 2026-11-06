import QtQuick
import qs.bar
import qs.config
import qs.kit

// Battery options in the Shell Manager.
Column {
  spacing: Theme.gapGroup

  KitLabel { text: "BAR" }
  BarTextRow { module: "battery" }

  KitOptionRow {
    visible: ModuleSettings.get("battery", "text", "content") === "content"
    module: "battery"; key: "shows"; fallback: "both"
    label: "Shows"
    model: [{ label: "Icon and charge", value: "both" }, { label: "Charge only", value: "charge" }]
  }

  // with the icon gone, a plus says it is charging
  KitToggleRow {
    visible: ModuleSettings.get("battery", "text", "content") === "content" && ModuleSettings.get("battery", "shows", "both") === "charge"
    module: "battery"; key: "plus"; fallback: true
    label: "Plus while charging"
    hint: "56+"
  }

  KitToggleRow {
    module: "battery"; key: "compact"; fallback: false
    label: "Compact popup"; hint: "Hides health, cycles, energy"
  }

  KitGrouper {}
}
