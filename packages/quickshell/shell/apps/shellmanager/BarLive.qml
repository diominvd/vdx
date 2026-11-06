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
      notice: { label: "Messages", hint: "A new message as a line; off: a card" },
      battery: { label: "Low battery", hint: "The charge left, when it runs low" },
      bluetooth: { label: "Device connected", hint: "Headphones and other Bluetooth devices" }
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
      recording: { label: "Recording", hint: "A timer while the screen records" },
      update: { label: "Updates", hint: "Progress of an update run" },
      backup: { label: "Backup", hint: "Progress of a backup" },
      timer: { label: "Timer", hint: "The time left or the stopwatch; click opens" },
      vpn: { label: "VPN", hint: "Which server and the ping" },
      focus: { label: "Focus", hint: "Do not disturb is on" },
      radio: { label: "Radio", hint: "The station on air; a click opens the dial" },
      music: { label: "Music", hint: "The playing track: Yandex Music or files" },
      media: { label: "Media", hint: "Other apps: a browser, Spotify, mpv" }
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
      volume: { label: "Volume and brightness", hint: "A level while you change it" },
      mic: { label: "Microphone", hint: "When the mic is muted or unmuted" },
      layout: { label: "Keyboard layout", hint: "EN → RU when it changes" },
      plugged: { label: "Plugged in", hint: "Charge when the cable connects" }
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
