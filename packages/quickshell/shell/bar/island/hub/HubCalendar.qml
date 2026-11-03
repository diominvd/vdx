import QtQuick
import qs.bar.island
import qs.config
import qs.kit

// The month, a page of the hub: the title with Today and the month arrows, the
// weekday heads and six weeks of days, today picked. A back button leaves it.
Item {
  id: root

  property date now: new Date()
  signal back()
  property bool embedded: false              // in the hub itself, not a page of it: no way back

  // the first day of the month shown
  property date month: new Date(now.getFullYear(), now.getMonth(), 1)
  function shift(by) { month = new Date(month.getFullYear(), month.getMonth() + by, 1); }
  function today() { month = new Date(now.getFullYear(), now.getMonth(), 1); }

  // the Monday the grid starts on
  readonly property date start: {
    const d = new Date(month.getFullYear(), month.getMonth(), 1);
    d.setDate(1 - (d.getDay() + 6) % 7);
    return d;
  }
  // as many weeks as the month needs (five or six)
  readonly property int weeks: Math.ceil(((month.getDay() + 6) % 7 + new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()) / 7)
  readonly property int cell: Math.floor((width - 6 * grid.spacing) / 7)

  implicitHeight: column.implicitHeight

  Column {
    id: column
    width: parent.width
    spacing: Theme.gapLoose

    // ---- head ----
    Item {
      width: parent.width
      height: 36

      Row {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        spacing: Theme.gapMedium
        IslandButton { visible: !root.embedded; anchors.verticalCenter: parent.verticalCenter; icon: "arrow-left"; iconSize: 16; onClicked: root.back() }
        KitText { anchors.verticalCenter: parent.verticalCenter; text: Qt.formatDate(root.month, "MMMM"); font.weight: Font.Bold; font.pixelSize: Theme.fontSize + 3 }
        KitText { anchors.verticalCenter: parent.verticalCenter; text: Qt.formatDate(root.month, "yyyy"); color: Theme.muted; font.pixelSize: Theme.fontSize + 3 }
      }

      Row {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: Theme.gapSmall

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: todayLabel.implicitWidth + 2 * Theme.gapWide
          height: Theme.controlHeight
          radius: Theme.pill(height)
          color: todayArea.containsMouse ? Theme.controlHover : Theme.material ? Theme.controlFill : Theme.clear
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.normal; easing.type: Motion.easing } }
          border.width: Theme.frameWidth
          border.color: Theme.controlLine
          KitText { id: todayLabel; anchors.centerIn: parent; text: "Today"; font.pixelSize: Theme.fontSize - 1 }
          MouseArea { id: todayArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.today() }
        }
        IslandButton { anchors.verticalCenter: parent.verticalCenter; icon: "chevron-right"; iconSize: 14; rotation: 180; onClicked: root.shift(-1) }
        IslandButton { anchors.verticalCenter: parent.verticalCenter; icon: "chevron-right"; iconSize: 14; onClicked: root.shift(1) }
      }
    }

    // ---- the grid ----
    Rectangle {
      width: parent.width
      height: grid.implicitHeight + 2 * Theme.gapMedium + heads.height + Theme.gapSmall
      radius: Theme.radiusCard
      color: Theme.material ? Theme.sectionFill : Theme.controlFill
      border.width: Theme.frameWidth
      border.color: Theme.controlLine

      Row {
        id: heads
        anchors { top: parent.top; topMargin: Theme.gapMedium; horizontalCenter: parent.horizontalCenter }
        spacing: grid.spacing
        Repeater {
          model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
          Item {
            required property string modelData
            width: root.cell
            height: 22
            KitText { anchors.centerIn: parent; text: modelData; color: Theme.muted; font.pixelSize: Theme.fontSize - 3; font.letterSpacing: 0.5 }
          }
        }
      }

      Grid {
        id: grid
        anchors { top: heads.bottom; topMargin: Theme.gapSmall; horizontalCenter: parent.horizontalCenter }
        columns: 7
        spacing: Theme.gapSmall

        Repeater {
          model: root.weeks * 7

          Rectangle {
            required property int index
            readonly property date day: new Date(root.start.getFullYear(), root.start.getMonth(), root.start.getDate() + index)
            readonly property bool inMonth: day.getMonth() === root.month.getMonth()
            readonly property bool isToday: day.getFullYear() === root.now.getFullYear() && day.getMonth() === root.now.getMonth() && day.getDate() === root.now.getDate()
            width: root.cell
            height: root.cell * 0.8
            // Material: today a filled circle
            radius: Theme.material ? Theme.radiusFor(height) : Theme.radiusControl
            color: isToday ? (Theme.material ? Theme.primary : Theme.pickFill) : Theme.clear
            border.width: isToday ? Theme.frameWidth : 0
            border.color: Theme.foreground2

            KitText {
              anchors.centerIn: parent
              text: day.getDate()
              color: isToday && Theme.material ? Theme.inkOn(Theme.primary) : inMonth ? Theme.foreground0 : Theme.dim
              font.weight: isToday ? Theme.pickWeight : Theme.fontWeight
            }
          }
        }
      }
    }
  }
}
