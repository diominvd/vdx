import QtQuick
import qs.config
import qs.kit
import qs.modules.mpd

// Radio: a dial of the stations, the one on air and what it plays. Tune by
// dragging the dial; the button pauses or starts it.
KitFrame {
  id: root

  readonly property var stations: RadioService.stations
  readonly property string key: RadioService.resumeKey
  readonly property int index: Math.max(0, stations.findIndex(s => s.key === key))
  readonly property var station: stations[index] ?? null
  readonly property color tone: Theme.yellow
  readonly property bool onAir: RadioService.active

  signal closeRequested()                      // Modules › Radio › Close after stop

  implicitWidth: 340

  // ---- header ----
  KitHeader {
    icon: "radio"
    iconColor: root.onAir ? root.tone : Theme.foreground0
    title: root.station?.name ?? "Radio"
    subtitle: !root.onAir ? "OFF" : (MpdService.playing ? "ON AIR" : "PAUSED") + (root.station?.genre ? " · " + root.station.genre.toUpperCase() : "")

    KitText {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.stations.length > 0
      text: String(Math.round(dial.tuning) + 1).padStart(2, "0")
      color: root.onAir ? root.tone : Theme.muted
      font.pixelSize: Theme.fontSize + 12
    }
  }

  KitLine {}

  KitText {
    visible: root.stations.length === 0
    width: parent.width
    text: "No stations"
    color: Theme.muted
  }

  RadioDial {
    id: dial
    visible: root.stations.length > 0
    width: parent.width
    count: root.stations.length
    current: root.index
    tint: root.tone
    onTuned: index => RadioService.play(root.stations[index].key)
  }

  // ---- what plays ----
  Row {
    visible: root.stations.length > 0
    width: parent.width
    spacing: Theme.gapMedium

    KitText {
      id: track
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - button.width - (root.onAir ? button.width + parent.spacing : 0) - parent.spacing
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: !root.onAir ? (root.station?.about ?? "") : (MpdService.player.title || root.station?.about || "")
      color: Theme.muted
    }
    KitButton {
      visible: root.onAir
      icon: "square"
      onClicked: {
        MpdService.stop();
        if (ModuleSettings.get("tuner", "closeAfterStop", false)) root.closeRequested();
      }
    }
    KitButton {
      id: button
      icon: root.onAir && MpdService.playing ? "pause" : "play"
      iconTint: root.tone
      onClicked: root.onAir ? MpdService.toggle() : RadioService.setActive(true)
    }
  }

  // ---- the stations ----
  // Modules › Radio › Show the stations
  readonly property bool listShown: ModuleSettings.get("tuner", "showList", true)

  KitLine { visible: root.stations.length > 0 && root.listShown }

  Column {
    visible: root.stations.length > 0 && root.listShown
    width: parent.width
    spacing: Theme.gapMedium

    KitLabel { text: "STATIONS (" + root.stations.length + ")"; value: root.onAir ? "ON AIR" : "" ; valueColor: root.tone }

    Flickable {
      id: listView
      width: parent.width
      height: Math.min(contentHeight, 30 * 5)
      contentHeight: list.implicitHeight
      interactive: contentHeight > height
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      // the picked one stays in view
      function reveal(i) {
        const top = i * 30;
        if (top < contentY) contentY = top;
        else if (top + 30 > contentY + height) contentY = top + 30 - height;
      }
      Connections { target: dial; function onCurrentChanged() { listView.reveal(dial.current); } }

      Column {
        id: list
        width: parent.width

        Repeater {
          model: root.stations

          Rectangle {
            id: station
            required property var modelData
            required property int index

            readonly property bool picked: index === root.index
            readonly property bool playing: picked && root.onAir && MpdService.playing

            width: list.width
            height: 30
            radius: Theme.radiusControl
            color: picked ? Theme.selectedFill : area.containsMouse ? Theme.background1 : Theme.clear
            Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

            KitText {
              id: number
              anchors { left: parent.left; leftMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
              width: 22
              text: String(station.index + 1).padStart(2, "0")
              color: station.picked ? root.tone : Theme.muted
              font.pixelSize: Theme.fontSize - 2
            }
            KitText {
              anchors { left: number.right; leftMargin: Theme.gapSmall; right: genre.left; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
              text: station.modelData.name
              elide: Text.ElideRight
              color: station.picked ? Theme.selectedText : area.containsMouse ? Theme.foreground0 : Theme.foreground2
              font.weight: station.picked ? Font.ExtraBold : Font.DemiBold
            }
            KitText {
              id: genre
              anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
              text: station.modelData.genre ?? ""
              color: Theme.muted
              font.pixelSize: Theme.fontSize - 2
            }
            MouseArea {
              id: area
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: dial.settle(station.index)       // the dial glides there, then the station switches
            }
          }
        }
      }
    }
  }
}
