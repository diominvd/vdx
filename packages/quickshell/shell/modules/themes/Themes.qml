import QtQuick
import Quickshell
import qs.apps.shellmanager
import qs.bar
import qs.config
import qs.kit

// Bar module: the dotfiles theme. Click opens a strip of theme cards to
// switch from, or a list (ThemesPopup); the wheel steps to the next /
// previous theme (Modules › Themes).
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  implicitWidth: face.implicitWidth
  implicitHeight: face.implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("themes")
  Accessible.description: "Open theme choices"

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
    icon: "palette"
    text: BarLayout.faceText("themes", ModuleSettings.get("themes", "name", true) ? ThemeService.current : "")
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); popup.toggle(); }
    onWheel: wheel => {
      const list = ThemeService.inMode;
      if (!ModuleSettings.get("themes", "barWheel", true) || ThemeService.busy || list.length === 0
          || wheel.angleDelta.y === 0) return;
      const i = list.indexOf(ThemeService.current);
      ThemeService.apply(list[(i + (wheel.angleDelta.y > 0 ? -1 : 1) + list.length) % list.length]);
    }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "themes"
    moduleId: "themes"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    onShown: content.shown()

    ThemesPopup {
      id: content
      anchors.fill: parent
    }
  }
}
