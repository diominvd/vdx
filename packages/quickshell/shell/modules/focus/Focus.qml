import QtQuick
import qs.bar
import qs.config
import qs.kit

// Bar module: Focus (do not disturb). A click switches it; no popup. Dim while off.
Item {
  id: root

  // a click on a stretched hub chip, off the face: the same as the face's own
  function activate() { FocusService.toggle(); }

  implicitWidth: face.implicitWidth
  implicitHeight: face.implicitHeight

  KitBarItem {
    id: face
    icon: "moon"
    text: BarLayout.faceText("focus", FocusService.on ? "Focus" : "")
    tint: FocusService.on ? Theme.purple : Theme.gray
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: FocusService.toggle()
  }
}
