import QtQuick
import Quickshell
import qs.bar
import qs.components
import qs.config
import qs.kit
import qs.modules.mpd

// Bar module: Radio. The station on air, the icon alone otherwise. A click
// opens the dial, a middle click pauses or starts it.
Item {
  id: root

  required property PanelWindow bar

  // the Folder and the hub open this module's popup
  function openPopup() { popup.toggle(); }

  implicitWidth: face.implicitWidth
  implicitHeight: face.implicitHeight

  KitBarItem {
    id: face
    icon: "radio"
    text: BarLayout.faceText("tuner", RadioService.active ? (MpdService.player.station ?? "") : "")
    tint: RadioService.active ? Theme.yellow : Theme.gray
    opacity: RadioService.active && !MpdService.playing ? 0.6 : 1
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton) { if (RadioService.active) MpdService.toggle(); else RadioService.setActive(true); }
      else popup.toggle();
    }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "tuner"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    RadioPopup {
      id: content
      anchors.fill: parent
      onCloseRequested: popup.visible = false
    }
  }
}
