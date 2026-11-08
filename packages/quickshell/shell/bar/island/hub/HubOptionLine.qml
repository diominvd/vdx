import QtQuick
import qs.config
import qs.kit

Item {
  property string title: ""
  property string hint: ""
  default property alias controls: trailing.data
  width: parent.width
  implicitHeight: Math.max(Theme.rowHeight, labels.implicitHeight, trailing.height)
  Column {
    id: labels
    anchors { left: parent.left; right: trailing.left; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
    spacing: Theme.gapTight
    KitText { width: parent.width; text: title; elide: Text.ElideRight }
    KitText { width: parent.width; visible: hint !== ""; text: hint; color: Theme.muted; font.pixelSize: Theme.fontSize - 3; elide: Text.ElideRight }
  }
  Item { id: trailing; anchors { right: parent.right; verticalCenter: parent.verticalCenter } width: childrenRect.width; height: childrenRect.height }
}
