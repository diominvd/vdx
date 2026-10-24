import QtQuick
import Quickshell
import qs.apps.packages
import qs.bar
import qs.config
import qs.kit

// Bar module: the number of pending updates (repos and AUR), yellow while
// there are some; the popup updates or rolls back the last upgrade, and the
// full window (Shell Manager › Shell apps) has the installed packages and the cache.
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  implicitWidth: face.implicitWidth
  implicitHeight: face.implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("packages")
  Accessible.description: "Open package updates and rollback options"

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
    icon: "package"
    text: BarLayout.faceText("packages", !PackagesService.opt("showCount", true) ? ""
        : PackagesService.checkedAt === 0 ? "--" : String(PackagesService.count))
    tint: PackagesService.count > 0 && PackagesService.opt("tint", true) ? Theme.yellow : Theme.foreground0
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); popup.toggle(); }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "updates"
    moduleId: "packages"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    onShown: PackagesService.freshen()

    PackagesPopup {
      id: content
      anchors.fill: parent
      onOpenWindow: popup.visible = false
    }
  }
}
