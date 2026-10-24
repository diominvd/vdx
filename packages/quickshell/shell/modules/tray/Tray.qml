import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.bar
import qs.config
import qs.kit

// Bar module: the tray, the status icons of running apps (StatusNotifierItem).
// An app with a menu opens it on any click (a right click always does); one
// without a menu is activated by a click. A middle click is its secondary action.
// Passive items stay hidden, as the spec asks; the app's own icon is drawn in its colours.
// Collapse (Modules › Tray): the icons sit behind a dots button, a click opens them.
Row {
  id: root

  required property PanelWindow bar
  readonly property int iconSize: Theme.fontSize + 2 + ShellSettings.barIconGrow
  readonly property bool collapsible: ModuleSettings.get("tray", "collapsed", false)
  property bool open: false              // the icons are out, while collapsible
  readonly property bool showIcons: !collapsible || open

  function focusNeighbor(fromIndex, delta) {
    const count = trayRepeater.count;
    if (count < 1) return;
    for (let step = 1; step <= count; step++) {
      const next = (fromIndex + delta * step + count * 2) % count;
      const candidate = trayRepeater.itemAt(next);
      if (candidate && candidate.visible) {
        candidate.forceActiveFocus();
        return;
      }
    }
  }

  spacing: Theme.gapSmall

  // the dots (closed) or the arrow (open) that folds the icons away again
  Item {
    id: collapseButton
    visible: root.collapsible
    width: root.iconSize
    height: root.iconSize
    anchors.verticalCenter: parent.verticalCenter
    activeFocusOnTab: visible
    Accessible.role: Accessible.Button
    Accessible.name: root.open ? "Hide system tray icons" : "Show system tray icons"

    Rectangle {
      anchors.fill: parent
      radius: Theme.radiusControl
      color: "transparent"
      border.width: collapseButton.activeFocus ? 2 : 0
      border.color: Theme.foreground0
    }

    Keys.onPressed: event => {
      if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
      if (!event.isAutoRepeat) { root.open = !root.open; }
      event.accepted = true;
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: { collapseButton.forceActiveFocus(); root.open = !root.open; }
    }

    KitIcon {
      anchors.centerIn: parent
      name: root.open ? "chevron-right" : "more"
      tint: Theme.foreground0
      size: root.iconSize
    }
  }


  Repeater {
    id: trayRepeater
    model: SystemTray.items

    MouseArea {
      id: item

      required property SystemTrayItem modelData

      visible: root.showIcons && modelData.status !== Status.Passive
      width: root.iconSize
      height: root.iconSize
      anchors.verticalCenter: parent.verticalCenter
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      activeFocusOnTab: visible
      Accessible.role: Accessible.Button
      Accessible.name: modelData.tooltipTitle || "System tray item"
      Accessible.description: modelData.tooltipDescription || (modelData.hasMenu ? "Open application menu" : "Activate application")

      Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        color: "transparent"
        border.width: item.activeFocus ? 2 : 0
        border.color: Theme.foreground0
        z: 2
      }

      Keys.onPressed: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
        if (!event.isAutoRepeat) {
          if (modelData.onlyMenu || modelData.hasMenu) openMenu();
          else modelData.activate();
        }
        event.accepted = true;
      }
      Keys.onLeftPressed: event => { root.focusNeighbor(index, -1); event.accepted = true; }
      Keys.onRightPressed: event => { root.focusNeighbor(index, 1); event.accepted = true; }

      Image {
        anchors.fill: parent
        source: item.modelData.icon
        sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: item.containsMouse ? 1 : 0.85
        Behavior on opacity { enabled: Motion.bar; NumberAnimation { duration: Motion.quick } }
      }

      onClicked: mouse => {
        item.forceActiveFocus();
        if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate();
        else if (mouse.button === Qt.RightButton || modelData.onlyMenu || modelData.hasMenu) openMenu();
        else modelData.activate();
      }

      // the app's menu: a popup over the icon, in the shell's look
      function openMenu() { menuPopup.toggle(); }

      TrayMenu {
        id: menuPopup
        anchorItem: item
        bar: root.bar
        handle: item.modelData.menu
        ipcTarget: ""
      }
    }
  }
}
