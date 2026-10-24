import QtQuick
import Quickshell
import qs.apps.virustotal
import qs.bar
import qs.config
import qs.kit

// Bar module: the scanner's icon; the popup looks a hash, URL or file up,
// and the full window (Shell Manager › Shell apps) keeps the details.
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  implicitWidth: face.implicitWidth
  implicitHeight: face.implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("virustotal")
  Accessible.description: "Open file and URL scan options"

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
    icon: "scan"
    text: BarLayout.faceText("virustotal", BarLayout.label("virustotal"))
    tint: !VirusTotalService.opt("tint", true) ? Theme.foreground0
        : VirusTotalService.verdict === "malicious" ? Theme.red
        : VirusTotalService.verdict === "suspicious" ? Theme.yellow : Theme.foreground0
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); popup.toggle(); }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "scan"
    moduleId: "virustotal"
    onShown: if (VirusTotalService.clipboardOn) VirusTotalService.readClipboard(content)
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    VirusTotalPopup {
      id: content
      anchors.fill: parent
      onOpenWindow: popup.visible = false
    }
  }
}
