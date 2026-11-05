import QtQuick
import Quickshell.Widgets
import qs.config
import qs.kit
import qs.modules.player

Row {
  id: face

  property string kind: ""
  readonly property bool track: kind === "music" || kind === "media"
  property bool showCover: true
  readonly property var player: kind === "media" ? PlayerService.media : PlayerService.music
  property int coverSize: 18
  property int badgeRadius: 4
  spacing: Theme.gapMedium
  visible: kind !== ""

  // music and media: the cover, the track and the sound
  ClippingRectangle {
    visible: face.track && face.showCover
    anchors.verticalCenter: parent.verticalCenter
    width: face.coverSize
    height: face.coverSize
    radius: face.badgeRadius
    color: Theme.background3
    readonly property string liveEnd: "badge"      // IslandLiveFace.padFor

    Image {
      anchors.fill: parent
      source: face.player.cover
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
    }
  }
  KitText {
    visible: face.track
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, 260)
    elide: Text.ElideRight
    text: !face.player.hasMedia ? "Nothing playing" : face.player.title + (face.player.artist !== "" ? " · " + face.player.artist : "")
    color: Theme.foreground1
  }
  LiveBars {
    visible: face.track
    anchors.verticalCenter: parent.verticalCenter
    barCount: 4
    tone: face.kind === "media" ? Theme.foreground2 : Theme.green
    height: 16
    active: face.player.playing      // its own player: the radio or another app playing does not move it
    flatWhenIdle: true
  }
}
