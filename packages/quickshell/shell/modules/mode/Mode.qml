import QtQuick
import qs.apps.shellmanager
import qs.bar
import qs.kit

// Bar module: light or dark. A click switches the theme to its twin
// (ThemeService.setLight); no popup. The face shows a sun or a moon, and the
// mode's name under Bar text › Content (Modules › Mode).
Item {
  id: root

  // a click on a stretched hub chip, off the face: the same as the face's own
  function activate() { if (!ThemeService.busy) ThemeService.setLight(!ThemeService.light); }

  implicitWidth: face.implicitWidth
  implicitHeight: face.implicitHeight

  KitBarItem {
    id: face
    icon: "paint-bucket"
    text: BarLayout.faceText("mode", ThemeService.light ? "Light" : "Dark")
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: ThemeService.busy ? Qt.BusyCursor : Qt.PointingHandCursor
    onClicked: if (!ThemeService.busy) ThemeService.setLight(!ThemeService.light)
  }
}
