import QtQuick
import qs.config
import qs.kit
import qs.modules.mpd
import qs.modules.radio
import qs.modules.yandex

// A list of the Music app as a table in one raised box, as Files' list: captions, then
// a row per entry with a hairline between. `kind`: "yandex" (tracks: #, title and
// artist, album, time, like, ⋮), "queue" (MPD's queue: the playing one lit, ⋮),
// "files" (a folder entry `dir: true` with a folder icon, no ⋮; a track: #, title and
// artist, ⋮) or "radio" (stations: #, name and about, genre). The playing row is filled and bold; a Yandex track
// the update has not downloaded yet is dimmed. `activated(entry)` plays (a folder
// opens), `menu(entry, index, anchor)` opens its ⋮ menu. Empty: `empty` in muted text
// instead of the box.
Item {
  id: root

  property string kind: "yandex"
  property var tracks: []
  property string empty: ""

  readonly property int rowH: 44
  readonly property bool yandex: kind === "yandex"
  readonly property bool album: (yandex || kind === "radio") && width > 620
  readonly property int albumW: Math.round(width * 0.28)
  readonly property int numW: 40
  readonly property int timeW: 52
  readonly property int dirCount: kind === "files" ? tracks.filter(t => t.dir === true).length : 0
  readonly property int iconW: 28
  // what plays now, as a row's key: a Yandex id, a queue place or a station key
  readonly property var playing: kind === "queue" ? (MpdService.stopped ? -1 : MpdService.player.pos)
                               : kind === "radio" ? (RadioService.active ? RadioService.stationKey : "")
                               : kind === "files" ? (MpdService.source === "files" && !MpdService.stopped
                                                     ? MpdService.file.replace(/^file:\/\//, "") : "")
                               : (MpdService.source === "likes" && !MpdService.stopped ? YandexService.trackId : "")

  signal activated(var entry)
  signal menu(var entry, int index, var anchor)

  function keyOf(e) { return kind === "queue" ? e.pos : kind === "radio" ? e.key : kind === "files" ? e.path : e.id; }

  function clock(seconds) {
    const s = Math.max(0, Math.floor(seconds));
    return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
  }

  // the queue keeps the playing track in view
  function follow() {
    if (kind !== "queue" || list.moving) return;
    const i = tracks.findIndex(t => t.pos === playing);
    if (i >= 0) list.positionViewAtIndex(i, ListView.Center);
  }
  onPlayingChanged: Qt.callLater(follow)
  onTracksChanged: Qt.callLater(follow)

  KitText {
    visible: root.tracks.length === 0 && root.empty !== ""
    width: parent.width
    text: root.empty
    color: Theme.muted
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSize - 1
  }

  Rectangle {
    id: box
    visible: root.tracks.length > 0
    anchors.fill: parent
    radius: Theme.radiusCard
    color: Theme.background1

    // ---- captions ----
    Item {
      id: captions
      width: parent.width
      height: 32

      Repeater {
        model: [
          { text: "#", x: 0, w: root.numW, right: true, on: true },
          { text: root.kind === "radio" ? "STATION" : "TITLE", x: root.numW + Theme.gapWide, w: 0, on: true },
          { text: root.kind === "radio" ? "GENRE" : "ALBUM", x: root.width - root.albumW - root.timeW - 2 * root.iconW - Theme.gapWide * 2, w: 0, on: root.album },
          { text: "TIME", x: root.width - root.timeW - 2 * root.iconW - Theme.gapWide, w: root.timeW, right: true, on: root.yandex }
        ]

        KitText {
          required property var modelData
          visible: modelData.on
          x: modelData.right ? modelData.x + modelData.w - width : modelData.x
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.text
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 2
          font.letterSpacing: 1
          font.weight: Font.DemiBold
        }
      }

      KitLine { anchors.bottom: parent.bottom; x: Theme.gapWide; width: parent.width - 2 * Theme.gapWide; sectionBreak: false;  }
    }

    ListView {
      id: list
      anchors { left: parent.left; right: parent.right; top: captions.bottom; bottom: parent.bottom
                topMargin: Theme.gapHair; bottomMargin: Theme.gapHair }
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: root.tracks
      reuseItems: true

      delegate: Item {
        id: row

        required property var modelData
        required property int index

        readonly property var key: root.keyOf(modelData)
        readonly property bool current: key === root.playing
        readonly property bool playable: !root.yandex || YandexLibrary.playable(modelData.id)
        readonly property bool liked: root.yandex && YandexService.liked.includes(modelData.id)
        readonly property bool favorite: root.kind === "radio" && RadioService.isFavorite(modelData.key)
        readonly property bool hovered: area.containsMouse || likeArea.containsMouse || moreArea.containsMouse
                                        || starArea.containsMouse
        readonly property bool hasMenu: root.kind !== "radio" && !modelData.dir

        width: list.width
        height: root.rowH

        // the row's fill, inset in the box
        Rectangle {
          anchors { fill: parent; leftMargin: Theme.gapHair; rightMargin: Theme.gapHair }
          radius: Theme.radiusControl
          color: row.current ? Theme.background3 : row.hovered ? Theme.background2 : Theme.clear
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
        }

        // the hairline between rows
        KitLine {
          visible: row.index > 0 && !row.current
          x: Theme.gapWide
          width: parent.width - 2 * Theme.gapWide
          sectionBreak: false

        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: row.playable ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: mouse => {
            if (mouse.button === Qt.RightButton) { if (row.hasMenu) root.menu(row.modelData, row.index, more); }
            else if (row.playable) root.activated(row.modelData);
          }
        }

        // the place, or a note playing in the playing row
        Item {
          x: 0
          width: root.numW
          height: parent.height

          KitText {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: !row.current && !row.modelData.dir
            text: root.kind === "queue" ? row.modelData.pos : row.index + 1 - root.dirCount
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 2
          }

          KitIcon {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: row.modelData.dir === true
            name: "folder"
            size: Theme.iconSmall
            tint: Theme.gray
          }

          KitIcon {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: row.current
            name: MpdService.playing ? "volume" : "pause"
            size: Theme.iconSmall
            tint: Theme.foreground0
          }
        }

        // ---- title, artist ----
        Column {
          anchors {
            left: parent.left; leftMargin: root.numW + Theme.gapWide
            right: parent.right
            rightMargin: root.width - (root.album ? albumText.x : root.yandex ? timeText.x
                                       : root.kind === "radio" ? starButton.x
                                       : root.kind === "queue" || root.kind === "files" ? moreButton.x : root.width) + Theme.gapWide
            verticalCenter: parent.verticalCenter
          }
          spacing: Theme.gapHair

          KitText {
            width: parent.width
            text: root.kind === "radio" ? row.modelData.name : row.modelData.title
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: row.playable ? Theme.foreground0 : Theme.muted
            font.weight: row.current ? Font.ExtraBold : Font.DemiBold
          }

          KitText {
            width: parent.width
            visible: text !== ""
            text: root.kind === "radio" ? row.modelData.about ?? ""
              : row.modelData.dir === true ? "Folder"
              : [row.modelData.artist, row.playable ? "" : "not downloaded yet"].filter(s => s).join(" · ")
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 2
          }
        }

        KitText {
          id: albumText
          visible: root.album
          x: root.width - root.albumW - root.timeW - 2 * root.iconW - Theme.gapWide * 2
          width: root.albumW
          anchors.verticalCenter: parent.verticalCenter
          text: (root.kind === "radio" ? row.modelData.genre : row.modelData.album) ?? ""
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 1
        }

        KitText {
          id: timeText
          visible: root.yandex
          x: root.width - root.timeW - 2 * root.iconW - Theme.gapWide
          width: root.timeW
          anchors.verticalCenter: parent.verticalCenter
          horizontalAlignment: Text.AlignRight
          text: root.clock(row.modelData.duration ?? 0)
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 2
        }

        // ---- the like: shown on a liked row, or while the pointer is on the row ----
        Rectangle {
          id: likeButton
          visible: root.yandex
          x: root.width - 2 * root.iconW - Theme.gapSmall
          anchors.verticalCenter: parent.verticalCenter
          width: root.iconW
          height: root.iconW
          radius: Theme.radiusFor(height)
          color: likeArea.containsMouse ? Theme.hoverOn(true) : Theme.clear
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

          KitIcon {
            anchors.centerIn: parent
            visible: row.liked || row.hovered
            name: row.liked ? "heart-filled" : "heart"
            size: Theme.iconSmall
            tint: row.liked ? Theme.red : Theme.foreground2
          }

          MouseArea {
            id: likeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: YandexService.toggleLike(row.modelData.id)
          }
        }

        // ---- the favourite station: a star in the like's column ----
        Rectangle {
          id: starButton
          visible: root.kind === "radio"
          x: root.width - 2 * root.iconW - Theme.gapSmall
          anchors.verticalCenter: parent.verticalCenter
          width: root.iconW
          height: root.iconW
          radius: Theme.radiusFor(height)
          color: starArea.containsMouse ? Theme.hoverOn(true) : Theme.clear
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

          KitIcon {
            anchors.centerIn: parent
            visible: row.favorite || row.hovered
            name: "star"
            solid: row.favorite
            size: Theme.iconSmall
            tint: row.favorite ? Theme.yellow : Theme.foreground2
          }

          MouseArea {
            id: starArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: RadioService.setFavorite(row.modelData.key, !row.favorite)
          }
        }

        // ---- ⋮ ----
        Rectangle {
          id: moreButton
          visible: row.hasMenu
          x: root.width - root.iconW - Theme.gapSmall
          anchors.verticalCenter: parent.verticalCenter
          width: root.iconW
          height: root.iconW
          radius: Theme.radiusFor(height)
          color: moreArea.containsMouse ? Theme.hoverOn(true) : Theme.clear
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

          Item { id: more; anchors.fill: parent }

          KitIcon {
            anchors.centerIn: parent
            name: "more"
            size: Theme.iconSmall
            tint: row.hovered ? Theme.foreground0 : Theme.gray
          }

          MouseArea {
            id: moreArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.menu(row.modelData, row.index, more)
          }
        }
      }
    }
  }
}
