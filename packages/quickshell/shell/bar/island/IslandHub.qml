import QtQuick
import Quickshell
import qs.bar
import qs.config
import qs.kit
import qs.modules.equalizer

// The island opened up: the date, the settings and power buttons, the track (prev, play,
// next), then the Launcher and Keys chips and the hub's modules (Shell Manager › Bar) as chips.
// A chip is the module's own face: its click opens the module's popup in the
// island, a right click its options.
Item {
  id: root

  required property PanelWindow bar
  property var modules: ({})

  signal power()
  signal manager()                          // the gear: Shell Manager
  signal app(string view)                   // the Launcher / Keys chip: "launcher" or "keybinds"
  signal settings(string id)

  // Shell Manager › Bar › HUB (island style)
  readonly property var ids: BarLayout.islandIn("hub", bar.screen?.name ?? "")

  property date now: new Date()

  implicitHeight: column.implicitHeight + 2 * Theme.gapGroup

  Timer {
    interval: 30000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  Column {
    id: column
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.gapGroup }
    spacing: Theme.gapWide

    // ---- header ----
    Item {
      width: parent.width
      height: powerButton.height

      KitText {
        anchors { left: parent.left; leftMargin: Theme.gapHair; verticalCenter: parent.verticalCenter }
        text: Qt.formatDateTime(root.now, "dddd, d MMMM")
        font.weight: Font.Bold
      }

      IslandButton {
        anchors { right: powerButton.left; rightMargin: Theme.gapSmall }
        icon: "settings"
        iconSize: 16
        onClicked: root.manager()
      }

      IslandButton {
        id: powerButton
        anchors.right: parent.right
        icon: "power"
        iconSize: 16
        onClicked: root.power()
      }
    }

    // ---- track ----
    Rectangle {
      width: parent.width
      height: 52
      visible: IslandService.hasMedia && ShellSettings.hubPlayer
      radius: Theme.radiusCard
      color: Theme.background1

      IslandCover {
        id: cover
        anchors { left: parent.left; leftMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
        size: 36
        radius: Theme.radiusControl
      }

      Column {
        anchors { left: cover.right; leftMargin: Theme.gapLoose; right: controls.left; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }

        KitText {
          width: parent.width
          text: IslandService.title || "Nothing playing"
          textFormat: Text.PlainText
          font.weight: Font.Bold
          elide: Text.ElideRight
        }
        KitText {
          width: parent.width
          visible: text !== ""
          text: IslandService.artist
          textFormat: Text.PlainText
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 1
          elide: Text.ElideRight
        }
      }

      // one hover disc for the group: it slides to the button under the
      // pointer, so two discs never show at once
      // it jumps to the button it moves to and fades in or out on the group
      // leaving: the last button stays put while it fades
      Rectangle {
        id: disc
        readonly property Item target: controls.hoverTarget
        property Item last: null
        onTargetChanged: if (target) last = target
        x: last ? controls.x + last.x : 0
        y: last ? controls.y + last.y : 0
        width: last ? last.width : 0
        height: last ? last.height : 0
        radius: Theme.pill(height)
        color: Theme.background2
        opacity: target ? 1 : 0

        Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
      }

      Row {
        id: controls
        anchors { right: parent.right; rightMargin: Theme.gapHair; verticalCenter: parent.verticalCenter }
        property Item hoverTarget: null

        EqualizerBars {
          anchors.verticalCenter: parent.verticalCenter
          height: 14
          rightPadding: Theme.gapMedium
        }
        IslandButton { group: controls; icon: "skip-back"; iconSize: 16; onClicked: IslandService.prev() }
        IslandButton { group: controls; icon: IslandService.playing ? "pause" : "play"; iconSize: 18; onClicked: IslandService.togglePlay() }
        IslandButton { group: controls; icon: "skip-forward"; iconSize: 16; onClicked: IslandService.next() }
      }
    }

    // ---- modules ----
    Flow {
      width: parent.width
      spacing: Theme.gapSmall

      // the launcher and the keybinds, opened inside the island
      Repeater {
        model: [{ view: "launcher", icon: "search", label: "Launcher" },
                { view: "keybinds", icon: "keyboard", label: "Keys" }]

        Rectangle {
          id: appChip
          required property var modelData

          width: appRow.width + 2 * Theme.gapWide
          height: 32
          radius: Theme.radiusCard
          property bool keyboardPressed: false
          color: keyboardPressed || appTap.pressed ? Theme.background3 : appHover.hovered ? Theme.background2 : Theme.background1
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

          // Launcher and keybind chips are custom buttons; expose the same
          // action to keyboard and assistive-technology users as to the pointer.
          Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: appChip.activeFocus ? Theme.focusRingWidth : 0
            border.color: Theme.focusRing
          }

          activeFocusOnTab: true
          Accessible.role: Accessible.Button
          Accessible.name: appChip.modelData.label
          Accessible.description: appChip.modelData.view === "launcher" ? "Open application launcher" : "Open keyboard shortcuts"
          HoverHandler { id: appHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { id: appTap; onTapped: { appChip.forceActiveFocus(); root.app(appChip.modelData.view); } }
          onActiveFocusChanged: if (!activeFocus) keyboardPressed = false
          Keys.onPressed: event => {
            if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
            if (!event.isAutoRepeat) {
              keyboardPressed = true;
              root.app(appChip.modelData.view);
            }
            event.accepted = true;
          }
          Keys.onReleased: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
              keyboardPressed = false;
              event.accepted = true;
            }
          }

          Row {
            id: appRow
            anchors.centerIn: parent
            spacing: Theme.gapSmall

            KitIcon { anchors.verticalCenter: parent.verticalCenter; name: appChip.modelData.icon; size: 16 }
            KitText { anchors.verticalCenter: parent.verticalCenter; text: appChip.modelData.label }
          }
        }
      }

      Repeater {
        model: root.ids

        Rectangle {
          id: chip
          required property string modelData

          width: slot.width + 2 * Theme.gapWide
          height: 32
          radius: Theme.radiusCard
          color: hover.hovered ? Theme.background2 : Theme.background1
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

          HoverHandler { id: hover }

          Loader {
            id: slot
            anchors.centerIn: parent
            sourceComponent: root.modules[chip.modelData] ?? null
          }

          TapHandler {
            acceptedButtons: Qt.RightButton
            enabled: ShellSettings.barRightSettings
            onTapped: root.settings(chip.modelData)
          }
        }
      }
    }
  }
}
