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

  KitBarItem {
    id: face
    icon: "activity"
    text: BarLayout.faceText("taskmanager", BarLayout.label("taskmanager"))
    tint: TaskManagerService.popupOpen && TaskManagerService.cpu >= 90 ? Theme.red : Theme.foreground0
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.toggle()
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
