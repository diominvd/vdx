import QtQuick
import Quickshell.Widgets
import qs.config
import qs.kit
import qs.modules.player

// The track that plays, on the locked screen: the cover, the title and artist and the
// transport. While a player has a track, paused too (PlayerService.view); no timeline, so nothing
// ticks on a locked screen. `released` after a click: the password field takes the keys back.
Rectangle {
  id: root

  readonly property var player: PlayerService.view
  readonly property int coverSize: 44
  signal released()

  visible: player.hasMedia
  implicitWidth: 360
  implicitHeight: coverSize + 2 * Theme.gapWide
  radius: Theme.coverRadius(coverSize) + Theme.gapWide
  color: Theme.background1
  border.width: Theme.frameWidth
  border.color: Theme.background3

  ClippingRectangle {
    id: cover
    anchors { left: parent.left; leftMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
    width: root.coverSize; height: width
    radius: Theme.coverRadius(root.coverSize)
    color: Theme.background2

    Image {
      anchors.fill: parent
      source: root.visible ? root.player.cover : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      sourceSize { width: root.coverSize * 2; height: root.coverSize * 2 }
    }

    KitIcon {
      anchors.centerIn: parent
      visible: root.player.cover === ""
      name: "music"
      tint: Theme.gray
    }
  }

  Column {
    anchors {
      left: cover.right; leftMargin: Theme.gapWide
      right: controls.left; rightMargin: Theme.gapMedium
      verticalCenter: parent.verticalCenter
    }
    spacing: Theme.gapHair

    KitText {
      width: parent.width
      text: root.player.title || "—"
      textFormat: Text.PlainText
      elide: Text.ElideRight
      font.weight: Font.ExtraBold
    }

    KitText {
      width: parent.width
      text: root.player.artist || "—"
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: Theme.foreground2
      font.pixelSize: Theme.fontSize - 1
    }
  }

  Row {
    id: controls
    anchors { right: parent.right; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
    spacing: Theme.gapTight

    KitButton { icon: "skip-back"; disabled: !root.player.canPrevious; onClicked: { root.player.prev(); root.released(); } }
    KitButton { icon: root.player.playing ? "pause" : "play"; selected: true; onClicked: { root.player.togglePlay(); root.released(); } }
    KitButton { icon: "skip-forward"; disabled: !root.player.canNext; onClicked: { root.player.next(); root.released(); } }
  }
}
