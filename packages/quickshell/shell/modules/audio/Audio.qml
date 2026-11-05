import QtQuick
import Quickshell
import qs.bar
import qs.config
import qs.kit

// Bar module: output volume ("--" while muted); wheel changes it.
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  KitBarItem {
    id: label
    icon: AudioService.muted ? "volume-x" : AudioService.headphones ? "headphones" : "volume"
    text: BarLayout.faceText("audio", AudioService.muted || !AudioService.sink ? "--" : String(Math.min(AudioService.maxPercent, AudioService.volume)))
    tint: AudioService.muted ? Theme.red : AudioService.volume > 100 ? Theme.orange : Theme.foreground0
  }

  // Wheel events reach a layer-shell surface only through a MouseArea.
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.toggle()
    onWheel: wheel => {
      if (wheel.angleDelta.y !== 0)
        AudioService.stepVolume(wheel.angleDelta.y > 0 ? AudioService.scrollStep : -AudioService.scrollStep);
    }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "audio"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    AudioPopup {
      id: content
      anchors.fill: parent
      open: popup.visible
      onCloseRequested: popup.visible = false
    }
  }
}
