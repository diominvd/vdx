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
  readonly property string shown: TimerService.active ? TimerService.kind : TimerService.ended ? "countdown" : tab
  readonly property color tone: Theme.orange

  function presetText(minutes) {
    if (minutes < 60) return minutes + " min";
    const hours = Math.floor(minutes / 60), rest = minutes % 60;
    return hours + " h" + (rest > 0 ? " " + rest + " min" : "");
  }

  implicitWidth: Theme.popupWidth

  // ---- header ----
  KitHeader {
    icon: "clock"
    iconColor: TimerService.active ? root.tone : Theme.foreground0
    title: root.shown === "stopwatch" ? "Stopwatch" : "Timer"
    subtitle: TimerService.ended ? "TIME IS UP" : !TimerService.active ? "READY" : (TimerService.paused ? "PAUSED" : "RUNNING")
      + (TimerService.endsText !== "" ? " · ENDS " + TimerService.endsText : "")
  }

  KitLine {}

  // ---- a countdown that ran out ----
  KitRow {
    visible: TimerService.ended
    label: TimerService.label !== "" ? TimerService.label : "Time is up"
    hint: "Finished"
    Row {
      spacing: Theme.gapMedium
      KitButton { icon: "play"; iconTint: root.tone; text: "Restart"; onClicked: TimerService.restart() }
      KitButton { icon: "x"; iconTint: Theme.red; text: "Stop"; onClicked: TimerService.stop() }
    }
  }

  KitSegments {
    visible: !TimerService.active && !TimerService.ended
    width: parent.width
    model: [{ label: "Timer", value: "countdown" }, { label: "Stopwatch", value: "stopwatch" }]
    current: root.tab
    onPicked: value => root.tab = value
  }

  // ---- a countdown to set ----
  Column {
    visible: !TimerService.active && !TimerService.ended && root.tab === "countdown"
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

  // ---- a countdown running (Bezel, the act distance): the head ring, the number, two actions ----
  Item {
    visible: TimerService.kind === "countdown"
    width: parent.width
    height: Math.max(Theme.ringWide, info.implicitHeight)

    // lit ticks are what is left; its centre is the primary control
    KitRing {
      id: head
      anchors.verticalCenter: parent.verticalCenter
      size: Theme.ringWide
      kind: "ticks"
      value: 1 - TimerService.progress
      tint: TimerService.paused ? Theme.muted : root.tone

      Rectangle {
        anchors.centerIn: parent
        width: Math.round(head.size * 0.42)
        height: width
        radius: width / 2     // inside a ring: a circle in either corner style
        color: centre.containsMouse ? Theme.controlHover : Theme.clear
        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
        KitIcon { anchors.centerIn: parent; name: TimerService.paused ? "play" : "pause"; filled: true; size: 20; tint: Theme.foreground1 }
        MouseArea {
          id: centre
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: TimerService.togglePause()
        }
        Accessible.role: Accessible.Button
        Accessible.name: TimerService.paused ? "Resume" : "Pause"
      }
    }

    Column {
      id: info
      anchors { left: head.right; leftMargin: Theme.gapGroup; right: parent.right; verticalCenter: parent.verticalCenter }
      spacing: Theme.gapHair

      KitText {
        width: parent.width
        text: (TimerService.label !== "" ? TimerService.label : "Timer")
          + (TimerService.paused ? " · paused" : " · of " + Math.round(TimerService.total / 60000) + " min")   // the end is in the header
        color: Theme.muted
        elide: Text.ElideRight
      }
      // a display figure: the same number as the pill's, at its largest
      KitText {
        text: TimerService.text
        color: TimerService.paused ? Theme.muted : root.tone
        font.pixelSize: 38
        font.weight: Font.Bold
        font.features: { "tnum": 1 }
        font.letterSpacing: -1.5
      }
      Row {
        spacing: Theme.gapMedium
        KitButton { text: "+1 min"; onClicked: TimerService.addMinutes(1) }
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
