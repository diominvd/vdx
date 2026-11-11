import QtQuick
import qs.bar.island
import qs.config
import qs.kit

// A sample of one live activity as the island shows it: the island's surface,
// frame and corners in the current theme, a fixed size so a list of them lines
// up (Bar › Live), the sample centred in it. Sample data.
Item {
  id: root

  property string kind: ""
  // what the sample lies on (the row's fill): the chip keeps its distance from it in every theme
  property color surface: Theme.sectionFill

  // a slot of one width, so the names beside the samples line up; the chip is as wide as its content
  implicitWidth: 230
  implicitHeight: Theme.islandHeight
  clip: true

  // the real chip's (IslandLive): its glyphs and capsules, concentric with it
  readonly property int chipRadius: Math.max(0, Math.min(Theme.barRadiusFor(Theme.islandHeight), Theme.islandRadius) - 4)
  readonly property int coverSize: Theme.islandHeight - 8 - 6
  readonly property int badgeRadius: Math.max(0, chipRadius - 3)

  function wave(c) { return [0.3, 0.7, 0.45, 1, 0.55, 0.8, 0.35]; }

  // only the sample of this kind is built: every row of the list has one, and each kind carries
  // its own shapes, so building all kinds in every row made the page lag
  // the chip of the live slot: darker than the island, its sides padded as IslandLiveFace does
  readonly property int capHeight: Math.round(Theme.fontSize * 0.73)
  function padFor(end) {
    if (!end) return 0;
    const shape = end.liveEnd ?? (typeof end.text === "string" && end.font !== undefined ? "text" : "");
    if (shape === "badge") return 3;
    const ink = shape === "text" ? capHeight : end.height;
    return Math.max(Math.round((chipHeight - ink) / 2), chipRadius);
  }
  property int lead: 0
  property int trail: 0
  function measure() {
    const it = body.item;
    let first = null, last = null;
    if (it) for (const c of it.children) {
      if (!c.visible || c.width <= 0) continue;
      if (!first) first = c;
      last = c;
    }
    lead = padFor(first);
    trail = padFor(last);
  }

  readonly property int chipHeight: Theme.islandHeight - 8

  component Wave: Row {
    property color tone: Theme.green
    property var levels: [0.45, 1, 0.65, 0.85]
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.gapTight
    Repeater { model: parent.levels; Rectangle { required property real modelData; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 16 * modelData; radius: Theme.pill(height); color: parent.tone } }
  }

  Rectangle {
    id: chip
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(root.width, body.width + root.lead + root.trail)
    height: root.chipHeight
    radius: root.chipRadius
    color: Theme.separated(Theme.background1, root.surface, 1.25)      // the live slot's own fill in the bar, kept apart from the row
    clip: true

  Loader {
    id: body
    x: root.lead
    anchors.verticalCenter: parent.verticalCenter
    onLoaded: { root.measure(); Qt.callLater(root.measure); }
    // a part comes or goes (the buttons of a recording, an avatar that loads) or takes its size after the
    // first read: the two ends are read again
    Connections {
      target: body.item
      ignoreUnknownSignals: true
      function onChildrenChanged() { Qt.callLater(root.measure); }
      function onImplicitWidthChanged() { Qt.callLater(root.measure); }
    }
    sourceComponent: ({notice: c_notice, battery: c_battery, bluetooth: c_bluetooth, recording: c_recording, update: c_update, backup: c_backup, vpn: c_vpn, timer: c_timer, radio: c_radio, focus: c_focus, music: c_music, media: c_media, volume: c_volume, mic: c_mic, layout: c_layout, plugged: c_plugged})[root.kind] ?? null
  }
  }

  Component {
    id: c_notice
    Row {
      spacing: Theme.gapMedium
      // messages
      Rectangle {
        visible: root.kind === "notice" && ShellSettings.liveNoticeMark !== "dot"
        anchors.verticalCenter: parent.verticalCenter
        readonly property string liveEnd: "badge"
        width: root.coverSize
        height: root.coverSize
        radius: root.badgeRadius
        color: Theme.tonalOn(Theme.blue, chip.color)
        KitIcon { anchors.centerIn: parent; visible: ShellSettings.liveNoticeMark === "avatar"; name: "bell"; size: 16; tint: Theme.blue }
        KitText { anchors.centerIn: parent; visible: ShellSettings.liveNoticeMark === "initial"; text: "N"; color: Theme.blue; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Medium }
      }
      Rectangle { visible: root.kind === "notice" && ShellSettings.liveNoticeMark === "dot"; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: Theme.pill(height); color: Theme.blue; }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "notice"; text: "Nikita: скину"; font.pixelSize: Theme.fontSize - 1 }
    }
  }

  Component {
    id: c_battery
    Row {
      spacing: Theme.gapMedium
      LiveGlyph { surface: chip.color; size: root.coverSize; corner: root.badgeRadius; name: "battery-2"; tint: Theme.red }
      KitText { anchors.verticalCenter: parent.verticalCenter; text: "Battery"; color: Theme.foreground1; font.weight: Theme.material ? Font.Medium : Font.Normal }
      LiveCap { surface: chip.color; text: "9%"; tint: Theme.red; size: root.coverSize; corner: root.badgeRadius; solid: true }
    }
  }

  Component {
    id: c_bluetooth
    Row {
      spacing: Theme.gapMedium
      LiveGlyph { surface: chip.color; size: root.coverSize; corner: root.badgeRadius; name: "bluetooth"; tint: Theme.blue }
      KitText { anchors.verticalCenter: parent.verticalCenter; text: "Headphones"; color: Theme.foreground1 }
      LiveCap { surface: chip.color; text: "80%"; tint: Theme.blue; size: root.coverSize; corner: root.badgeRadius; plainBold: false }
    }
  }

  Component {
    id: c_recording
    Row {
      spacing: Theme.gapMedium
      // recording
      Rectangle { visible: root.kind === "recording"; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: Theme.pill(height); color: Theme.red; }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: root.kind === "recording"; text: "00:03"; font.pixelSize: Theme.fontSize - 1 }
      Wave { visible: root.kind === "recording"; tone: Theme.red; levels: root.wave() }
      // the round buttons of the live face: pause (dim) and stop (red)
      Repeater {
        model: root.kind === "recording" && ShellSettings.liveRecordingButtons ? [{ stop: false }, { stop: true }] : []
        Rectangle {
          required property var modelData
          anchors.verticalCenter: parent.verticalCenter
          readonly property string liveEnd: "badge"
          width: root.coverSize; height: root.coverSize; radius: root.badgeRadius
          color: modelData.stop ? Theme.red : Theme.background3
          KitIcon {
            anchors.centerIn: parent
            name: parent.modelData.stop ? "square" : "pause"
            size: 12
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
      LiveGlyph { surface: chip.color; size: root.coverSize; corner: root.badgeRadius; name: "download"; tint: Theme.blue }
      IslandLiveProgress { anchors.verticalCenter: parent.verticalCenter; value: 0.47; tint: Theme.blue }
      KitText { anchors.verticalCenter: parent.verticalCenter; text: "47%"; color: Theme.blue }
    }
  }

  Component {
    id: c_backup
    Row {
      spacing: Theme.gapMedium
      // backup
      LiveGlyph { surface: chip.color; size: root.coverSize; corner: root.badgeRadius; name: "history"; tint: Theme.green }
      IslandLiveProgress { anchors.verticalCenter: parent.verticalCenter; value: 0.46; tint: Theme.green }
      KitText { anchors.verticalCenter: parent.verticalCenter; text: "46%"; color: Theme.foreground2 }
    }
  }

  Component {
    id: c_vpn
    Row {
      spacing: Theme.gapMedium
      LiveGlyph { surface: chip.color; size: root.coverSize; corner: root.badgeRadius; name: "public"; tint: Theme.green }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: ShellSettings.liveVpnServer; text: "Finland"; color: Theme.material ? Theme.foreground1 : Theme.foreground2; font.weight: Theme.material ? Font.Medium : Font.Normal }
      LiveCap { visible: ShellSettings.liveVpnPing; surface: chip.color; text: "48 ms"; tint: Theme.green; size: root.coverSize; corner: root.badgeRadius; plainText: "48 ms"; plainTint: Theme.muted; plainBold: false }
    }
  }

  Component {
    id: c_timer
    Row {
      spacing: Theme.gapMedium
      LiveGlyph { surface: chip.color; size: root.coverSize; corner: root.badgeRadius; name: "clock"; tint: Theme.orange }
      KitText { anchors.verticalCenter: parent.verticalCenter; visible: Theme.material; text: "Timer"; color: Theme.foreground1; font.weight: Font.Medium }
      LiveCap { surface: chip.color; text: "13:12"; tint: Theme.orange; size: root.coverSize; corner: root.badgeRadius }
    }
  }

  Component {
    id: c_radio
    Row {
      spacing: Theme.gapMedium
      LiveGlyph { surface: chip.color; size: root.coverSize; corner: root.badgeRadius; name: "radio"; tint: Theme.yellow }
      KitText { anchors.verticalCenter: parent.verticalCenter; text: "Station"; color: Theme.foreground1; font.weight: Theme.material ? Font.Medium : Font.Normal }
      LiveCap { surface: chip.color;
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
      LiveGlyph { surface: chip.color; size: root.coverSize; corner: root.badgeRadius; name: "moon"; tint: Theme.purple }
      KitText { anchors.verticalCenter: parent.verticalCenter; text: Theme.material ? "Focus on" : "Focus"; color: Theme.foreground1; font.weight: Theme.material ? Font.Medium : Font.Normal }
    }
  }

  Component {
    id: c_music
    Row {
      spacing: Theme.gapMedium
      // music: the cover, the parts Island › Live activities chooses, the sound
      Rectangle {
        visible: ShellSettings.liveMusicCover
        anchors.verticalCenter: parent.verticalCenter
        readonly property string liveEnd: "badge"
        width: root.coverSize; height: root.coverSize; radius: root.badgeRadius; color: Theme.separated(Theme.background3, chip.color, 1.2)
        KitIcon { anchors.centerIn: parent; name: "music"; size: Math.round(root.coverSize * 0.55); tint: Theme.foreground2 }
      }
      KitText {
        readonly property var parts: [ShellSettings.liveTrackTitle ? "Song" : "", ShellSettings.liveTrackArtist ? "Artist" : "", ShellSettings.liveTrackDuration ? "3:42" : ""].filter(t => t !== "")
        visible: parts.length > 0
        anchors.verticalCenter: parent.verticalCenter
        text: parts.join(" · ")
        color: Theme.foreground1
      }
      Wave { tone: Theme.green }
    }
  }

  Component {
    id: c_media
    Row {
      spacing: Theme.gapMedium
      // media: the cover, the parts Island › Live activities chooses, the sound
      Rectangle {
        visible: ShellSettings.liveMediaCover
        anchors.verticalCenter: parent.verticalCenter
        readonly property string liveEnd: "badge"
        width: root.coverSize; height: root.coverSize; radius: root.badgeRadius; color: Theme.separated(Theme.background3, chip.color, 1.2)
        KitIcon { anchors.centerIn: parent; name: "play"; size: Math.round(root.coverSize * 0.55); tint: Theme.foreground2 }
      }
      KitText {
        readonly property var parts: ["Video"].filter(t => t !== "")
        visible: parts.length > 0
        anchors.verticalCenter: parent.verticalCenter
        text: parts.join(" · ")
        color: Theme.foreground1
      }
      Wave { tone: Theme.foreground2 }
    }
  }

  Component {
    id: c_volume
    Row {
      spacing: Theme.gapMedium
      LiveGlyph { surface: chip.color; size: root.coverSize; corner: root.badgeRadius; name: "volume"; tint: Theme.foreground2 }
      Rectangle { visible: Theme.material; anchors.verticalCenter: parent.verticalCenter; width: 70; height: 6; radius: Theme.pill(height); color: Theme.background3
        Rectangle { width: parent.width * 0.62; height: parent.height; radius: parent.radius; color: Theme.foreground1 } }
      Row {
        visible: !Theme.material
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Repeater { model: 14; Rectangle { required property int index; width: 2; height: 14; radius: Theme.pill(height); color: index < 9 ? Theme.foreground1 : Theme.background3 } }
      }
      LiveCap { surface: chip.color; text: "62"; tint: Theme.foreground1; size: root.coverSize; corner: root.badgeRadius; plainBold: false }
    }
  }

  Component {
    id: c_mic
    Row {
      spacing: Theme.gapMedium
      LiveGlyph { surface: chip.color; size: root.coverSize; corner: root.badgeRadius; name: "mic-off"; tint: Theme.red }
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
      LiveGlyph { surface: chip.color; size: root.coverSize; corner: root.badgeRadius; name: "zap"; tint: Theme.green }
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 70; height: Theme.material ? 6 : 4; radius: Theme.pill(height); color: Theme.background3
        Rectangle { width: parent.width * 0.52; height: parent.height; radius: parent.radius; color: Theme.green } }
      KitText { anchors.verticalCenter: parent.verticalCenter; text: "52"; color: Theme.green }
    }
  }
}
