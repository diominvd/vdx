import QtQuick
import qs.config
import qs.kit
import qs.modules.battery
import qs.modules.bluetooth
import qs.modules.mihomo
import qs.modules.equalizer
import qs.modules.focus
import qs.modules.mpd
import qs.modules.radio
import qs.modules.timer

// Strict: a bare glyph and text. Material 3 (Theme.material): the glyph in a tonal circle, the key
// value in a tonal capsule (LiveCap), a rounded track for a level; the activities share those slots.
Row {
  id: face

  property string kind: ""
  property int coverSize: 18
  property int badgeRadius: 4
  spacing: kind === "volume" || kind === "timer" ? Theme.gapSmall : Theme.gapMedium
  visible: kind !== ""

  // low battery: the level in red, the time left
  LiveGlyph { corner: face.badgeRadius; visible: face.kind === "battery"; size: face.coverSize; name: BatteryService.levelIcon; tint: Theme.red }
  KitText { visible: face.kind === "battery"; anchors.verticalCenter: parent.verticalCenter; text: "Battery"; color: Theme.foreground1; font.weight: Theme.material ? Font.Medium : Font.Normal }
  KitText {
    visible: face.kind === "battery" && BatteryService.minutesLeft > 0
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, 150)
    elide: Text.ElideRight
    text: "· " + (BatteryService.minutesLeft >= 60 ? Math.floor(BatteryService.minutesLeft / 60) + " h " : "") + BatteryService.minutesLeft % 60 + " min left"
    color: Theme.muted
  }
  LiveCap { size: face.coverSize; corner: face.badgeRadius; visible: face.kind === "battery"; text: BatteryService.capacity + "%"; tint: Theme.red; solid: true }

  // a device that connected: its name, the charge
  LiveGlyph { corner: face.badgeRadius; visible: face.kind === "bluetooth"; size: face.coverSize; name: "bluetooth"; tint: Theme.blue }
  KitText { visible: face.kind === "bluetooth"; anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, 180); elide: Text.ElideRight; text: BluetoothService.mainDevice?.name ?? ""; color: Theme.foreground1 }
  LiveCap { size: face.coverSize; corner: face.badgeRadius; visible: face.kind === "bluetooth" && BluetoothService.mainDevice?.battery != null; text: BluetoothService.mainDevice?.battery + "%"; tint: Theme.blue; plainBold: false }

  // vpn: the server and the ping
  LiveGlyph { corner: face.badgeRadius; visible: face.kind === "vpn" && Theme.material; size: face.coverSize; name: "shield"; tint: Theme.green }
  KitText { visible: face.kind === "vpn" && !Theme.material; anchors.verticalCenter: parent.verticalCenter; text: "VPN"; color: Theme.foreground1; font.letterSpacing: 1 }
  KitText {
    visible: face.kind === "vpn"
    anchors.verticalCenter: parent.verticalCenter
    text: MihomoService.current
    color: Theme.material ? Theme.foreground1 : Theme.foreground2
    font.weight: Theme.material ? Font.Medium : Font.Normal
    width: Math.min(implicitWidth, 110)
    elide: Text.ElideRight
  }
  LiveCap { size: face.coverSize; corner: face.badgeRadius; visible: face.kind === "vpn" && MihomoService.currentDelay > 0; text: MihomoService.currentDelay + " ms"; tint: Theme.green; plainText: String(MihomoService.currentDelay); plainTint: Theme.muted; plainBold: false }

  // radio: the station on air, the sound
  LiveGlyph { corner: face.badgeRadius; visible: face.kind === "radio" && Theme.material; size: face.coverSize; name: "radio"; tint: Theme.yellow; opacity: RadioService.active && MpdService.playing ? 1 : 0.5 }
  Rectangle {
    visible: face.kind === "radio" && !Theme.material
    anchors.verticalCenter: parent.verticalCenter
    width: 8
    height: 8
    radius: Theme.pill(height)
    color: Theme.yellow
    opacity: RadioService.active && MpdService.playing ? 1 : 0.4

    KitGlow { z: -1; anchors.fill: parent; target: "live"; lit: RadioService.active && MpdService.playing; tint: parent.color; radius: parent.radius }
  }
  KitText {
    visible: face.kind === "radio"
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, 220)
    elide: Text.ElideRight
    text: RadioService.stationName || (MpdService.player.station ?? "") || "Radio"
    color: Theme.foreground1
    font.weight: Theme.material ? Font.Medium : Font.Normal
  }
  EqualizerBars {
    visible: face.kind === "radio" && !Theme.material
    anchors.verticalCenter: parent.verticalCenter
    barCount: 4
    tone: Theme.yellow
    glowTarget: "live"
    height: 14
    active: RadioService.active && MpdService.playing
    flatWhenIdle: true
  }
  LiveCap {
    size: face.coverSize
    corner: face.badgeRadius
    visible: face.kind === "radio" && Theme.material
    text: ""
    tint: Theme.yellow
    width: 40
    EqualizerBars {
      anchors.centerIn: parent
      barCount: 4
      tone: Theme.yellow
      glowTarget: ""
      height: 14
      active: RadioService.active && MpdService.playing
      flatWhenIdle: true
    }
  }

  // timer: the ring of what is left (a stopwatch: the clock), the time
  LiveGlyph {
    corner: face.badgeRadius
    visible: face.kind === "timer" && TimerService.kind === "countdown"
    size: face.coverSize
    tint: Theme.orange
    opacity: TimerService.paused ? 0.5 : 1
    TimerRing {
      anchors.centerIn: parent
      width: parent.width - 6; height: width
      progress: TimerService.progress
      tint: Theme.orange
    }
  }
  LiveGlyph { corner: face.badgeRadius; visible: face.kind === "timer" && TimerService.kind === "stopwatch"; size: face.coverSize; name: "clock"; tint: Theme.orange }
  KitText { visible: face.kind === "timer" && Theme.material; anchors.verticalCenter: parent.verticalCenter; text: TimerService.title; color: Theme.foreground1; font.weight: Font.Medium }
  LiveCap { size: face.coverSize; corner: face.badgeRadius; visible: face.kind === "timer"; text: TimerService.text; tint: Theme.orange; opacity: TimerService.paused ? 0.5 : 1 }

  // focus: do not disturb is on
  LiveGlyph { corner: face.badgeRadius; visible: face.kind === "focus"; size: face.coverSize; name: "moon"; tint: Theme.purple }
  KitText { visible: face.kind === "focus"; anchors.verticalCenter: parent.verticalCenter; text: Theme.material ? "Focus on" : "Focus"; color: Theme.foreground1; font.weight: Theme.material ? Font.Medium : Font.Normal }

  // volume and brightness: the level as a ruler while it changes
  LiveGlyph { corner: face.badgeRadius; visible: face.kind === "volume"; size: face.coverSize; glowTarget: ""; name: IslandService.osdIcon; tint: IslandService.osdMuted || IslandService.osdLoud ? Theme.red : Theme.foreground2 }
  IslandLiveProgress {
    visible: face.kind === "volume" && Theme.material
    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: 110
    implicitHeight: 6
    value: Math.min(1, IslandService.osdLevel)
    tint: IslandService.osdLoud ? Theme.red : Theme.foreground1
  }
  Row {
    visible: face.kind === "volume" && !Theme.material
    anchors.verticalCenter: parent.verticalCenter
    spacing: 3
    Repeater {
      model: 14
      Rectangle {
        required property int index
        width: 2; height: 14; radius: Theme.pill(height)
        color: index < Math.round(Math.min(1, IslandService.osdLevel) * 14) ? (IslandService.osdLoud ? Theme.red : Theme.foreground1) : Theme.background3
      }
    }
  }
  LiveCap { size: face.coverSize; corner: face.badgeRadius; visible: face.kind === "volume"; text: Math.round(IslandService.osdLevel * 100); tint: IslandService.osdLoud ? Theme.red : Theme.foreground1; plainBold: false }

  // flashes: the mic, the layout, the cable
  LiveGlyph { corner: face.badgeRadius; visible: face.kind === "mic"; size: face.coverSize; name: IslandService.micMuted ? "mic-off" : "mic"; tint: IslandService.micMuted ? Theme.red : Theme.green }
  KitText { visible: face.kind === "mic"; anchors.verticalCenter: parent.verticalCenter; text: IslandService.micMuted ? "Muted" : "Mic on"; color: Theme.foreground1 }
  KitText { visible: face.kind === "layout"; anchors.verticalCenter: parent.verticalCenter; text: Format.layout(IslandService.layoutFrom) || IslandService.layoutFrom; color: Theme.muted }
  KitText { visible: face.kind === "layout"; anchors.verticalCenter: parent.verticalCenter; text: "→"; color: Theme.dim }
  KitText { visible: face.kind === "layout"; anchors.verticalCenter: parent.verticalCenter; text: Format.layout(IslandService.layoutNow) || IslandService.layoutNow; color: Theme.foreground1; font.weight: Font.Medium }
  readonly property color pluggedTint: BatteryService.capacity <= BatteryService.critical ? Theme.red
    : BatteryService.charging ? Theme.green
    : BatteryService.saver ? Theme.yellow : Theme.foreground1
  LiveGlyph { corner: face.badgeRadius; visible: face.kind === "plugged"; size: face.coverSize; name: "zap"; tint: face.pluggedTint }
  IslandLiveProgress {
    visible: face.kind === "plugged"
    anchors.verticalCenter: parent.verticalCenter
    value: BatteryService.capacity / 100
    tint: face.pluggedTint
  }
  KitText { visible: face.kind === "plugged"; anchors.verticalCenter: parent.verticalCenter; text: String(BatteryService.capacity); color: face.pluggedTint }
}
