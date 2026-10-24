import QtQuick
import Quickshell
import qs.apps.taskmanager
import qs.bar
import qs.config
import qs.kit

// Bar module: the task manager's icon; the popup shows the load and the
// busiest programs with End, and opens the full window (Ctrl+Shift+Esc).
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  implicitWidth: face.implicitWidth
  implicitHeight: face.implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("taskmanager")
  Accessible.description: "Open task manager and process details"

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
    icon: "activity"
    text: BarLayout.faceText("taskmanager", BarLayout.label("taskmanager"))
    tint: TaskManagerService.popupOpen && TaskManagerService.cpu >= 90 ? Theme.red : Theme.foreground0
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); popup.toggle(); }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "tasks"
    moduleId: "taskmanager"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    onShown: TaskManagerService.popupOpen = true
    onHidden: TaskManagerService.popupOpen = false

    TaskManagerPopup {
      id: content
      anchors.fill: parent
      onOpenWindow: popup.visible = false
    }
  }
}
