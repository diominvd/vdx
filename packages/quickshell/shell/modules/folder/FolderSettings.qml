import QtQuick
import qs.bar
import qs.config
import qs.kit

// Folder options in the Shell Manager: the bar face's text.
Column {
  spacing: Theme.sectionGap

  KitLabel { text: "BAR" }
  BarTextRow { module: "folder" }

  KitOptionRow {
    module: "folder"; key: "icon"; fallback: "folder"
    label: "Symbol"; hint: ""
    model: [{ label: "Folder", value: "folder" }, { label: "Dots", value: "dots" }]
  }

  KitLine {}

  KitLinkRow {
    label: "Unseen dot"
    hint: "In Notifications › Unseen"
    target: "notifications"
  }

  KitGrouper {}
}
