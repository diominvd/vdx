import QtQuick
import qs.kit
import qs.config

// A KitRow with its checkbox on the left, so the boxes line up down a list.
// The row's controls (children) go on the right, as in any KitRow.
Row {
  id: root

  property alias label: row.label
  property alias hint: row.hint
  property alias labelColor: row.labelColor
  property bool checked: false
  default property alias trailing: row.trailing
  signal toggled()

  width: parent ? parent.width : 0
  spacing: Theme.gapWide

  PackageCheck {
    anchors.verticalCenter: parent.verticalCenter
    accessibleName: root.label
    checked: root.checked
    onToggled: root.toggled()
  }

  KitRow {
    id: row
    width: Math.max(0, root.width - root.spacing - 16)
  }
}
