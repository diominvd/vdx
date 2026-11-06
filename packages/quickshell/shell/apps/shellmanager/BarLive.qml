import QtQuick
import qs.config
import qs.kit

// Bar › Live: the island's live activities — what grows out of the pill, in
// priority order — and the rules that apply to all of them. An activity's own options
// open under its row (LiveOptions).
Column {
  id: root

  function jump(kind) { for (const s of [asks, held, flash]) s.jump(kind); }

  Column {
    width: parent.width

    KitLabel { text: "LIVE ACTIVITIES" }
    KitRow {
      label: "Live activities"
      hint: "Off: the pill stays at rest"
      KitSwitch { checked: ShellSettings.liveEnabled; onToggled: ShellSettings.setLook("liveEnabled", !checked, "island") }
    }
    KitGrouper {}
  }

  KitLine { visible: ShellSettings.liveEnabled }

  BarLiveSection {
    width: parent.width
    visible: ShellSettings.liveEnabled
    id: asks
    section: "asks"
    title: "ASKS"
    info: ({
      notice: { label: "Messages", hint: "Shows a new message as a line" },
      battery: { label: "Low battery", hint: "Shows the charge when it runs low" },
      bluetooth: { label: "Device connected", hint: "Shows a connected Bluetooth device" }
    })
  }

  KitLine { visible: ShellSettings.liveEnabled }

  BarLiveSection {
    width: parent.width
    visible: ShellSettings.liveEnabled
    id: held
    section: "held"
    title: "HELD"
    about: "They stay while the job runs; drag a row to set who takes the pill first"
    info: ({
      recording: { label: "Recording", hint: "Shows a timer while the screen records" },
      update: { label: "Updates", hint: "Shows the progress of an update" },
      backup: { label: "Backup", hint: "Shows the progress of a backup" },
      timer: { label: "Timer", hint: "Shows the time left or the stopwatch" },
      vpn: { label: "VPN", hint: "Shows the server and the ping" },
      focus: { label: "Focus", hint: "Shows that Focus mode is on" },
      radio: { label: "Radio", hint: "Shows the station on air" },
      music: { label: "Music", hint: "Shows the track playing in Music" },
      media: { label: "Media", hint: "Shows the track playing in other apps" }
    })
  }

  KitLine { visible: ShellSettings.liveEnabled }

  BarLiveSection {
    width: parent.width
    visible: ShellSettings.liveEnabled
    id: flash
    section: "flash"
    title: "FLASH"
    info: ({
      volume: { label: "Volume and brightness", hint: "Shows the level while you change it" },
      mic: { label: "Microphone", hint: "Shows when the mic is muted or unmuted" },
      layout: { label: "Keyboard layout", hint: "Shows the layout when it changes" },
      plugged: { label: "Plugged in", hint: "Shows the charge when the cable connects" }
    })
  }

  KitLine { visible: ShellSettings.liveEnabled }

  Column {
    width: parent.width
    visible: ShellSettings.liveEnabled

    KitLabel { text: "BEHAVIOUR" }

    KitRow {
      label: "New one comes forward"
      hint: "A new activity takes the pill, then the wheel pages on"
      KitSwitch { checked: ShellSettings.liveFront; onToggled: ShellSettings.setLook("liveFront", !checked, "island") }
    }
    KitSliderRow {
      label: "Flash lasts"
      snaps: [0, 1/6, 2/6, 3/6, 4/6, 5/6, 1]
      value: (ShellSettings.liveFlashMs - 1000) / 3000
      text: ((pressed ? 1000 + Math.round(dragValue * 6) * 500 : ShellSettings.liveFlashMs) / 1000).toFixed(1) + " s"
      onMoved: value => ShellSettings.setLook("liveFlashMs", 1000 + Math.round(value * 6) * 500, "island")
    }
    KitRow {
      label: "Wheel pages through them"
      hint: "Scrolling picks one on this monitor"
      KitSwitch { checked: ShellSettings.liveWheel; onToggled: ShellSettings.setLook("liveWheel", !checked, "island") }
    }
    KitSliderRow {
      visible: ShellSettings.liveWheel
      label: "Scroll delay"
      snaps: [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1]
      value: ShellSettings.liveWheelDelayMs / 500
      text: ShellSettings.liveWheelDelayMs === 0 ? "Off" : ShellSettings.liveWheelDelayMs + " ms"
      onMoved: value => ShellSettings.setLook("liveWheelDelayMs", Math.round(value * 10) * 50, "island")
    }
    KitRow {
      label: "Right click opens options"
      hint: "On a live activity: its settings here"
      KitSwitch { checked: ShellSettings.liveRightSettings; onToggled: ShellSettings.setLook("liveRightSettings", !checked, "island") }
    }
    KitGrouper {}
  }

  KitGrouper {}
}
