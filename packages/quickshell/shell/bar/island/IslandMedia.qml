import QtQuick
import qs.config
import qs.kit
import qs.modules.equalizer

// The player: cover, title and artist with the wave, a seek line with the
// times, and prev / play / next.
Item {
  id: root

  readonly property real fraction: IslandService.length > 0 ? Math.min(1, IslandService.position / IslandService.length) : 0

  function time(seconds) {
    const s = Math.max(0, Math.round(seconds));
    return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
  }

  IslandCover {
    id: cover
    x: 18
    y: 16
    size: 52
    radius: Theme.radiusCard
  }

  Column {
    anchors { left: cover.right; leftMargin: Theme.gapWide; right: wave.left; rightMargin: Theme.gapWide; verticalCenter: cover.verticalCenter }
    spacing: Theme.gapTight

    KitText {
      width: parent.width
      text: IslandService.title || "Nothing playing"
      textFormat: Text.PlainText
      font.weight: Font.Bold
      elide: Text.ElideRight
    }
    KitText {
      width: parent.width
      visible: text !== ""
      text: IslandService.artist
      textFormat: Text.PlainText
      color: Theme.muted
      elide: Text.ElideRight
    }
  }

  EqualizerBars {
    id: wave
    anchors { right: parent.right; rightMargin: 20; verticalCenter: cover.verticalCenter }
    height: 18
  }

  // ---- seek ----
  Item {
    id: seek
    anchors { left: parent.left; right: parent.right; leftMargin: 18; rightMargin: 18; top: cover.bottom; topMargin: Theme.gapWide }
    height: elapsed.implicitHeight
    visible: !IslandService.radio

    KitText {
      id: elapsed
      text: root.time(IslandService.position)
      color: Theme.muted
      font.pixelSize: Theme.fontSize - 2
    }

    Item {
      id: track
      anchors { left: elapsed.right; right: remain.left; leftMargin: Theme.gapMedium; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
      height: 12

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: Theme.pill(height)
        color: Theme.background2

        Rectangle {
          width: parent.width * (drag.pressed ? drag.at : root.fraction)
          height: parent.height
          radius: Theme.pill(height)
          color: Theme.foreground0
        }
      }

      Rectangle {
        anchors.fill: parent
        radius: Theme.pill(height)
        color: "transparent"
        border.width: drag.activeFocus ? Theme.focusRingWidth : 0
        border.color: Theme.focusRing
      }

      MouseArea {
        id: drag
        property real at: 0
        anchors.fill: parent
        enabled: IslandService.length > 0
        activeFocusOnTab: enabled
        Accessible.role: Accessible.Slider
        Accessible.name: "Seek playback"
        Accessible.description: root.time(IslandService.position) + " of " + root.time(IslandService.length)
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => { forceActiveFocus(); at = Math.max(0, Math.min(1, mouse.x / width)); }
        onPositionChanged: mouse => at = Math.max(0, Math.min(1, mouse.x / width))
        onReleased: IslandService.seek(at)
        Keys.onLeftPressed: event => {
          IslandService.seek(Math.max(0, IslandService.position - 5) / IslandService.length)
          event.accepted = true
        }
        Keys.onRightPressed: event => {
          IslandService.seek(Math.min(IslandService.length, IslandService.position + 5) / IslandService.length)
          event.accepted = true
        }
        Keys.onUpPressed: event => {
          IslandService.seek(Math.min(IslandService.length, IslandService.position + 5) / IslandService.length)
          event.accepted = true
        }
        Keys.onDownPressed: event => {
          IslandService.seek(Math.max(0, IslandService.position - 5) / IslandService.length)
          event.accepted = true
        }
        Keys.onPressed: event => {
          if (event.key === Qt.Key_Home) IslandService.seek(0)
          else if (event.key === Qt.Key_End) IslandService.seek(1)
          else return
          event.accepted = true
        }
      }
    }

    KitText {
      id: remain
      anchors.right: parent.right
      text: IslandService.length > 0 ? "-" + root.time(IslandService.length - IslandService.position) : "--"
      color: Theme.muted
      font.pixelSize: Theme.fontSize - 2
    }
  }

  // ---- controls ----
  Row {
    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 10 }
    spacing: Theme.gapGroup

    IslandButton { icon: "skip-back"; onClicked: IslandService.prev() }
    IslandButton {
      icon: IslandService.playing ? "pause" : "play"
      iconSize: 24
      onClicked: IslandService.togglePlay()
    }
    IslandButton { icon: "skip-forward"; onClicked: IslandService.next() }
  }
}
