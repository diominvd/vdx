import QtQuick
import qs.bar
import qs.config
import qs.kit

// Radio options in the Shell Manager: the bar face's text and the popup's stop button.
Column {
  spacing: Theme.gapGroup

  KitLabel { text: "BAR" }
  BarTextRow { module: "tuner" }

  KitLine {}

  KitLabel { text: "POPUP" }

  KitToggleRow {
    module: "tuner"; key: "showList"; fallback: true
    label: "Show the stations"; hint: "Off: the dial only"
  }

  KitToggleRow {
    module: "tuner"; key: "closeAfterStop"; fallback: false
    label: "Close after stop"; hint: "Closes the popup when you stop"
  }

  KitGrouper {}
}
