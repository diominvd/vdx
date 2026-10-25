import QtQuick
import qs.bar
import qs.components
import qs.config
import qs.kit
import qs.modules.notifications

// The island at rest: the modules of LEFT, the clock, the modules of RIGHT
// (Shell Manager › Bar, island style) and a dot for unseen notifications.
// Each side takes the room its modules need — an empty one none — so the
// clock is centred only when both sides match.
Item {
  id: root

  property var modules: ({})                   // Bar's module id -> Component
  property string screen: ""
  signal settings(string id)                   // a module's right click: its options
  signal clockClicked()                        // the clock's click, when the hub opens on a click
  property date now: new Date()

  // Modules › Clock's format
  readonly property string format: (ModuleSettings.get("clock", "date", false) ? "ddd dd · " : "")
    + (ModuleSettings.get("clock", "twelveHour", false) ? "h:mm" : "HH:mm")
    + (ModuleSettings.get("clock", "seconds", false) ? ":ss" : "")
    + (ModuleSettings.get("clock", "twelveHour", false) ? " AP" : "")

  // the dot: unseen notices while the centre sits in the hub (Bar › Style › Notifications dot)
  readonly property bool unseen: NotificationsService.unseen > 0 && ShellSettings.barFolderDot
  readonly property bool clockOn: BarLayout.islandClock(screen)
  // nothing to show at rest: the island hides (Shell Manager › Bar › Clock)
  readonly property bool empty: !clockOn && !unseen && BarLayout.islandIn("start", screen).length === 0
                                && BarLayout.islandIn("end", screen).length === 0
  // the pointer resting on the clock (not on a module) opens the hub
  readonly property bool clockHovered: clockHover.hovered
  implicitWidth: Math.max(110, line.implicitWidth + 2 * Theme.gapGroup)
  implicitHeight: Theme.islandHeight

  // a custom separator on the island's side: its line, no module behind it
  Component { id: separatorFace; Separator {} }

  // a side with nothing in it is zero wide: the Row skips it and its gap
  Row {
    id: line
    anchors.centerIn: parent
    spacing: Theme.gapGroup

  Row {
    id: left
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.gapWide

    Repeater {
      model: BarLayout.islandIn("start", root.screen)
      Loader {
        required property string modelData
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: BarLayout.isSeparator(modelData) ? separatorFace : (root.modules[modelData] ?? null)

        // a right click takes its options; without this it falls through to the island
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.RightButton
          enabled: !BarLayout.isSeparator(modelData)
          onClicked: if (ShellSettings.barRightSettings) root.settings(modelData)
        }
      }
    }
  }

  Item {
    anchors.verticalCenter: parent.verticalCenter
    visible: root.clockOn
    width: clock.implicitWidth
    height: Theme.islandHeight
    property bool keyboardPressed: false
    onActiveFocusChanged: if (!activeFocus) keyboardPressed = false

    KitText {
      id: clock
      anchors.centerIn: parent
      text: Qt.formatDateTime(root.now, root.format)
      font.weight: Font.Bold
      scale: parent.keyboardPressed || clockArea.pressed ? 0.97 : 1
      Behavior on scale { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
    }

    HoverHandler { id: clockHover }

    // When configured for click-to-open, the clock is a real keyboard button too.
    activeFocusOnTab: root.clockOn && ShellSettings.clockOpens === "click"
    Accessible.role: Accessible.Button
    Accessible.name: "Open Island hub"
    Accessible.description: "Open the Island hub"
    Rectangle {
      anchors.fill: parent
      radius: Theme.radiusControl
      color: "transparent"
      border.width: parent.activeFocus ? Theme.focusRingWidth : 0
      border.color: Theme.focusRing
    }
    Keys.onPressed: event => {
      if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
      if (!event.isAutoRepeat && activeFocusOnTab) {
        keyboardPressed = true;
        root.clockClicked();
      }
      event.accepted = true;
    }
    Keys.onReleased: event => {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        keyboardPressed = false;
        event.accepted = true;
      }
    }

    // the hub opens on a click here instead of a hover (Bar › Behaviour › Open the hub)
    MouseArea {
      id: clockArea
      anchors.fill: parent
      enabled: ShellSettings.clockOpens === "click"
      cursorShape: Qt.PointingHandCursor
      onClicked: { parent.forceActiveFocus(); root.clockClicked(); }
    }
  }

  Row {
    id: right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.gapWide

    Repeater {
      model: BarLayout.islandIn("end", root.screen)
      Loader {
        required property string modelData
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: BarLayout.isSeparator(modelData) ? separatorFace : (root.modules[modelData] ?? null)

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.RightButton
          enabled: !BarLayout.isSeparator(modelData)
          onClicked: if (ShellSettings.barRightSettings) root.settings(modelData)
        }
      }
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.unseen
      width: 6
      height: 6
      radius: Theme.pill(height)
      color: Theme.notifyDot(ShellSettings.barDotColor)
    }
  }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }
}
