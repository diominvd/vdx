import QtQuick
import Quickshell
import qs.bar
import qs.config
import qs.kit

// Bar module: the proxy state (VPN glyph + label, green while mihomo.service runs).
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  // the server the policy group points at, cut to fit the bar
  readonly property int maxName: 16
  function shortCurrent() {
    const c = MihomoService.current;
    return c.length > maxName ? c.slice(0, maxName - 1) + Theme.ellipsis : c;
  }

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  KitBarItem {
    id: label
    icon: "vpn"
    text: BarLayout.faceText("mihomo", MihomoService.serviceOn && MihomoService.current !== "" ? root.shortCurrent() : "--")
    tint: MihomoService.serviceOn ? Theme.green : Theme.gray
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.toggle()
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "mihomo"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    onShown: MihomoService.popupShown()
    onHidden: MihomoService.popupHidden()

    MihomoPopup {
      id: content
      anchors.fill: parent
      onCloseRequested: popup.visible = false
    }
  }
}
