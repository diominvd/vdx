import QtQuick
import Quickshell
import qs.bar
import qs.components
import qs.config
import qs.kit

// Robot icon and the percent of the chosen plan limit (Modules › AI › Limit);
// yellow / red when that limit is running out.
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  readonly property string kind: ModuleSettings.get("ai", "limit", "session")
  readonly property var shown: ClaudeService.limits.find(l => l.kind === kind) ?? null
  readonly property int percent: shown ? shown.percent : -1

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("ai")
  Accessible.description: "Open AI usage and limit details"

  Keys.onPressed: event => {
    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
    if (!event.isAutoRepeat) popup.toggle();
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
    icon: "bot"
    text: BarLayout.faceText("ai", root.percent >= 0 ? root.percent + "%" : "--")
    tint: root.percent >= ClaudeService.critical ? Theme.red
         : root.percent >= ClaudeService.warning ? Theme.yellow
         : Theme.foreground0
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); popup.toggle(); }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "ai"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    onShown: ClaudeService.popupShown()
    onHidden: ClaudeService.popupHidden()

    AiPopup {
      id: content
      anchors.fill: parent
    }
  }
}
