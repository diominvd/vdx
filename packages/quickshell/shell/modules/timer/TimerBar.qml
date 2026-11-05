import QtQuick
import Quickshell
import qs.bar
import qs.config
import qs.kit

// Bar module: Timer. The time while one runs, the icon alone otherwise. A click
// opens the popup, a middle click pauses or resumes.
Item {
  id: root

  required property PanelWindow bar

  // the Folder and the hub's tile open this module's popup
  function openPopup() { popup.toggle(); }

  implicitWidth: face.implicitWidth
  implicitHeight: face.implicitHeight

  KitBarItem {
    id: face
    icon: "clock"
    text: BarLayout.faceText("timer", TimerService.text)
    tint: TimerService.active ? Theme.orange : Theme.foreground0
    opacity: TimerService.paused ? 0.6 : 1
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton) { if (TimerService.active) TimerService.togglePause(); }
      else popup.toggle();
    }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "timer"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    TimerPopup {
      id: content
      anchors.fill: parent
    }
  }
}
