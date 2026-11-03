import QtQuick
import qs.config
import qs.kit

// One entry of EntryBrowser's index: its icon on a plate, its name and, under it, its
// state behind a dot (green: good news, e.g. on the bar). An entry that is off (not
// installed) is muted. The whole card is the button: click, Enter or Space.
Rectangle {
  id: root

  required property var entry
  signal clicked()

  readonly property bool hovered: area.containsMouse
  readonly property bool off: !!entry.off

  height: Theme.rowHeight + 2 * Theme.gapMedium
  radius: Theme.radiusCard
  color: hovered ? Theme.controlHover : Theme.groupFill
  Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
  border.width: activeFocus ? Theme.focusWidth : Theme.material ? 0 : Theme.hairline
  border.color: activeFocus ? Theme.focusRing : hovered ? Theme.controlLineHover : Theme.controlLine

  activeFocusOnTab: true
  Keys.onPressed: event => {
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      root.clicked();
      event.accepted = true;
    }
  }
  Accessible.role: Accessible.Button
  Accessible.name: entry.label + (entry.state ? ", " + entry.state : "")

  KitIconPlate {
    id: plate
    anchors { left: parent.left; leftMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
    name: root.entry.icon ?? ""
    tint: root.off ? Theme.muted : Theme.foreground0
  }

  Column {
    anchors { left: plate.right; leftMargin: Theme.gapLoose; right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
    spacing: Theme.gapTight

    KitText {
      width: parent.width
      text: root.entry.label
      elide: Text.ElideRight
      color: root.off ? Theme.muted : Theme.foreground0
      font.weight: Font.Medium
    }

    Row {
      width: parent.width
      spacing: Theme.gapSmall
      visible: !!root.entry.state

      Rectangle {
        id: dot
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.gapSmall
        height: width
        radius: Theme.pill(height)
        color: root.entry.ok ? Theme.green : Theme.gray
      }

      KitText {
        width: parent.width - dot.width - parent.spacing
        text: root.entry.state ?? ""
        elide: Text.ElideRight
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 1
      }
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
