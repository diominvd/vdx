import QtQuick
import qs.config
import qs.kit

// Timer: a countdown set with a slider, or a stopwatch with laps; the rows of
// every other popup. While one runs, its time is the first row.
KitFrame {
  id: root

  // the tab follows a running one; idle, it is the owner's pick
  property string tab: "countdown"
  property int minutes: TimerService.lastMinutes
  readonly property string shown: TimerService.active ? TimerService.kind : tab
  readonly property color tone: Theme.accentFor("modules", Theme.orange)

  function presetText(minutes) {
    if (minutes < 60) return minutes + " min";
    const hours = Math.floor(minutes / 60), rest = minutes % 60;
    return hours + " h" + (rest > 0 ? " " + rest + " min" : "");
  }

  implicitWidth: 320

  // ---- header ----
  KitHeader {
    icon: "clock"
    iconColor: TimerService.active ? root.tone : Theme.foreground0
    title: root.shown === "stopwatch" ? "Stopwatch" : "Timer"
    subtitle: !TimerService.active ? "READY" : (TimerService.paused ? "PAUSED" : "RUNNING")
      + (TimerService.endsText !== "" ? " · ENDS " + TimerService.endsText : "")
  }

  KitLine {}

  KitSegments {
    visible: !TimerService.active
    width: parent.width
    model: [{ label: "Timer", value: "countdown" }, { label: "Stopwatch", value: "stopwatch" }]
    current: root.tab
    onPicked: value => root.tab = value
  }

  // ---- a countdown to set ----
  Column {
    visible: !TimerService.active && root.tab === "countdown"
    width: parent.width
    spacing: Theme.gapGroup

    TimerRuler {
      width: parent.width
      value: root.minutes
      to: TimerService.maxMinutes
      tint: root.tone
      onMoved: value => root.minutes = value
    }
    Row {
      width: parent.width
      KitButton {
        id: startButton
        text: "Start"
        icon: "play"
        iconTint: root.tone
        onClicked: TimerService.startCountdown(root.minutes)
      }
      Item { width: parent.width - startButton.width - bigTime.width; height: 1 }
      KitText {
        id: bigTime
        anchors.verticalCenter: parent.verticalCenter
        text: TimerService.fmt(root.minutes * 60000, false)
        color: root.tone
        font.pixelSize: Theme.fontSize + 12
      }
    }
    Flow {
      visible: TimerService.presets.length > 0
      width: parent.width
      spacing: Theme.gapSmall
      Repeater {
        model: TimerService.presets
        KitButton {
          required property int modelData
          text: root.presetText(modelData)
          selected: root.minutes === modelData
          onClicked: root.minutes = modelData
        }
      }
    }
  }

  // ---- a countdown running ----
  Column {
    visible: TimerService.kind === "countdown"
    width: parent.width
    spacing: Theme.gapGroup

    KitLabel {
      text: "REMAINING"
      value: TimerService.text
      valueColor: TimerService.paused ? Theme.muted : root.tone
    }
    KitRow {
      label: TimerService.label !== "" ? TimerService.label : "Timer"
      hint: TimerService.paused ? "Paused" : "of " + Math.round(TimerService.total / 60000) + " min"
      Row {
        spacing: Theme.gapMedium
        KitButton { icon: TimerService.paused ? "play" : "pause"; text: TimerService.paused ? "Resume" : "Pause"; onClicked: TimerService.togglePause() }
        KitButton { icon: "x"; iconTint: Theme.red; text: "Stop"; onClicked: TimerService.stop() }
      }
    }
  }

  // ---- a stopwatch ----
  Column {
    visible: root.shown === "stopwatch"
    width: parent.width
    spacing: Theme.gapGroup

    KitLabel {
      text: "ELAPSED"
      value: TimerService.kind === "stopwatch" ? TimerService.text : TimerService.fmt(0, true)
      valueColor: TimerService.active ? root.tone : Theme.muted
    }
    KitRow {
      label: "Stopwatch"
      hint: !TimerService.active ? "Not running" : TimerService.paused ? "Paused" : "Running"
      Row {
        spacing: Theme.gapMedium
        KitButton {
          icon: TimerService.running ? "pause" : "play"
          iconTint: TimerService.running ? Theme.foreground0 : root.tone
          text: !TimerService.active ? "Start" : TimerService.paused ? "Resume" : "Pause"
          onClicked: TimerService.active ? TimerService.togglePause() : TimerService.startStopwatch()
        }
        KitButton { visible: TimerService.running; text: "Lap"; onClicked: TimerService.lap() }
        KitButton { visible: TimerService.paused; icon: "x"; iconTint: Theme.red; text: "Reset"; onClicked: TimerService.stop() }
      }
    }
  }

  KitLine { visible: root.shown === "stopwatch" && TimerService.laps.length > 0 }

  Flickable {
    visible: root.shown === "stopwatch" && TimerService.laps.length > 0
    width: parent.width
    height: Math.min(contentHeight, 5 * Theme.rowHeight)
    contentHeight: laps.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Column {
      id: laps
      width: parent.width
      Repeater {
        model: TimerService.laps
        KitRow {
          required property real modelData
          required property int index
          label: "Lap " + (TimerService.laps.length - index)
          KitText { text: TimerService.fmt(modelData, true); color: index === 0 ? Theme.foreground0 : Theme.foreground2 }
        }
      }
    }
  }
}
