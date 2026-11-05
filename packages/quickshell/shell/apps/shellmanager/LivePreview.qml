import QtQuick
import qs.bar.island
import qs.config
import qs.kit

// A sample of one live activity as the island shows it: the island's surface,
// frame and corners in the current theme, a fixed size so a list of them lines
// up (Bar › Live), the sample centred in it. Sample data.
Rectangle {
  id: root

  property string kind: ""

  implicitWidth: 190
  implicitHeight: Theme.islandHeight
  radius: Math.min(Theme.barRadiusFor(height), Theme.islandRadius)
  color: Theme.background0
  border.width: Theme.islandFrameWidth
  border.color: Theme.background2
  clip: true
  // a sample is at most this wide: samples are short on purpose, a longer one is cut

  // the real chip's (IslandLive): its glyphs and capsules, concentric with it
  readonly property int chipRadius: Math.max(0, Math.min(Theme.barRadiusFor(Theme.islandHeight), Theme.islandRadius) - 4)
  readonly property int coverSize: Theme.islandHeight - 8 - 6
  readonly property int badgeRadius: Math.max(0, chipRadius - 3)

  function wave(c) { return [0.3, 0.7, 0.45, 1, 0.55, 0.8, 0.35]; }

  // only the sample of this kind is built: every row of the list has one, and each kind carries
  // its own shapes, so building all kinds in every row made the page lag
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
      Rectangle { visible: root.kind === "notice" && ShellSettings.liveNoticeMark === "dot"; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: Theme.pill(height); color: Theme.blue; }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "notice"; text: "Nikita: скину"; font.pixelSize: Theme.fontSize - 1 }
    }
  }

  Component {
    id: c_battery
    Row {
      spacing: Theme.gapMedium
      LiveGlyph { size: root.coverSize; corner: root.badgeRadius; name: "battery-2"; tint: Theme.red }
      KitText { anchors.verticalCenter: parent.verticalCenter; text: "Battery"; color: Theme.foreground1; font.weight: Theme.material ? Font.Medium : Font.Normal }
      LiveCap { text: "9%"; tint: Theme.red; size: root.coverSize; corner: root.badgeRadius; solid: true }
    }
  }

  Component {
    id: c_bluetooth
    Row {
      spacing: Theme.gapMedium
      LiveGlyph { size: root.coverSize; corner: root.badgeRadius; name: "bluetooth"; tint: Theme.blue }
      KitText { anchors.verticalCenter: parent.verticalCenter; text: "AirPods"; color: Theme.foreground1 }
      LiveCap { text: "80%"; tint: Theme.blue; size: root.coverSize; corner: root.badgeRadius; plainBold: false }
    }
  }

  Component {
    id: c_recording
    Row {
      spacing: Theme.gapMedium
      // recording
      Rectangle { visible: root.kind === "recording"; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: Theme.pill(height); color: Theme.red; }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "recording"; text: "00:03"; font.pixelSize: Theme.fontSize - 1 }
      Row {
        visible: root.kind === "recording"
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gapTight
        Repeater { model: root.wave(); Rectangle { required property real modelData; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 14 * modelData; radius: Theme.pill(height); color: Theme.red; } }
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
      KitIcon { visible: root.kind === "update"; name: "download"; size: 12; tint: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
      Rectangle {
        visible: root.kind === "update"
        anchors.verticalCenter: parent.verticalCenter
        width: 60; height: 3; radius: Theme.pill(height); color: Theme.background3
        Rectangle { width: parent.width * 0.47; height: parent.height; radius: Theme.pill(height); color: Theme.blue; }
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
        Rectangle { width: parent.width * 0.46; height: parent.height; radius: Theme.pill(height); color: Theme.green; }
      }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "backup"; text: "1.2G"; color: Theme.foreground2; font.pixelSize: Theme.fontSize - 1 }
    }
  }

  Component {
    id: c_vpn
    Row {
      spacing: Theme.gapMedium
      LiveGlyph { visible: Theme.material; size: root.coverSize; corner: root.badgeRadius; name: "shield"; tint: Theme.green }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: !Theme.material; text: "VPN"; color: Theme.foreground1; font.letterSpacing: 1 }
      KitText { anchors.verticalCenter: parent.verticalCenter; text: "Finland"; color: Theme.material ? Theme.foreground1 : Theme.foreground2; font.weight: Theme.material ? Font.Medium : Font.Normal }
      LiveCap { text: "48 ms"; tint: Theme.green; size: root.coverSize; corner: root.badgeRadius; plainText: "48"; plainTint: Theme.muted; plainBold: false }
    }
  }

  Component {
    id: c_timer
    Row {
      spacing: Theme.gapMedium
      LiveGlyph { size: root.coverSize; corner: root.badgeRadius; name: "clock"; tint: Theme.orange }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: Theme.material; text: "Timer"; color: Theme.foreground1; font.weight: Font.Medium }
      LiveCap { text: "13:12"; tint: Theme.orange; size: root.coverSize; corner: root.badgeRadius }
    }
  }

  Component {
    id: c_radio
    Row {
      spacing: Theme.gapMedium
      LiveGlyph { size: root.coverSize; corner: root.badgeRadius; name: "radio"; tint: Theme.yellow }
      KitText { anchors.verticalCenter: parent.verticalCenter; text: "Love Radio"; color: Theme.foreground1; font.weight: Theme.material ? Font.Medium : Font.Normal }
      LiveCap {
        text: ""; tint: Theme.yellow; size: root.coverSize; corner: root.badgeRadius; width: Theme.material ? 40 : 0; visible: Theme.material
        Row { anchors.centerIn: parent; spacing: Theme.gapTight
          Repeater { model: [0.45, 1, 0.65, 0.85]; Rectangle { required property real modelData; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 14 * modelData; radius: Theme.pill(height); color: Theme.yellow } } }
      }
      Row {
        visible: !Theme.material
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.gapTight
        Repeater { model: [0.45, 1, 0.65, 0.85]; Rectangle { required property real modelData; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 14 * modelData; radius: Theme.pill(height); color: Theme.yellow } }
      }
    }
  }

  Component {
    id: c_focus
    Row {
      spacing: Theme.gapMedium
      LiveGlyph { size: root.coverSize; corner: root.badgeRadius; name: "moon"; tint: Theme.purple }
      KitText { anchors.verticalCenter: parent.verticalCenter; text: Theme.material ? "Focus on" : "Focus"; color: Theme.foreground1; font.weight: Theme.material ? Font.Medium : Font.Normal }
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
        Repeater { model: [0.45, 1, 0.65, 0.85]; Rectangle { required property real modelData; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 14 * modelData; radius: Theme.pill(height); color: Theme.green; } }
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
        Repeater { model: [0.8, 0.4, 1, 0.55]; Rectangle { required property real modelData; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 14 * modelData; radius: Theme.pill(height); color: Theme.foreground2; } }
      }
    }
  }

  Component {
    id: c_volume
    Row {
      spacing: Theme.gapMedium
      LiveGlyph { size: root.coverSize; corner: root.badgeRadius; name: "volume"; tint: Theme.foreground2 }
      Rectangle { visible: Theme.material; anchors.verticalCenter: parent.verticalCenter; width: 70; height: 6; radius: Theme.pill(height); color: Theme.background3
        Rectangle { width: parent.width * 0.62; height: parent.height; radius: parent.radius; color: Theme.foreground1 } }
      Row {
        visible: !Theme.material
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Repeater { model: 14; Rectangle { required property int index; width: 2; height: 14; radius: Theme.pill(height); color: index < 9 ? Theme.foreground1 : Theme.background3 } }
      }
      LiveCap { text: "62"; tint: Theme.foreground1; size: root.coverSize; corner: root.badgeRadius; plainBold: false }
    }
  }

  Component {
    id: c_mic
    Row {
      spacing: Theme.gapMedium
      LiveGlyph { size: root.coverSize; corner: root.badgeRadius; name: "mic-off"; tint: Theme.red }
      KitText { anchors.verticalCenter: parent.verticalCenter; text: "Muted"; color: Theme.foreground1 }
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
      LiveGlyph { size: root.coverSize; corner: root.badgeRadius; name: "zap"; tint: Theme.green }
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 70; height: Theme.material ? 6 : 4; radius: Theme.pill(height); color: Theme.background3
        Rectangle { width: parent.width * 0.52; height: parent.height; radius: parent.radius; color: Theme.green } }
      KitText { anchors.verticalCenter: parent.verticalCenter; text: "52"; color: Theme.green }
    }
  }
}
