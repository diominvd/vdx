import QtQuick
import Quickshell
import qs.apps.backup
import qs.bar
import qs.kit

// Bar module: the backups' icon; the popup shows when the last backup ran,
// backs up now, and points to the restore guide. Super is not bound: the full
// window is the Backups app (Shell apps).
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  implicitWidth: face.implicitWidth
  implicitHeight: face.implicitHeight

  KitBarItem {
    id: face
    icon: "history"
    text: BarLayout.faceText("backup", BarLayout.label("backup"))
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.toggle()
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "backups"
    moduleId: "backup"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    onShown: BackupService.refresh()

    BackupPopup {
      id: content
      anchors.fill: parent
      onOpenWindow: popup.visible = false
    }
  }
}
