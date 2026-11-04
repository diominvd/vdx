import QtQuick
import qs.bar
import qs.config
import qs.kit

// Bluetooth options in the Shell Manager: what the bar shows (Bar text).
Column {
  spacing: Theme.sectionGap

  KitLabel { text: "BAR" }
  BarTextRow { module: "bluetooth" }

  KitLine {}

  KitLinkRow {
    label: "Bluetooth"
    hint: "In Bluetooth"
    target: "bluetooth"
  }

  KitGrouper {}
}
