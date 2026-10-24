import QtQuick
import Quickshell
import qs.bar
import qs.config
import qs.kit

// Bar module: one icon, a floating window; the popup switches the window mode.
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  implicitWidth: face.implicitWidth
  implicitHeight: face.implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("windows")
  Accessible.description: "Open window layout options"

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
    id: face
    icon: "app-window"
    text: BarLayout.faceText("windows", WindowsService.current.label)
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); popup.toggle(); }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "windows"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    WindowsPopup {
      id: content
      anchors.fill: parent
      onArranged: if (ModuleSettings.get("windows", "closeOnGrid", false)) popup.toggle()
      onModePicked: if (ModuleSettings.get("windows", "closeOnMode", false)) popup.toggle()
    }
  }
}
