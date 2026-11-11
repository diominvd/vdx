import QtQuick
import qs.apps.auth
import qs.apps.backup
import qs.apps.capture
import qs.apps.packages
import qs.config
import qs.kit

Row {
  id: face

  property string kind: ""
  property bool inputEnabled: true
  property int coverSize: 18
  property int badgeRadius: 4
  height: Math.max(coverSize, Theme.fontSize)
  spacing: Theme.gapMedium
  visible: kind !== ""

  // recording: the dot, the time, the sound, pause and stop
  Rectangle {
    visible: face.kind === "recording" && CaptureService.recording
    anchors.verticalCenter: parent.verticalCenter
    width: 8
    height: 8
    radius: Theme.pill(height)
    color: Theme.red
    opacity: CaptureService.paused ? 0.4 : 1

  }
  KitText {
    visible: face.kind === "recording" && CaptureService.recording
    anchors.verticalCenter: parent.verticalCenter
    text: CaptureService.elapsedText
    color: Theme.foreground1
    font.weight: Font.Medium
  }
  LiveBars {
    visible: face.kind === "recording" && CaptureService.recording
    anchors.verticalCenter: parent.verticalCenter
    barCount: 7
    tone: Theme.red
    height: 16
    active: !CaptureService.paused
  }
  // buttons, the chip's height less its inset and concentric with it: pause (dim) and stop (red)
  Repeater {
    model: face.kind === "recording" && CaptureService.recording && ShellSettings.liveRecordingButtons ? [{ stop: false }, { stop: true }] : []
    Rectangle {
      id: btn
      required property var modelData
      readonly property bool stop: modelData.stop
      anchors.verticalCenter: parent.verticalCenter
      width: face.coverSize
      height: face.coverSize
      radius: face.badgeRadius
      readonly property string liveEnd: "badge"    // IslandLiveFace.padFor
      color: stop ? Theme.red : Theme.background3
      opacity: area.containsMouse ? 0.85 : 1
      Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
      Accessible.role: Accessible.Button
      Accessible.name: stop ? "Stop recording" : CaptureService.paused ? "Resume recording" : "Pause recording"

      KitIcon {
        anchors.centerIn: parent
        name: btn.stop ? "square" : CaptureService.paused ? "play" : "pause"
        size: 12
        filled: true
        tint: btn.stop ? Theme.background0 : Theme.foreground1
      }
      MouseArea {
        id: area
        anchors.fill: parent
        enabled: face.inputEnabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.stop ? CaptureService.stopRecording() : CaptureService.togglePause()
      }
    }
  }
  KitIcon {
    visible: face.kind === "recording" && !CaptureService.recording && CaptureService.recordOutcome !== ""
    name: CaptureService.recordOutcome === "error" ? "info" : "check"
    size: 16
    tint: CaptureService.recordOutcome === "error" ? Theme.red : Theme.green
    anchors.verticalCenter: parent.verticalCenter
  }
  KitText {
    visible: face.kind === "recording" && !CaptureService.recording && CaptureService.recordOutcome !== ""
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, 180)
    elide: Text.ElideRight
    text: CaptureService.recordOutcome === "error" ? "Recording failed" : CaptureService.recordOutcomeText
    color: CaptureService.recordOutcome === "error" ? Theme.red : Theme.green
  }

  // update: the download's progress, else what runs
  LiveGlyph { corner: face.badgeRadius; visible: face.kind === "update"; size: face.coverSize; name: "download"; tint: Theme.blue }
  readonly property bool updateDone: face.kind === "update" && !PackagesService.busy && !RootService.running && PackagesService.status !== ""
  readonly property bool updateBar: face.kind === "update" && PackagesService.stage === "downloading"
  IslandLiveProgress {
    visible: face.updateBar
    anchors.verticalCenter: parent.verticalCenter
    value: PackagesService.stagePercent
    tint: Theme.blue
  }
  KitText { visible: face.updateBar; anchors.verticalCenter: parent.verticalCenter; text: Math.round(PackagesService.stagePercent * 100) + "%"; color: Theme.blue }
  KitText {
    visible: face.kind === "update" && !face.updateBar
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, 180)
    elide: Text.ElideRight
    text: face.updateDone ? (PackagesService.status === "error" ? "Update failed" : "Updates installed")
      : PackagesService.stage === "installing" ? "Installing packages" : PackagesService.busy ? "Updating packages" : RootService.title
    color: face.updateDone ? (PackagesService.status === "error" ? Theme.red : Theme.green) : Theme.blue
  }

  // backup: BKP and its progress
  LiveGlyph { corner: face.badgeRadius; visible: face.kind === "backup"; size: face.coverSize; name: "history"; tint: Theme.green }
  IslandLiveProgress {
    visible: face.kind === "backup" && BackupService.status === ""
    anchors.verticalCenter: parent.verticalCenter
    value: BackupService.progress / 100
    tint: Theme.green
  }

  KitText {
    visible: face.kind === "backup"
    anchors.verticalCenter: parent.verticalCenter
    text: BackupService.status === "error" ? "Failed" : BackupService.status === "ok" ? "Done" : Math.max(0, Math.round(BackupService.progress)) + "%"
    color: BackupService.status === "error" ? Theme.red : BackupService.status === "ok" ? Theme.green : Theme.foreground2
  }
}
