import QtQuick
import Quickshell.Widgets
import qs.bar
import qs.config
import qs.kit
import qs.modules.mpd
import qs.modules.player
import qs.modules.yandex

// The track that plays in one player (`player`, a PlayerView: the music of MPD, or the
// media of other apps): the cover, the title, artist and album, the like (a Yandex
// track only), the timeline and the transport. Nothing playing: an empty player.
Column {
  id: root

  property var player: PlayerService.music
  // nothing playing: an empty player, or (`emptyPlayer` off) a line saying so
  property bool emptyPlayer: true
  signal pickRequested()
  signal closeRequested()                      // Modules › Music › Close after stop
  property string emptyText: ""

  readonly property int coverSize: YandexService.coverSize
  readonly property int gap: Theme.gapWide
  // the slider is 18 high, its line 3 in the middle: the empty strip above the line
  readonly property int lineInset: 7
  // the timeline's right end: the total, or the time left (Modules › Music)
  readonly property bool showRemaining: ModuleSettings.get("music", "showRemaining", false)
  // the like belongs to a Yandex track only
  readonly property bool yandexTrack: root.player.mpd && MpdService.source === "likes" && YandexService.trackId !== ""
  readonly property string detail: root.player.detail

  function clock(seconds) {
    const s = Math.max(0, Math.floor(seconds));
    return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
  }

  width: parent ? parent.width : 0
  spacing: gap


  KitText {
    visible: !root.player.hasMedia && !root.emptyPlayer
    width: parent.width
    wrapMode: Text.WordWrap
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 1
    text: root.emptyText
  }

  Item {
    id: now
    visible: root.player.hasMedia || root.emptyPlayer
    width: parent.width
    // the row of the cover and the text, the timeline, the transport
    height: Math.max(root.coverSize, info.height) + Theme.sectionGap - root.lineInset + timeline.height + root.gap + transport.height

    // ---- cover ----
    ClippingRectangle {
      id: cover
      x: 0
      y: 0
      radius: Theme.coverRadius(root.coverSize)
      width: root.coverSize
      height: width
      color: Theme.background1
      border.width: Theme.frameWidth
      border.color: Theme.background3

      Image {
        anchors { fill: parent; margins: 1 }
        source: root.player.cover
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize { width: root.coverSize * 2; height: root.coverSize * 2 }
      }

      KitIcon {
        anchors.centerIn: parent
        visible: root.player.cover === ""
        name: "music"
        tint: Theme.gray
        size: Theme.iconLarge
      }
    }

    // ---- title, artist, album, and the like / raise ----
    Item {
      id: info

      x: cover.width + root.gap
      y: 0
      width: now.width - x
      height: Math.max(root.coverSize, textColumn.implicitHeight, like.height)

      Column {
        id: textColumn
        anchors {
          left: parent.left
          right: raise.left; rightMargin: Theme.gapMedium
          verticalCenter: parent.verticalCenter
        }
        spacing: Theme.gapHair

        KitText {
          width: parent.width
          text: root.player.title || "—"
          textFormat: Text.PlainText
          elide: Text.ElideRight
          font.weight: Font.ExtraBold
          font.pixelSize: root.coverSize > 64 ? Theme.fontSize + 2 : Theme.fontSize
        }

        KitText {
          width: parent.width
          text: root.player.artist || "—"
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Theme.foreground2
          font.pixelSize: Theme.fontSize - 1
        }

        KitText {
          width: parent.width
          visible: text !== ""
          text: root.detail
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 2
        }
      }

      KitButton {
        id: raise
        anchors { right: like.left; rightMargin: Theme.gapTight; verticalCenter: parent.verticalCenter }
        visible: root.player.canRaise
        icon: "external"
        onClicked: root.player.raise()
      }

      KitButton {
        id: like
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        visible: root.yandexTrack
        icon: YandexService.isLiked ? "heart-filled" : "heart"
        iconTint: YandexService.isLiked ? Theme.red : Theme.foreground0
        onClicked: YandexService.toggleLike()
      }
    }

    // ---- timeline ----
    Column {
      id: timeline

      y: Math.max(root.coverSize, info.height) + Theme.sectionGap - root.lineInset   // as far from the cover as the separator above it
      width: parent.width
      spacing: Theme.gapTight

      KitSlider {
        id: slider
        line: true
        width: parent.width
        enabled: root.player.canSeek
        value: root.player.length > 0 ? root.player.position / root.player.length : 0
        onReleased: value => root.player.seek(value)
      }

      Item {
        width: parent.width
        height: elapsed.implicitHeight

        KitText {
          id: elapsed
          text: root.clock(slider.pressed ? slider.dragValue * root.player.length : root.player.position)
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 2
        }

        KitText {
          anchors.right: parent.right
          visible: root.player.length > 0
          text: root.showRemaining
            ? "-" + root.clock(root.player.length - (slider.pressed ? slider.dragValue * root.player.length : root.player.position))
            : root.clock(root.player.length)
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 2
        }
      }
    }

    // ---- transport ----
    Item {
      id: transport

      x: timeline.x
      y: timeline.y + timeline.height + root.gap
      width: timeline.width
      height: 30

      KitButton {
        anchors.left: parent.left
        visible: root.player.canShuffle
        icon: "shuffle"
        selected: root.player.shuffleOn
        iconTint: root.player.shuffleOn ? Theme.foreground0 : Theme.gray
        onClicked: root.player.toggleShuffle()
      }

      Row {
        anchors.centerIn: parent
        spacing: Theme.gapMedium

        KitButton { icon: "skip-back"; disabled: !root.player.canPrevious; onClicked: root.player.prev() }

        KitButton {
          width: 52
          icon: root.player.playing ? "pause" : "play"
          selected: true
          // the player's own (the music a station put aside comes back); nothing at all: the likes
          // start (never what MPD kept — that may be the radio — nor another app's sound); without
          // Yandex Music the Library opens to pick from
          onClicked: {
            if (root.player.hasMedia) root.player.togglePlay();
            else if (BarLayout.installed("yandex")) YandexService.setActive(true);
            else root.pickRequested();
          }
        }

        KitButton { icon: "skip-forward"; disabled: !root.player.canNext; onClicked: root.player.next() }

        // MPD only: stops the music and closes the player; MPD itself keeps running
        KitButton {
          visible: root.player.mpd
          icon: "square"
          onClicked: {
            MpdService.stop();
            if (ModuleSettings.get("music", "closeAfterStop", false)) root.closeRequested();
          }
        }
      }

      KitButton {
        anchors.right: parent.right
        visible: root.player.canLoop
        icon: root.player.loop === "one" ? "repeat-1" : "repeat"
        selected: root.player.loop !== "off"
        iconTint: root.player.loop !== "off" ? Theme.foreground0 : Theme.gray
        onClicked: root.player.cycleLoop()
      }
    }
  }
}
