import QtQuick
import Quickshell
import qs.bar
import qs.components
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

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("audio")
  Accessible.description: "Open audio controls; use the mouse wheel to change volume"

  Keys.onPressed: event => {
    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
    if (!event.isAutoRepeat) popup.toggle();
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
    icon: AudioService.muted ? "volume-x" : AudioService.headphones ? "headphones" : "volume"
    text: BarLayout.faceText("audio", !ModuleSettings.get("audio", "percent", true) ? "" : AudioService.muted || !AudioService.sink ? "--" : String(Math.min(AudioService.maxPercent, AudioService.volume)))
    tint: AudioService.muted ? Theme.red : Theme.foreground0
  }

  // Wheel events reach a layer-shell surface only through a MouseArea.
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); popup.toggle(); }
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
    }
  }
}
