import QtQuick
import qs.config
import qs.kit

// A sample of one live activity as the island shows it: the island's surface,
// frame and corners in the current theme, a fixed size so a list of them lines
// up (Bar › Live), the sample centred in it. Sample data.
Rectangle {
  id: root

  property string kind: ""

  implicitWidth: 190
  implicitHeight: 36
  radius: Math.min(Theme.barRadiusFor(height), Theme.islandRadius)
  color: Theme.background0
  border.width: Theme.islandFrameWidth
  border.color: Theme.background2
  clip: true

  function wave(c) { return [0.3, 0.7, 0.45, 1, 0.55, 0.8, 0.35]; }

  // only the sample of this kind is built: every row of the list has one, and each kind carries
  // glows (two shadows apiece), so building all kinds in every row made the page lag
  Loader {
    anchors.centerIn: parent
    sourceComponent: ({notice: c_notice, battery: c_battery, bluetooth: c_bluetooth, recording: c_recording, update: c_update, backup: c_backup, vpn: c_vpn, timer: c_timer, radio: c_radio, focus: c_focus, music: c_music, media: c_media, volume: c_volume, mic: c_mic, layout: c_layout, plugged: c_plugged})[root.kind] ?? null
  }

  Component {
    id: c_notice
    Row {
      spacing: Theme.gapMedium
      // messages
      Rectangle {
        visible: root.kind === "notice" && ShellSettings.liveNoticeMark === "avatar"
        anchors.verticalCenter: parent.verticalCenter
        width: 20; height: 20; radius: Theme.pill(width)
        color: Theme.mix(Theme.background0, Theme.blue, 0.22)
        KitText { anchors.centerIn: parent; text: "N"; color: Theme.blue; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Medium }
      }
      Rectangle { visible: root.kind === "notice" && ShellSettings.liveNoticeMark === "dot"; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: Theme.pill(height); color: Theme.blue; KitGlow { z: -1; anchors.fill: parent; target: "live"; tint: parent.color; radius: parent.radius } }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "notice"; text: "Nikita: скину"; font.pixelSize: Theme.fontSize - 1 }
    }
  }

  Component {
    id: c_battery
    Row {
      spacing: Theme.gapMedium
      // low battery
      Rectangle { visible: root.kind === "battery"; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: Theme.pill(height); color: Theme.red; KitGlow { z: -1; anchors.fill: parent; target: "live"; tint: parent.color; radius: parent.radius } }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "battery"; text: "9% · 14m"; font.pixelSize: Theme.fontSize - 1 }
    }
  }

  Component {
    id: c_bluetooth
    Row {
      spacing: Theme.gapMedium
      // a device connected
      Rectangle { visible: root.kind === "bluetooth"; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: Theme.pill(height); color: Theme.green; KitGlow { z: -1; anchors.fill: parent; target: "live"; tint: parent.color; radius: parent.radius } }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "bluetooth"; text: "AirPods 80"; font.pixelSize: Theme.fontSize - 1 }
    }
  }

  Component {
    id: c_recording
    Row {
      spacing: Theme.gapMedium
      // recording
      Rectangle { visible: root.kind === "recording"; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: Theme.pill(height); color: Theme.red; KitGlow { z: -1; anchors.fill: parent; target: "live"; tint: parent.color; radius: parent.radius } }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "recording"; text: "00:03"; font.pixelSize: Theme.fontSize - 1 }
      Row {
        visible: root.kind === "recording"
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gapTight
        Repeater { model: root.wave(); Rectangle { required property real modelData; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 14 * modelData; radius: Theme.pill(height); color: Theme.red; KitGlow { z: -1; anchors.fill: parent; target: "live"; tint: parent.color; radius: parent.radius } } }
      }
      // the round buttons of the live face: pause (dim) and stop (red)
      Repeater {
        model: root.kind === "recording" ? [{ stop: false }, { stop: true }] : []
        Rectangle {
          required property var modelData
          anchors.verticalCenter: parent.verticalCenter
          width: 18; height: 18; radius: Theme.pill(height)
          color: modelData.stop ? Theme.red : Theme.background3
          KitIcon {
            anchors.centerIn: parent
            name: parent.modelData.stop ? "square" : "pause"
            size: 10
            filled: true
            tint: parent.modelData.stop ? Theme.background0 : Theme.foreground1
          }
        }
      }
    }
  }

  Component {
    id: c_update
    Row {
      spacing: Theme.gapMedium
      // updates
      KitIcon { visible: root.kind === "update"; glowTarget: "live"; name: "download"; size: 12; tint: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
      Rectangle {
        visible: root.kind === "update"
        anchors.verticalCenter: parent.verticalCenter
        width: 60; height: 3; radius: Theme.pill(height); color: Theme.background3
        Rectangle { width: parent.width * 0.47; height: parent.height; radius: Theme.pill(height); color: Theme.blue; KitGlow { z: -1; anchors.fill: parent; target: "live"; tint: parent.color; radius: parent.radius } }
      }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "update"; text: "47%"; color: Theme.blue; font.pixelSize: Theme.fontSize - 1 }
    }
  }

  Component {
    id: c_backup
    Row {
      spacing: Theme.gapMedium
      // backup
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "backup"; text: "BKP"; font.pixelSize: Theme.fontSize - 3; font.letterSpacing: 1 }
      Rectangle {
        visible: root.kind === "backup"
        anchors.verticalCenter: parent.verticalCenter
        width: 70; height: 3; radius: Theme.pill(height); color: Theme.background3
        Rectangle { width: parent.width * 0.46; height: parent.height; radius: Theme.pill(height); color: Theme.green; KitGlow { z: -1; anchors.fill: parent; target: "live"; tint: parent.color; radius: parent.radius } }
      }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "backup"; text: "1.2G"; color: Theme.foreground2; font.pixelSize: Theme.fontSize - 1 }
    }
  }

  Component {
    id: c_vpn
    Row {
      spacing: Theme.gapMedium
      // vpn
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "vpn"; text: "VPN"; font.pixelSize: Theme.fontSize - 3; font.letterSpacing: 1 }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "vpn"; text: "Finland"; font.pixelSize: Theme.fontSize - 1 }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "vpn"; text: "483"; color: Theme.foreground2; font.pixelSize: Theme.fontSize - 1 }
    }
  }

  Component {
    id: c_timer
    Row {
      spacing: Theme.gapMedium
      // timer
      KitIcon { visible: root.kind === "timer"; glowTarget: "live"; anchors.verticalCenter: parent.verticalCenter; name: "clock"; size: 16; tint: Theme.orange }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "timer"; text: "13:12"; color: Theme.orange; font.pixelSize: Theme.fontSize - 1 }
    }
  }

  Component {
    id: c_radio
    Row {
      spacing: Theme.gapMedium
      // radio
      Rectangle { visible: root.kind === "radio"; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: Theme.pill(height); color: Theme.yellow; KitGlow { z: -1; anchors.fill: parent; target: "live"; tint: parent.color; radius: parent.radius } }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "radio"; text: "Love Radio"; font.pixelSize: Theme.fontSize - 1 }
    }
  }

  Component {
    id: c_focus
    Row {
      spacing: Theme.gapMedium
      // focus
      KitIcon { visible: root.kind === "focus"; glowTarget: "live"; anchors.verticalCenter: parent.verticalCenter; name: "moon"; size: 16; tint: Theme.purple }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "focus"; text: "Focus"; font.pixelSize: Theme.fontSize - 1 }
    }
  }

  Component {
    id: c_music
    Row {
      spacing: Theme.gapMedium
      // music: the cover, the name, the sound
      Rectangle { visible: root.kind === "music" && ShellSettings.liveMusicCover; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: Theme.pill(width); color: Theme.background3
        KitIcon { anchors.centerIn: parent; name: "music"; size: 9; tint: Theme.foreground2 } }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "music"; text: "Survivor"; font.pixelSize: Theme.fontSize - 1; width: Math.min(implicitWidth, 64); elide: Text.ElideRight }
      Row {
        visible: root.kind === "music"
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gapTight
        Repeater { model: [0.45, 1, 0.65, 0.85]; Rectangle { required property real modelData; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 14 * modelData; radius: Theme.pill(height); color: Theme.green; KitGlow { z: -1; anchors.fill: parent; target: "live"; tint: parent.color; radius: parent.radius } } }
      }
    }
  }

  Component {
    id: c_media
    Row {
      spacing: Theme.gapMedium
      // media: another app's sound — the app's icon, the title, the sound
      Rectangle { visible: root.kind === "media" && ShellSettings.liveMediaCover; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; radius: Theme.pill(width); color: Theme.background3
        KitIcon { anchors.centerIn: parent; name: "play"; size: 9; tint: Theme.foreground2 } }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "media"; text: "Lo-fi stream"; font.pixelSize: Theme.fontSize - 1; width: Math.min(implicitWidth, 80); elide: Text.ElideRight }
      Row {
        visible: root.kind === "media"
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gapTight
        Repeater { model: [0.8, 0.4, 1, 0.55]; Rectangle { required property real modelData; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 14 * modelData; radius: Theme.pill(height); color: Theme.foreground2; KitGlow { z: -1; anchors.fill: parent; target: "live"; tint: parent.color; radius: parent.radius } } }
      }
    }
  }

  Component {
    id: c_volume
    Row {
      spacing: Theme.gapMedium
      // volume and brightness
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "volume"; text: "VOL"; font.pixelSize: Theme.fontSize - 3; font.letterSpacing: 1 }
      Row {
        visible: root.kind === "volume"
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Repeater { model: 14; Rectangle { required property int index; width: 2; height: 14; radius: Theme.pill(height); color: index < 9 ? Theme.foreground1 : Theme.background3 } }
      }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "volume"; text: "62"; font.pixelSize: Theme.fontSize - 1 }
    }
  }

  Component {
    id: c_mic
    Row {
      spacing: Theme.gapMedium
      // microphone
      KitIcon { visible: root.kind === "mic"; glowTarget: "live"; name: "mic-off"; size: 13; tint: Theme.red; anchors.verticalCenter: parent.verticalCenter }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "mic"; text: "Muted"; font.pixelSize: Theme.fontSize - 1 }
    }
  }

  Component {
    id: c_layout
    Row {
      spacing: Theme.gapMedium
      // keyboard layout
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "layout"; text: "EN"; color: Theme.muted; font.pixelSize: Theme.fontSize - 1 }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "layout"; text: "→"; color: Theme.dim; font.pixelSize: Theme.fontSize - 1 }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "layout"; text: "RU"; font.pixelSize: Theme.fontSize - 1; font.weight: Font.Medium }
    }
  }

  Component {
    id: c_plugged
    Row {
      spacing: Theme.gapMedium
      // the cable
      KitIcon { visible: root.kind === "plugged"; glowTarget: "live"; name: "zap"; size: 12; tint: Theme.green; anchors.verticalCenter: parent.verticalCenter }
      Rectangle {
        visible: root.kind === "plugged"
        anchors.verticalCenter: parent.verticalCenter
        width: 70; height: 3; radius: Theme.pill(height); color: Theme.background3
        Rectangle { width: parent.width * 0.52; height: parent.height; radius: Theme.pill(height); color: Theme.green; KitGlow { z: -1; anchors.fill: parent; target: "live"; tint: parent.color; radius: parent.radius } }
      }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "plugged"; text: "52"; color: Theme.green; font.pixelSize: Theme.fontSize - 1 }
    }
  }
}
