import QtQuick
import Quickshell
import qs.bar
import qs.components
import qs.config
import qs.kit

// Bar module: the network's name (or the icon alone), green while connected.
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  readonly property string name: WifiService.ssid.length > WifiService.barMaxLength
    ? WifiService.ssid.slice(0, WifiService.barMaxLength - 1) + Theme.ellipsis
    : WifiService.ssid

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("wifi")
  Accessible.description: "Open network connections"

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
    icon: WifiService.radioOn ? "wifi" : "wifi-off"
    text: BarLayout.faceText("wifi", WifiService.connected ? root.name : "--")
    tint: WifiService.connected ? Theme.accentFor("modules", Theme.green) : Theme.gray
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); popup.toggle(); }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "wifi"
    closeOnEscape: false                 // WifiPopup: Escape goes back, then closes
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    onShown: WifiService.popupShown()
    onHidden: WifiService.popupHidden()

    WifiPopup {
      id: content
      anchors.fill: parent
      onCloseRequested: popup.visible = false
    }
  }
}
