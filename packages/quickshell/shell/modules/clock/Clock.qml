import QtQuick
import qs.config
import qs.kit

// HH:mm; click switches to the full date.
Item {
  id: root

  property bool full: false
  property date now: new Date()

  // the bar's format, from the Shell Manager's Modules › Clock
  readonly property string format: (ModuleSettings.get("clock", "date", false) ? "ddd dd · " : "")
    + (ModuleSettings.get("clock", "twelveHour", false) ? "h:mm" : "HH:mm")
    + (ModuleSettings.get("clock", "seconds", false) ? ":ss" : "")
    + (ModuleSettings.get("clock", "twelveHour", false) ? " AP" : "")

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: label.text
  Accessible.description: "Toggle between the configured clock format and the full date"

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusControl
    color: "transparent"
    border.width: root.activeFocus ? Theme.focusRingWidth : 0
    border.color: Theme.focusRing
  }

  Keys.onPressed: event => {
    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
    if (!event.isAutoRepeat) { root.full = !root.full; }
    event.accepted = true;
  }

  KitText {
    id: label
    text: Qt.formatDateTime(root.now, root.full ? "dddd, dd MMMM yyyy HH:mm:ss" : root.format)
    color: Theme.muted
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); root.full = !root.full; }
  }
}
