import QtQuick
import Quickshell
import qs.bar
import qs.components
import qs.config
import qs.kit

// Bell at the right edge. Unseen notifications light it (tint); a tucked-away
// bell tells the Folder (its `attention`), which draws the dot. The bell's own
// badge (Modules › Notifications › Bell badge): off, a dot or the count.
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  readonly property bool attention: NotificationsService.unseen > 0
  readonly property string badge: ModuleSettings.get("notifications", "badge", "off")

  implicitWidth: bell.implicitWidth
  implicitHeight: bell.implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("notifications")
  Accessible.description: "Open notifications"

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
    id: bell
    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
    icon: "bell"
    text: BarLayout.faceText("notifications", root.badge === "count" && root.attention
      ? (NotificationsService.unseen > 99 ? "99+" : String(NotificationsService.unseen)) : "")
    tint: root.attention ? Theme.foreground0 : Theme.gray

    // the dot: the same mark as the Folder's, on the bell's corner
    Rectangle {
      radius: Theme.pill(height)
      visible: root.badge === "dot" && root.attention
      x: Theme.fontSize - 3
      y: 0
      width: 6
      height: 6
      color: Theme.notifyDot(ShellSettings.barDotColor)
      border.width: Theme.frameWidth
      border.color: Theme.background0
    }
  }

  MouseArea {
    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
    width: bell.implicitWidth
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); popup.toggle(); }
  }

  BarPopup {
    id: popup
    anchorItem: bell
    ipcTarget: "notifications"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    onShown: NotificationsService.popupShown()

    NotificationsPopup {
      id: content
      anchors.fill: parent
      onCloseRequested: popup.visible = false
    }
  }
}
