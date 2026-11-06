import QtQuick
import qs.bar
import qs.config
import qs.kit

// Mihomo options in the Shell Manager: the bar face's text.
Column {
  spacing: Theme.gapGroup

  KitLabel { text: "BAR" }
  BarTextRow { module: "mihomo" }

  KitLabel { text: "POPUP" }

  KitToggleRow {
    module: "mihomo"; key: "compact"; fallback: false
    label: "Compact popup"; hint: "Hides ping, provider, traffic"
  }

  KitRow {
    wide: true
    label: "Servers shown"
    hint: "Listed before it scrolls"

    KitSegments {
      model: [{ label: "5", value: 5 }, { label: "8", value: 8 }, { label: "10", value: 10 }, { label: "15", value: 15 }]
      current: ModuleSettings.get("mihomo", "serverRows", Theme.visibleRows)
      onPicked: value => ModuleSettings.set("mihomo", "serverRows", value)
    }
  }

  KitGrouper {}
}
