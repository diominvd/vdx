import QtQuick
import qs.bar
import qs.config
import qs.kit

// Wifi options in the Shell Manager: what the bar shows (Bar text).
Column {
  spacing: Theme.sectionGap

  KitLabel { text: "BAR" }
  BarTextRow { module: "wifi" }

  KitToggleRow {
    module: "wifi"; key: "compact"; fallback: false
    label: "Compact popup"; hint: "Hides address, signal, traffic and DNS"
  }

  KitGrouper {}
}
