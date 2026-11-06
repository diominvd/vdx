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

  // the parts Island › Live activities › Music (Media) chooses, joined by " · "
  readonly property string line: {
    if (!player.hasMedia) return "Nothing playing";
    const parts = [];
    if (ShellSettings.liveTrackTitle && player.title !== "") parts.push(player.title);
    if (ShellSettings.liveTrackArtist && player.artist !== "") parts.push(player.artist);
    if (ShellSettings.liveTrackDuration && player.length > 0) {
      const s = Math.floor(player.length);
      parts.push(Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"));
    }
    return parts.join(" · ");
  }

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
    visible: face.track && face.line !== ""
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, 260)
    elide: Text.ElideRight
    text: face.line
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
