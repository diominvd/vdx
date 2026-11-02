import QtQuick
import QtQuick.Effects
import qs.config
import qs.kit
import qs.modules.equalizer
import qs.modules.mpd
import qs.modules.player
import qs.modules.radio

Row {
  id: face

  property string kind: ""
  readonly property bool track: kind === "music" || kind === "media"
  readonly property var player: kind === "media" ? PlayerService.media : PlayerService.music
  property int coverSize: 18
  property int badgeRadius: 4
  spacing: 8
  visible: kind !== ""

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
