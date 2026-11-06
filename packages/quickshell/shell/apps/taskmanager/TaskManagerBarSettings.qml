import QtQuick
import qs.bar
import qs.kit
import qs.config

// The task manager's bar module options (Shell apps › BAR, under the
// module's place): how much its popup lists.
Column {
  spacing: Theme.sectionGap

  KitLabel { text: "BAR" }
  BarTextRow { module: "taskmanager"; hasContent: false }

  KitLine {}

  KitLabel { text: "POPUP" }

  KitOptionRow {
    module: "taskmanager"; key: "popupRows"; fallback: 5
    label: "Programs shown"; hint: "The rest in the window"
    model: [{ label: "3", value: 3 }, { label: "5", value: 5 }, { label: "10", value: 10 }]
  }

  KitToggleRow { module: "taskmanager"; key: "closeOnOpen"; label: "Close when its window opens"; hint: "Off: popup stays open" }

  KitGrouper {}
}
