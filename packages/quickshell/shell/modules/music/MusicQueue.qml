import QtQuick
import qs.config
import qs.modules.mpd
import qs.modules.player
import qs.kit

// The music's queue (PlayerService.musicQueue: MPD's; never a station's or another app's): two
// lines per track, nine rows visible, then it scrolls. It scrolls itself so the current track sits
// on top. A click plays a track, a right click takes it out; the search field above swaps the list for matches while it has text. How many rows show is Music › Queue rows.
Column {
  id: root

  property string query: ""
  readonly property bool searching: query.trim() !== ""

  readonly property int rowHeight: 38
  readonly property int upNext: ModuleSettings.get("music", "queueRows", 9)
  readonly property int currentPos: MpdService.player.pos ?? 0
  // the Queue tab is the music's: a station's or another app's queue is not shown here
  readonly property string notice: PlayerService.music.hasMedia ? "" : "Nothing is queued"
  readonly property var tracks: {
    const queue = PlayerService.musicQueue;
    if (!searching) return queue;
    const q = query.trim().toLowerCase();
    return q === "" ? [] : queue.filter(t => (t.artist + " " + t.title).toLowerCase().includes(q));
  }

  function scrollToCurrent() {
    if (searching || list.moving) return;
    const index = tracks.findIndex(t => t.pos === currentPos);
    list.contentY = Math.max(0, Math.min(index * rowHeight, list.contentHeight - list.height));
  }

  onTracksChanged: Qt.callLater(scrollToCurrent)
  onCurrentPosChanged: Qt.callLater(scrollToCurrent)
  onSearchingChanged: if (!searching) Qt.callLater(scrollToCurrent)

  spacing: Theme.gapMedium

  KitText {
    visible: root.notice !== ""
    width: parent.width
    text: root.notice
    color: Theme.muted
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSize - 1
  }

  KitInput {
    id: search
    visible: root.notice === ""
    icon: "search"
    placeholder: "Search the queue"
    text: root.query
    onTextEdited: root.query = text
  }

  Flickable {
    id: list
    visible: root.notice === ""
    width: parent.width
    height: Math.min(contentHeight, root.upNext * root.rowHeight)
    contentHeight: rows.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: rows
      width: parent.width

      Repeater {
        model: root.tracks

        Rectangle {
          radius: Theme.radiusControl
          id: row

          required property var modelData

          readonly property bool current: modelData.pos === root.currentPos

          width: rows.width
          height: root.rowHeight
          color: current ? Theme.background3 : hover.hovered ? Theme.background1 : Theme.clear
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

          HoverHandler { id: hover }

          KitText {
            id: number
            anchors { left: parent.left; leftMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
            width: 32
            text: row.modelData.pos
            color: row.current ? Theme.foreground0 : Theme.muted
            Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
            font.pixelSize: Theme.fontSize - 2
          }

          Column {
            anchors {
              left: number.right; leftMargin: 4
              right: parent.right; rightMargin: Theme.gapLoose
              verticalCenter: parent.verticalCenter
            }
            spacing: 1

            KitText {
              width: parent.width
              text: row.modelData.title
              elide: Text.ElideRight
              color: row.current || hover.hovered ? Theme.foreground0 : Theme.foreground2
              Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
              font.weight: row.current ? Font.ExtraBold : Font.DemiBold
              font.pixelSize: Theme.fontSize - 1
            }

            KitText {
              width: parent.width
              text: row.modelData.artist
              elide: Text.ElideRight
              color: Theme.muted
              font.pixelSize: Theme.fontSize - 2
            }
          }

          // click plays it; right click takes it out of the queue
          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
              if (mouse.button === Qt.RightButton) MpdService.control(["--queue-del", String(row.modelData.pos)]);
              else {
                MpdService.play(row.modelData.pos);
                root.query = "";
              }
            }
          }
        }
      }
    }
  }

  KitText {
    visible: root.notice === "" && root.tracks.length === 0
    text: root.searching ? "Nothing matches" : "The queue is empty."
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 1
  }
}
