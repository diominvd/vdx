import QtQuick
import Quickshell
import qs.bar
import qs.components
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

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("brightness")
  Accessible.description: "Open brightness controls; use the mouse wheel to change brightness"

  Keys.onPressed: event => {
    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
    if (!event.isAutoRepeat) { popup.toggle(); }
    event.accepted = true;
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusControl
    color: "transparent"
    border.width: root.activeFocus ? 2 : 0
    border.color: Theme.foreground0
  }

  KitBarItem {
    id: label
    icon: BrightnessService.nightActive ? "moon" : "sun"
    text: BarLayout.faceText("brightness", !ModuleSettings.get("brightness", "percent", true) ? ""
      : BrightnessService.available ? String(BrightnessService.brightness) : "--")
    tint: BrightnessService.nightActive ? Theme.accentFor("modules", Theme.orange) : Theme.foreground0
  }

  // Wheel events reach a layer-shell surface only through a MouseArea.
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); popup.toggle(); }
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
