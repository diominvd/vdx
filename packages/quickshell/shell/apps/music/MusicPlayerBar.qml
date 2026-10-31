import QtQuick
import Quickshell.Widgets
import qs.config
import qs.kit
import qs.modules.mpd
import qs.modules.player
import qs.modules.yandex

// The player at the foot of the Music window, in one raised box: the cover and the
// track on the left, the transport over the timeline in
// the middle, the like and the player's own window on the right. It drives the
// current player of PlayerService: MPD (Yandex likes, radio) or any MPRIS one.
Rectangle {
  id: root

  property bool yandexOn: false

  // a Yandex track plays: its like shows
  readonly property bool yandexTrack: yandexOn && PlayerService.mpd && MpdService.source === "likes"
                                      && YandexService.trackId !== ""
  readonly property bool showRemaining: ModuleSettings.get("music", "showRemaining", false)
  readonly property real at: timeline.pressed ? timeline.dragValue * PlayerService.length : PlayerService.position

  function clock(seconds) {
    const s = Math.max(0, Math.floor(seconds));
    return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
  }

  implicitHeight: 48 + 2 * Theme.gapWide
  radius: Theme.radiusCard
  color: Theme.background1

  // ---- the track ----
  Item {
    id: track
    anchors { left: parent.left; leftMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
    width: Math.round(root.width * 0.28)
    height: 48

    ClippingRectangle {
      id: cover
      width: 48
      height: 48
      radius: Theme.coverRadius(48)
      color: Theme.background2

      Image {
        anchors.fill: parent
        source: PlayerService.cover
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize { width: 96; height: 96 }
      }

      KitIcon {
        anchors.centerIn: parent
        visible: PlayerService.cover === ""
        name: PlayerService.radio ? "radio" : "music"
        tint: Theme.gray
        size: Theme.iconSmall + 4
      }
    }

    Column {
      anchors { left: cover.right; leftMargin: Theme.gapWide; right: parent.right; verticalCenter: parent.verticalCenter }
      spacing: Theme.gapHair

      KitText {
        width: parent.width
        text: PlayerService.title || "—"
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.weight: Font.ExtraBold
      }

      KitText {
        width: parent.width
        text: [PlayerService.artist, PlayerService.name].filter(s => s).join(" · ")
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 2
      }
    }
  }

  // ---- transport and timeline ----
  Column {
    id: middle
    anchors { left: track.right; leftMargin: Theme.gapGroup; right: side.left; rightMargin: Theme.gapGroup
              verticalCenter: parent.verticalCenter }
    spacing: Theme.gapHair

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Theme.gapSmall

      KitButton {
        visible: PlayerService.canShuffle
        icon: "shuffle"
        selected: PlayerService.shuffleOn
        iconTint: PlayerService.shuffleOn ? Theme.foreground0 : Theme.gray
        onClicked: PlayerService.toggleShuffle()
      }
      KitButton { icon: "skip-back"; disabled: !PlayerService.canPrevious; onClicked: PlayerService.prev() }
      KitButton {
        width: 44
        icon: PlayerService.playing ? "pause" : "play"
        selected: true
        onClicked: PlayerService.togglePlay()
      }
      KitButton { icon: "skip-forward"; disabled: !PlayerService.canNext; onClicked: PlayerService.next() }
      KitButton {
        visible: PlayerService.canLoop
        icon: PlayerService.loop === "one" ? "repeat-1" : "repeat"
        selected: PlayerService.loop !== "off"
        iconTint: PlayerService.loop !== "off" ? Theme.foreground0 : Theme.gray
        onClicked: PlayerService.cycleLoop()
      }
    }

    Item {
      width: parent.width
      height: Math.max(elapsed.implicitHeight, timeline.height)
      visible: PlayerService.length > 0

      KitText {
        id: elapsed
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: 40
        text: root.clock(root.at)
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 2
      }

      KitSlider {
        id: timeline
        line: true
        anchors { left: elapsed.right; right: total.left; leftMargin: Theme.gapMedium; rightMargin: Theme.gapMedium
                  verticalCenter: parent.verticalCenter }
        enabled: PlayerService.canSeek
        value: PlayerService.length > 0 ? PlayerService.position / PlayerService.length : 0
        onReleased: value => PlayerService.seek(value)
      }

      KitText {
        id: total
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 40
        horizontalAlignment: Text.AlignRight
        text: root.showRemaining ? "-" + root.clock(PlayerService.length - root.at) : root.clock(PlayerService.length)
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 2
      }
    }
  }

  // ---- the like, the player's window ----
  Row {
    id: side
    anchors { right: parent.right; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
    spacing: Theme.gapSmall

    KitButton {
      visible: root.yandexTrack
      icon: YandexService.isLiked ? "heart-filled" : "heart"
      iconTint: YandexService.isLiked ? Theme.red : Theme.foreground0
      onClicked: YandexService.toggleLike()
    }

    KitButton {
      visible: PlayerService.canRaise
      icon: "external"
      onClicked: PlayerService.raise()
    }
  }
}
