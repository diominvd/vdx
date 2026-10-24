import QtQuick
import Quickshell
import qs.apps.cleaner
import qs.bar
import qs.config
import qs.kit

// Bar module: the cleaner's icon; the popup shows what can go and cleans the
// safe part in one click, or opens the full window (Super+X).
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  implicitWidth: face.implicitWidth
  implicitHeight: face.implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("cleaner")
  Accessible.description: "Open system cleaner"

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
    icon: "brush"
    text: BarLayout.faceText("cleaner", BarLayout.label("cleaner"))
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); popup.toggle(); }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "clean"
    moduleId: "cleaner"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    onShown: CleanerService.freshen()

    CleanerPopup {
      id: content
      anchors.fill: parent
      onOpenWindow: popup.visible = false
    }
  }
}
