import QtQuick
import qs.components
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

Row {
  id: face

  property string kind: ""
  spacing: Theme.gapMedium
  visible: kind !== ""

  // low battery: the level in red, the time left
  KitIcon { visible: face.kind === "battery"; glowTarget: "live"; name: BatteryService.levelIcon; size: 16; tint: Theme.red; anchors.verticalCenter: parent.verticalCenter }
  KitText { visible: face.kind === "battery"; anchors.verticalCenter: parent.verticalCenter; text: "Battery"; color: Theme.foreground1 }
  KitText { visible: face.kind === "battery"; anchors.verticalCenter: parent.verticalCenter; width: 34; horizontalAlignment: Text.AlignRight; text: BatteryService.capacity + "%"; color: Theme.red }
  KitText {
    visible: face.kind === "battery" && BatteryService.minutesLeft > 0
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, 150)
    elide: Text.ElideRight
    text: "· " + (BatteryService.minutesLeft >= 60 ? Math.floor(BatteryService.minutesLeft / 60) + " h " : "") + BatteryService.minutesLeft % 60 + " min left"
    color: Theme.muted
  }

  // a device that connected: its name, the charge
  KitIcon { visible: face.kind === "bluetooth"; glowTarget: "live"; name: "bluetooth"; size: 16; tint: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
  KitText { visible: face.kind === "bluetooth"; anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, 180); elide: Text.ElideRight; text: BluetoothService.mainDevice?.name ?? ""; color: Theme.foreground1 }
  KitText {
    visible: face.kind === "bluetooth" && BluetoothService.mainDevice?.battery != null
    anchors.verticalCenter: parent.verticalCenter
    text: BluetoothService.mainDevice?.battery + "%"
    color: Theme.blue
  }

  // vpn: the server and the ping
  KitText { visible: face.kind === "vpn"; anchors.verticalCenter: parent.verticalCenter; text: "VPN"; color: Theme.foreground1; font.letterSpacing: 1 }
  KitText { visible: face.kind === "vpn"; anchors.verticalCenter: parent.verticalCenter; text: MihomoService.current; color: Theme.foreground2; width: Math.min(implicitWidth, 110); elide: Text.ElideRight }
  KitText { visible: face.kind === "vpn" && MihomoService.currentDelay > 0; anchors.verticalCenter: parent.verticalCenter; text: String(MihomoService.currentDelay); color: Theme.muted }

  // radio: the station on air, the sound
  Rectangle {
    visible: face.kind === "radio"
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
  }
  EqualizerBars {
    visible: face.kind === "radio"
    anchors.verticalCenter: parent.verticalCenter
    barCount: 4
    tone: Theme.yellow
    glowTarget: "live"
    height: 14
    active: RadioService.active && MpdService.playing
    flatWhenIdle: true
  }

  // timer: the ring of what is left (a stopwatch: the clock), the time
  TimerRing {
    visible: face.kind === "timer" && TimerService.kind === "countdown"
    anchors.verticalCenter: parent.verticalCenter
    width: 16; height: 16
    progress: TimerService.progress
    tint: Theme.orange
    opacity: TimerService.paused ? 0.5 : 1
  }
  KitIcon { visible: face.kind === "timer" && TimerService.kind === "stopwatch"; glowTarget: "live"; name: "clock"; size: 16; tint: Theme.orange; anchors.verticalCenter: parent.verticalCenter }
  KitText {
    visible: face.kind === "timer"
    anchors.verticalCenter: parent.verticalCenter
    text: TimerService.text
    color: Theme.orange
    font.weight: Font.Medium
    opacity: TimerService.paused ? 0.5 : 1
  }

  // focus: do not disturb is on
  KitIcon { visible: face.kind === "focus"; glowTarget: "live"; name: "moon"; size: 16; tint: Theme.purple; anchors.verticalCenter: parent.verticalCenter }
  KitText { visible: face.kind === "focus"; anchors.verticalCenter: parent.verticalCenter; text: "Focus"; color: Theme.foreground1 }

  // volume and brightness: the level as a ruler while it changes
  KitIcon { visible: face.kind === "volume"; name: IslandService.osdIcon; size: 16; tint: IslandService.osdMuted ? Theme.red : IslandService.osdLoud ? Theme.red : Theme.foreground2; anchors.verticalCenter: parent.verticalCenter }
  Row {
    visible: face.kind === "volume"
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
  KitText { visible: face.kind === "volume"; anchors.verticalCenter: parent.verticalCenter; width: 30; horizontalAlignment: Text.AlignRight; text: Math.round(IslandService.osdLevel * 100); color: IslandService.osdLoud ? Theme.red : Theme.foreground1 }

  // flashes: the mic, the layout, the cable
  KitIcon { visible: face.kind === "mic"; glowTarget: "live"; name: IslandService.micMuted ? "mic-off" : "mic"; size: 16; tint: IslandService.micMuted ? Theme.red : Theme.green; anchors.verticalCenter: parent.verticalCenter }
  KitText { visible: face.kind === "mic"; anchors.verticalCenter: parent.verticalCenter; text: IslandService.micMuted ? "Muted" : "Mic on"; color: Theme.foreground1 }
  KitText { visible: face.kind === "layout"; anchors.verticalCenter: parent.verticalCenter; text: Format.layout(IslandService.layoutFrom) || IslandService.layoutFrom; color: Theme.muted }
  KitText { visible: face.kind === "layout"; anchors.verticalCenter: parent.verticalCenter; text: "→"; color: Theme.dim }
  KitText { visible: face.kind === "layout"; anchors.verticalCenter: parent.verticalCenter; text: Format.layout(IslandService.layoutNow) || IslandService.layoutNow; color: Theme.foreground1; font.weight: Font.Medium }
  readonly property color pluggedTint: BatteryService.capacity <= BatteryService.critical ? Theme.red
    : BatteryService.charging ? Theme.green
    : BatteryService.saver ? Theme.yellow : Theme.foreground1
  KitIcon { visible: face.kind === "plugged"; glowTarget: "live"; name: "zap"; size: 16; tint: face.pluggedTint; anchors.verticalCenter: parent.verticalCenter }
  IslandLiveProgress {
    visible: face.kind === "plugged"
    anchors.verticalCenter: parent.verticalCenter
    value: BatteryService.capacity / 100
    tint: face.pluggedTint
  }
  KitText { visible: face.kind === "plugged"; anchors.verticalCenter: parent.verticalCenter; text: String(BatteryService.capacity); color: face.pluggedTint }
}
