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
  property int coverSize: 18
  spacing: kind === "volume" || kind === "timer" ? Theme.gapSmall : Theme.gapMedium
  visible: kind !== ""

  // low battery: the level in red, the time left
  LiveGlyph { visible: face.kind === "battery"; size: face.coverSize; name: BatteryService.levelIcon; tint: Theme.red }
  KitText { visible: face.kind === "battery"; anchors.verticalCenter: parent.verticalCenter; text: "Battery"; color: Theme.foreground1 }
  KitText {
    visible: face.kind === "battery" && BatteryService.minutesLeft > 0
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, 150)
    elide: Text.ElideRight
    text: "· " + (BatteryService.minutesLeft >= 60 ? Math.floor(BatteryService.minutesLeft / 60) + " h " : "") + BatteryService.minutesLeft % 60 + " min left"
    color: Theme.muted
  }
  LiveCap { visible: face.kind === "battery"; text: BatteryService.capacity + "%"; tint: Theme.red; solid: true }

  // a device that connected: its name, the charge
  LiveGlyph { visible: face.kind === "bluetooth"; size: face.coverSize; name: "bluetooth"; tint: Theme.blue }
  KitText { visible: face.kind === "bluetooth"; anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, 180); elide: Text.ElideRight; text: BluetoothService.mainDevice?.name ?? ""; color: Theme.foreground1 }
  LiveCap { visible: face.kind === "bluetooth" && BluetoothService.mainDevice?.battery != null; text: BluetoothService.mainDevice?.battery + "%"; tint: Theme.blue; plainBold: false }

  // vpn: the server and the ping
  KitText { visible: face.kind === "vpn"; anchors.verticalCenter: parent.verticalCenter; text: "VPN"; color: Theme.foreground1; font.letterSpacing: 1 }
  KitText { visible: face.kind === "vpn"; anchors.verticalCenter: parent.verticalCenter; text: MihomoService.current; color: Theme.foreground2; width: Math.min(implicitWidth, 110); elide: Text.ElideRight }
  LiveCap { visible: face.kind === "vpn" && MihomoService.currentDelay > 0; text: MihomoService.currentDelay + " ms"; tint: Theme.green; plainText: String(MihomoService.currentDelay); plainTint: Theme.muted; plainBold: false }

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
  LiveGlyph {
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
  LiveGlyph { visible: face.kind === "timer" && TimerService.kind === "stopwatch"; size: face.coverSize; name: "clock"; tint: Theme.orange }
  LiveCap { visible: face.kind === "timer"; text: TimerService.text; tint: Theme.orange; opacity: TimerService.paused ? 0.5 : 1 }

  // focus: do not disturb is on
  LiveGlyph { visible: face.kind === "focus"; size: face.coverSize; name: "moon"; tint: Theme.purple }
  KitText { visible: face.kind === "focus"; anchors.verticalCenter: parent.verticalCenter; text: "Focus"; color: Theme.foreground1 }

  // volume and brightness: the level as a ruler while it changes
  LiveGlyph { visible: face.kind === "volume"; size: face.coverSize; glowTarget: ""; name: IslandService.osdIcon; tint: IslandService.osdMuted || IslandService.osdLoud ? Theme.red : Theme.foreground2 }
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
  LiveCap { visible: face.kind === "volume"; text: Math.round(IslandService.osdLevel * 100); tint: IslandService.osdLoud ? Theme.red : Theme.foreground1; plainBold: false }

  // flashes: the mic, the layout, the cable
  LiveGlyph { visible: face.kind === "mic"; size: face.coverSize; name: IslandService.micMuted ? "mic-off" : "mic"; tint: IslandService.micMuted ? Theme.red : Theme.green }
  KitText { visible: face.kind === "mic"; anchors.verticalCenter: parent.verticalCenter; text: IslandService.micMuted ? "Muted" : "Mic on"; color: Theme.foreground1 }
  KitText { visible: face.kind === "layout"; anchors.verticalCenter: parent.verticalCenter; text: Format.layout(IslandService.layoutFrom) || IslandService.layoutFrom; color: Theme.muted }
  KitText { visible: face.kind === "layout"; anchors.verticalCenter: parent.verticalCenter; text: "→"; color: Theme.dim }
  KitText { visible: face.kind === "layout"; anchors.verticalCenter: parent.verticalCenter; text: Format.layout(IslandService.layoutNow) || IslandService.layoutNow; color: Theme.foreground1; font.weight: Font.Medium }
  readonly property color pluggedTint: BatteryService.capacity <= BatteryService.critical ? Theme.red
    : BatteryService.charging ? Theme.green
    : BatteryService.saver ? Theme.yellow : Theme.foreground1
  LiveGlyph { visible: face.kind === "plugged"; size: face.coverSize; name: "zap"; tint: face.pluggedTint }
  IslandLiveProgress {
    visible: face.kind === "plugged"
    anchors.verticalCenter: parent.verticalCenter
    value: BatteryService.capacity / 100
    tint: face.pluggedTint
  }
  KitText { visible: face.kind === "plugged"; anchors.verticalCenter: parent.verticalCenter; text: String(BatteryService.capacity); color: face.pluggedTint }
}
