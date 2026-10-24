import QtQuick
import qs.apps.shellmanager
import qs.bar
import qs.config
import qs.kit

// Bar module: light or dark. A click switches the theme to its twin
// (ThemeService.setLight); no popup. The face shows a sun or a moon, and the
// mode's name under Bar text › Content (Modules › Mode).
Item {
  id: root

  implicitWidth: face.implicitWidth
  implicitHeight: face.implicitHeight

  enabled: !ThemeService.busy
  activeFocusOnTab: enabled
  Accessible.role: Accessible.Button
  Accessible.name: ThemeService.light ? "Switch to dark theme" : "Switch to light theme"
  Accessible.description: "Toggle between light and dark appearance"

  Keys.onPressed: event => {
    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
    if (!event.isAutoRepeat) { if (!ThemeService.busy) ThemeService.setLight(!ThemeService.light); }
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
    icon: ThemeService.light ? "sun" : "moon"
    text: BarLayout.faceText("mode", ThemeService.light ? "Light" : "Dark")
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: ThemeService.busy ? Qt.BusyCursor : Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); if (!ThemeService.busy) ThemeService.setLight(!ThemeService.light); }
  }
}
