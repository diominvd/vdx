import QtQuick
import qs.config
import qs.kit

// HH:mm; click switches to the full date.
Item {
  id: root

  property bool full: false
  ClockTime { id: time; forceSeconds: root.full }

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  KitText {
    id: label
    text: Qt.formatDateTime(time.now, root.full ? "dddd, dd MMMM yyyy HH:mm:ss" : time.format)
    color: Theme.muted
  }


  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.full = !root.full
  }
}
