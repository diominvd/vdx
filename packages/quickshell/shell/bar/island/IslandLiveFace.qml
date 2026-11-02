import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.apps.auth
import qs.apps.backup
import qs.apps.capture
import qs.apps.packages
import qs.components
import qs.config
import qs.kit
import qs.modules.battery
import qs.modules.bluetooth
import qs.modules.mihomo
import qs.modules.equalizer
import qs.modules.focus
import qs.modules.mpd
import qs.modules.player
import qs.modules.radio
import qs.modules.timer

// One face of the pill's live slot (IslandLive): what the activity `kind` shows.
Row {
  id: face

  property string kind: ""
  property bool inputEnabled: true
  property int coverSize: 18                   // a badge (cover, avatar): the chip's height less its inset on both sides
  property int badgeRadius: 4                  // concentric with the chip
  // an activity that starts with a badge sits it the same inset from the chip's left, top and bottom
  readonly property bool track: kind === "music" || kind === "media"
  readonly property var player: kind === "media" ? PlayerService.media : PlayerService.music
  readonly property bool badged: track || kind === "notice" && ShellSettings.liveNoticeMark === "avatar"   // a dot sits as far from the rim as the right side

  anchors.verticalCenter: parent.verticalCenter
  spacing: 8
  visible: kind !== ""

  // recording: the dot, the time, the sound, pause and stop
  Rectangle {
    visible: face.kind === "recording"
    anchors.verticalCenter: parent.verticalCenter
    width: 8
    height: 8
    radius: Theme.pill(height)
    color: Theme.red
    opacity: CaptureService.paused ? 0.4 : 1

    KitGlow { z: -1; anchors.fill: parent; target: "live"; lit: !CaptureService.paused; tint: parent.color; radius: parent.radius }
  }
  KitText {
    visible: face.kind === "recording"
    anchors.verticalCenter: parent.verticalCenter
    text: CaptureService.elapsedText
    color: Theme.foreground1
    font.weight: Font.Medium
  }
  EqualizerBars {
    visible: face.kind === "recording"
    anchors.verticalCenter: parent.verticalCenter
    barCount: 7
    tone: Theme.red
    glowTarget: "live"
    height: 16
    active: !CaptureService.paused
  }
  // round buttons, the chip's height less its inset: pause (dim) and stop (red)
  Repeater {
    model: face.kind === "recording" ? [{ stop: false }, { stop: true }] : []
    Rectangle {
      id: btn
      required property var modelData
      readonly property bool stop: modelData.stop
      anchors.verticalCenter: parent.verticalCenter
      width: face.coverSize
      height: face.coverSize
      radius: Theme.pill(height)
      color: stop ? Theme.red : Theme.background3
      opacity: area.containsMouse ? 0.85 : 1
      Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
      Accessible.role: Accessible.Button
      Accessible.name: stop ? "Stop recording" : CaptureService.paused ? "Resume recording" : "Pause recording"

      KitIcon {
        anchors.centerIn: parent
        name: btn.stop ? "square" : CaptureService.paused ? "play" : "pause"
        size: 12
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

  // update: the download's progress, else what runs
  KitIcon { visible: face.kind === "update"; glowTarget: "live"; name: "download"; tint: Theme.blue; size: 14; anchors.verticalCenter: parent.verticalCenter }
  readonly property bool updateBar: face.kind === "update" && PackagesService.stage === "downloading"
  Rectangle {
    visible: face.updateBar
    anchors.verticalCenter: parent.verticalCenter
    width: 90
    height: 4
    radius: Theme.pill(height)
    color: Theme.background3
    Rectangle {
      width: parent.width * PackagesService.stagePercent
      height: parent.height
      radius: Theme.pill(height)
      color: Theme.blue

      KitGlow { z: -1; anchors.fill: parent; target: "live"; tint: parent.color; radius: parent.radius }
    }
  }
  KitText { visible: face.updateBar; text: Math.round(PackagesService.stagePercent * 100) + "%"; color: Theme.blue }
  KitText {
    visible: face.kind === "update" && !face.updateBar
    width: Math.min(implicitWidth, 180)
    elide: Text.ElideRight
    text: PackagesService.stage === "installing" ? "Installing packages" : PackagesService.busy ? "Updating packages" : RootService.title
    color: Theme.blue
  }

  // backup: BKP and its progress
  KitText { visible: face.kind === "backup"; text: "BKP"; color: Theme.foreground1; font.letterSpacing: 1 }
  Rectangle {
    visible: face.kind === "backup"
    anchors.verticalCenter: parent.verticalCenter
    width: 70
    height: 4
    radius: Theme.pill(height)
    color: Theme.background3
    Rectangle {
      width: parent.width * Math.max(0, BackupService.progress) / 100
      height: parent.height
      radius: Theme.pill(height)
      color: Theme.green

      KitGlow { z: -1; anchors.fill: parent; target: "live"; tint: parent.color; radius: parent.radius }
    }
  }

  KitText {
    visible: face.kind === "backup"
    text: Math.max(0, Math.round(BackupService.progress)) + "%"
    color: Theme.foreground2
  }

  // a notification, as a line: the app's initial, "app: summary"
  Rectangle {
    visible: face.kind === "notice" && ShellSettings.liveNoticeMark === "dot"
    anchors.verticalCenter: parent.verticalCenter
    width: 8; height: 8; radius: Theme.pill(height)
    color: IslandService.noticeItem?.urgency === "critical" ? Theme.red : Theme.appColour(IslandService.noticeItem?.app)
  }
  Rectangle {
    visible: face.kind === "notice" && ShellSettings.liveNoticeMark === "avatar"
    anchors.verticalCenter: parent.verticalCenter
    width: face.coverSize
    height: face.coverSize
    radius: face.badgeRadius
    readonly property color tone: IslandService.noticeItem?.urgency === "critical" ? Theme.red : Theme.appColour(IslandService.noticeItem?.app)
    color: Theme.mix(Theme.background0, tone, 0.22)
    readonly property string appIcon: Hypr.iconOfApp(IslandService.noticeItem?.desktop, IslandService.noticeItem?.app)
    // the app's own icon; an app with none gets its initial
    IconImage {
      anchors.centerIn: parent
      implicitSize: parent.width - 4
      source: parent.appIcon
      visible: parent.appIcon !== ""
    }
    KitText { anchors.centerIn: parent; visible: parent.appIcon === ""; text: (IslandService.noticeItem?.app ?? "").slice(0, 1).toUpperCase(); color: parent.tone; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Medium }
  }
  KitText {
    visible: face.kind === "notice"
    width: Math.min(implicitWidth, 300)
    elide: Text.ElideRight
    textFormat: Text.PlainText
    text: {
      const n = IslandService.noticeItem;
      if (!n) return "";
      const head = n.summary !== "" ? n.summary : n.app;
      return n.body !== "" ? head + ": " + n.body : head;
    }
    color: IslandService.noticeItem?.urgency === "critical" ? Theme.red : Theme.foreground1
  }

  // low battery: the level in red, the time left
  KitIcon { visible: face.kind === "battery"; glowTarget: "live"; name: BatteryService.levelIcon; size: 16; tint: Theme.red; anchors.verticalCenter: parent.verticalCenter }
  KitText { visible: face.kind === "battery"; text: "Battery"; color: Theme.foreground1 }
  KitText { visible: face.kind === "battery"; text: BatteryService.capacity + "%"; color: Theme.red }
  KitText {
    visible: face.kind === "battery" && BatteryService.minutesLeft > 0
    width: Math.min(implicitWidth, 150)
    elide: Text.ElideRight
    text: "· " + (BatteryService.minutesLeft >= 60 ? Math.floor(BatteryService.minutesLeft / 60) + " h " : "") + BatteryService.minutesLeft % 60 + " min left"
    color: Theme.muted
  }

  // a device that connected: its name, the charge
  KitIcon { visible: face.kind === "bluetooth"; glowTarget: "live"; name: "bluetooth"; size: 16; tint: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
  KitText { visible: face.kind === "bluetooth"; width: Math.min(implicitWidth, 180); elide: Text.ElideRight; text: BluetoothService.mainDevice?.name ?? ""; color: Theme.foreground1 }
  KitText {
    visible: face.kind === "bluetooth" && BluetoothService.mainDevice?.battery != null
    text: BluetoothService.mainDevice?.battery + "%"
    color: Theme.blue
  }

  // vpn: the server and the ping
  KitText { visible: face.kind === "vpn"; text: "VPN"; color: Theme.foreground1; font.letterSpacing: 1 }
  KitText { visible: face.kind === "vpn"; text: MihomoService.current; color: Theme.foreground2; width: Math.min(implicitWidth, 110); elide: Text.ElideRight }
  KitText { visible: face.kind === "vpn" && MihomoService.currentDelay > 0; text: String(MihomoService.currentDelay); color: Theme.muted }

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
  KitText { visible: face.kind === "focus"; text: "Focus"; color: Theme.foreground1 }

  // volume and brightness: the level as a ruler while it changes
  KitIcon { visible: face.kind === "volume"; name: IslandService.osdIcon; size: 14; tint: IslandService.osdMuted ? Theme.red : IslandService.osdLoud ? Theme.red : Theme.foreground2; anchors.verticalCenter: parent.verticalCenter }
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
  KitText { visible: face.kind === "volume"; text: Math.round(IslandService.osdLevel * 100); color: IslandService.osdLoud ? Theme.red : Theme.foreground1 }

  // flashes: the mic, the layout, the cable
  KitIcon { visible: face.kind === "mic"; glowTarget: "live"; name: IslandService.micMuted ? "mic-off" : "mic"; size: 14; tint: IslandService.micMuted ? Theme.red : Theme.green; anchors.verticalCenter: parent.verticalCenter }
  KitText { visible: face.kind === "mic"; text: IslandService.micMuted ? "Muted" : "Mic on"; color: Theme.foreground1 }
  KitText { visible: face.kind === "layout"; text: Format.layout(IslandService.layoutFrom) || IslandService.layoutFrom; color: Theme.muted }
  KitText { visible: face.kind === "layout"; text: "→"; color: Theme.dim }
  KitText { visible: face.kind === "layout"; text: Format.layout(IslandService.layoutNow) || IslandService.layoutNow; color: Theme.foreground1; font.weight: Font.Medium }
  KitIcon { visible: face.kind === "plugged"; glowTarget: "live"; name: "zap"; size: 14; tint: Theme.purple; anchors.verticalCenter: parent.verticalCenter }
  Rectangle {
    visible: face.kind === "plugged"
    anchors.verticalCenter: parent.verticalCenter
    width: 70; height: 4; radius: Theme.pill(height)
    color: Theme.background3
    Rectangle {
      width: parent.width * BatteryService.capacity / 100; height: parent.height; radius: Theme.pill(height); color: Theme.purple
      KitGlow { z: -1; anchors.fill: parent; target: "live"; tint: parent.color; radius: parent.radius }
    }
  }
  KitText { visible: face.kind === "plugged"; text: String(BatteryService.capacity); color: Theme.purple }

  // music and media: the cover, the track and the sound
  Item {
    visible: face.track
    anchors.verticalCenter: parent.verticalCenter
    width: face.coverSize
    height: face.coverSize

    Image {
      id: cover
      anchors.fill: parent
      visible: false
      source: face.player.cover
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
    }
    Item {
      id: round
      anchors.fill: parent
      visible: false
      layer.enabled: true
      Rectangle { anchors.fill: parent; radius: face.badgeRadius }
    }
    // a circle: the cover's corners cut by the mask
    MultiEffect {
      anchors.fill: parent
      source: cover
      maskEnabled: true
      maskSource: round
    }
    Rectangle { anchors.fill: parent; radius: face.badgeRadius; color: Theme.background3; z: -1 }
  }
  KitText {
    visible: face.track
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, 260)
    elide: Text.ElideRight
    text: !face.player.hasMedia ? "Nothing playing" : face.player.title + (face.player.artist !== "" ? " · " + face.player.artist : "")
    color: Theme.foreground1
  }
  EqualizerBars {
    visible: face.track
    anchors.verticalCenter: parent.verticalCenter
    barCount: 4
    tone: face.kind === "media" ? Theme.foreground2 : Theme.green
    glowTarget: "live"
    height: 14
    active: face.player.playing      // its own player: the radio or another app playing does not move it
    flatWhenIdle: true
  }
}
