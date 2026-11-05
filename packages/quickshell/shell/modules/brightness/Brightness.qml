import QtQuick
import Quickshell
import qs.bar
import qs.config
import qs.kit

// Bar module: backlight level (sun, orange while the night light is on); wheel changes it.
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  KitBarItem {
    id: label
    icon: BrightnessService.nightActive ? "moon" : "sun"
    text: BarLayout.faceText("brightness", BrightnessService.available ? String(BrightnessService.brightness) : "--")
    tint: BrightnessService.nightActive ? Theme.orange : Theme.foreground0
  }

  // Wheel events reach a layer-shell surface only through a MouseArea.
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.toggle()
    onWheel: wheel => {
      if (wheel.angleDelta.y !== 0 && BrightnessService.available)
        BrightnessService.stepBrightness(wheel.angleDelta.y > 0 ? BrightnessService.scrollStep : -BrightnessService.scrollStep);
    }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "brightness"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    BrightnessPopup {
      id: content
      anchors.fill: parent
    }
  }
}
