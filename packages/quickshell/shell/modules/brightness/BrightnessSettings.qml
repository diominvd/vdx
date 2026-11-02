import QtQuick
import qs.bar
import qs.config
import qs.kit

// Brightness options in the Shell Manager.
Column {
  spacing: Theme.gapGroup

  KitLabel { text: "BAR" }
  BarTextRow { module: "brightness" }

  KitGrouper {}
}
