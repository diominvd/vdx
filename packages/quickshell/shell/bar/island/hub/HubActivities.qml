import QtQuick
import qs.apps.auth
import qs.apps.backup
import qs.apps.capture
import qs.apps.packages
import qs.bar
import qs.bar.island
import qs.config
import qs.kit
import qs.modules.focus
import qs.modules.mihomo
import qs.modules.timer

// What runs in the background, as cards under the clock: the held live activities (Bar › Live:
// recording, update, backup, timer, VPN, Focus), in their order and on their switches. The
// players are the player card's. One card is wide and keeps its
// buttons; two or more share a row, each a ring, a label and one number; what does not fit
// the `max` goes to one "+N more" line. A click opens the module the island would open.
// Options (Bar › Hub › Blocks › Activities): Most cards, Buttons. The hub builds it only while
// one of these runs (IslandHub.wants), so an idle hub takes no room.
Column {
  id: root

  // the held activities except the players (the player card is theirs); the asks and the flashes
  // (a message, the battery, a mic flash, a plugged cable) stay with the island
  readonly property var kinds: ShellSettings.liveSections.held.filter(k => k !== "radio" && k !== "music" && k !== "media")
  readonly property var running: IslandService.activities.filter(k => kinds.includes(k))
  readonly property int most: ModuleSettings.get("hub", "activitiesMost", 2)
  readonly property bool buttons: ShellSettings.liveRecordingButtons     // Bar › Live › Recording: the island's and the hub's
  readonly property var shown: running.slice(0, most)
  readonly property var rest: running.slice(most)
  readonly property int columns: shown.length > 1 ? 2 : 1

  function label(kind) { return ({ recording: "Recording", update: "Packages", backup: "Backup", timer: "Timer", vpn: "VPN", focus: "Focus" })[kind]; }

  // what a card shows: the label, the number, its unit, how full the ring is (-1: no ring) and the tint
  function spec(kind) {
    switch (kind) {
    case "recording":
      return { label: CaptureService.recording ? "Recording" : CaptureService.recordOutcome === "error" ? "Recording failed" : "Recording saved",
               value: CaptureService.recording ? CaptureService.elapsedText : "", unit: "", fraction: -1,
               tint: Theme.red, dim: CaptureService.paused };
    case "update": {
      const done = !PackagesService.busy && !RootService.running && PackagesService.status !== "";
      const down = PackagesService.stage === "downloading";
      return { label: done ? (PackagesService.status === "error" ? "Update failed" : "Updates installed")
                    : PackagesService.stage === "installing" ? "Installing packages" : "Updating packages",
               value: down ? String(Math.round(PackagesService.stagePercent * 100)) : "", unit: down ? "%" : "",
               fraction: down ? PackagesService.stagePercent : -1, tint: PackagesService.status === "error" ? Theme.red : Theme.blue };
    }
    case "backup": {
      const state = BackupService.status;
      return { label: state === "error" ? "Backup failed" : state === "ok" ? "Backup done" : "Backup",
               value: state === "" ? String(Math.max(0, Math.round(BackupService.progress))) : "", unit: state === "" ? "%" : "",
               fraction: state === "" ? BackupService.progress / 100 : -1, tint: state === "error" ? Theme.red : Theme.green };
    }
    case "vpn":
      return { label: MihomoService.current !== "" ? MihomoService.current : "VPN", value: MihomoService.currentDelay > 0 ? String(MihomoService.currentDelay) : "On",
               unit: MihomoService.currentDelay > 0 ? "ms" : "", fraction: -1, tint: Theme.green };
    case "focus":
      return { label: "Do not disturb", value: "On", unit: "", fraction: -1, tint: Theme.purple };
    case "timer":
      return { label: TimerService.label !== "" ? TimerService.label : TimerService.title + (TimerService.paused ? " · paused" : ""),
               value: TimerService.text, unit: "", fraction: TimerService.kind === "countdown" ? 1 - TimerService.progress : -1,
               tint: Theme.orange, dim: TimerService.paused };
    }
    return { label: kind, value: "", unit: "", fraction: -1, tint: Theme.gray };
  }
  function icon(kind) { return ({ recording: "camera", update: "download", backup: "history", timer: "clock", vpn: "vpn", focus: "moon" })[kind]; }
  function open(kind) { BarLayout.openModule(IslandService.liveTarget[kind]); }

  width: parent ? parent.width : 0
  spacing: Theme.gapSmall

  Grid {
    width: parent.width
    columns: root.columns
    spacing: Theme.gapSmall

    Repeater {
      model: root.shown

      Rectangle {
        id: card
        required property string modelData
        readonly property var info: root.spec(modelData)
        readonly property bool wide: root.columns === 1
        // buttons only on a wide card: the recording's (pause, stop; Bar › Live › Recording) and the timer's (pause)
        readonly property bool hasButtons: wide && (modelData === "timer" || modelData === "recording" && root.buttons && CaptureService.recording)

        width: (parent.width - (root.columns - 1) * parent.spacing) / root.columns
        height: wide ? 60 : 52
        radius: Theme.radiusCard
        color: Theme.material ? Theme.sectionFill : Theme.controlFill
        border.width: Theme.frameWidth
        border.color: area.containsMouse ? Theme.controlLineHover : Theme.controlLine

        // a click on the card (not on its buttons) opens the module
        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.open(card.modelData)
        }

        TimerRing {
          id: ring
          anchors { left: parent.left; leftMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
          width: 34; height: 34
          thickness: 3
          tint: card.info.tint
          track: Theme.background3
          // TimerRing empties as it grows: a fill of f is a progress of 1 - f
          progress: card.info.fraction < 0 ? 0 : 1 - card.info.fraction
          opacity: card.info.dim ? 0.5 : 1

          KitIcon { anchors.centerIn: parent; name: root.icon(card.modelData); size: 14; tint: card.info.tint }
        }

        Column {
          anchors {
            left: ring.right; leftMargin: Theme.gapWide
            right: buttonRow.visible ? buttonRow.left : parent.right
            rightMargin: Theme.gapMedium
            verticalCenter: parent.verticalCenter
          }
          spacing: 0

          KitText {
            width: parent.width
            text: card.info.label
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 2
          }
          Row {
            spacing: Theme.gapTight
            visible: card.info.value !== ""
            KitText { text: card.info.value; font.weight: Font.ExtraBold; font.pixelSize: Theme.fontSize + 3 }
            KitText { visible: card.info.unit !== ""; anchors.bottom: parent.bottom; text: card.info.unit; color: Theme.muted; font.pixelSize: Theme.fontSize - 2 }
          }
        }

        Row {
          id: buttonRow
          anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
          spacing: Theme.gapSmall
          visible: card.hasButtons

          KitButton {
            icon: card.modelData === "recording" ? (CaptureService.paused ? "play" : "pause") : (TimerService.paused ? "play" : "pause")
            onClicked: card.modelData === "recording" ? CaptureService.togglePause() : TimerService.togglePause()
          }
          KitButton {
            visible: card.modelData === "recording"
            icon: "square"
            iconTint: Theme.red
            onClicked: CaptureService.stopRecording()
          }
        }
      }
    }
  }

  // what did not fit: one line, a click opens the first of them
  Rectangle {
    visible: root.rest.length > 0
    width: parent.width
    height: 30
    radius: Theme.radiusCard
    color: Theme.material ? Theme.sectionFill : Theme.controlFill
    border.width: Theme.frameWidth
    border.color: restArea.containsMouse ? Theme.controlLineHover : Theme.controlLine

    KitText {
      anchors { left: parent.left; leftMargin: Theme.gapLoose; right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
      text: "+" + root.rest.length + " more · " + root.rest.map(k => root.label(k)).join(", ")
      color: Theme.muted
      elide: Text.ElideRight
      font.pixelSize: Theme.fontSize - 1
    }
    MouseArea {
      id: restArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.open(root.rest[0])
    }
  }
}
