import QtQuick
import Quickshell
import qs.apps.display
import qs.bar
import qs.kit

// Bar module: the scale of this bar's monitor; the popup sets each monitor's
// scale and the text size, and its button opens the full window (arrangement lives there).
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  implicitWidth: face.implicitWidth
  implicitHeight: face.implicitHeight

  // the scale of the monitor this bar sits on (each screen has its own bar)
  function scaleText() {
    const name = root.bar.screen ? root.bar.screen.name : "";
    const m = DisplayService.monitors.find(o => o.name === name);
    return m ? Math.round(m.scale * 100) + "%" : "--";
  }

  KitBarItem {
    id: face
    icon: "monitor"
    text: BarLayout.faceText("display", root.scaleText())
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: popup.toggle()
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "monitors"
    moduleId: "display"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    onShown: DisplayService.refresh()

    DisplayPopup {
      id: content
      anchors.fill: parent
      onOpenWindow: popup.visible = false
    }
  }
}
