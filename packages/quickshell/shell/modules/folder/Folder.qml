import QtQuick
import Quickshell
import qs.bar
import qs.config
import qs.kit

// Bar module: a folder for modules tucked off the bar (Shell Manager › Bar,
// FOLDER row) and for those the strip has no room for; the count next to it. Its popup lists them as tiles; a tile
// opens that module's own popup. The modules themselves live here, at the
// folder's size and transparent, so their popups open where the folder's does.
Item {
  id: root

  required property PanelWindow bar
  property var modules: ({})          // Bar's module id -> Component

  // the ones put here and the ones the strip had no room for (BarLayout.overflow)
  readonly property var ids: BarLayout.folderShown(bar.screen?.name ?? "")

  function moduleItem(id) {
    for (let i = 0; i < tucked.count; i++)
      if (tucked.itemAt(i)?.modelData === id) return tucked.itemAt(i).item;
    return null;
  }

  // a tucked module with news (its `attention`) puts a dot on the folder
  function anyAttention() {
    for (let i = 0; i < tucked.count; i++)
      if (tucked.itemAt(i)?.attention) return true;
    return false;
  }
  readonly property bool attention: anyAttention()

  implicitWidth: face.implicitWidth
  implicitHeight: face.implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("folder")
  Accessible.description: "Open overflow and tucked bar modules"

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
    icon: ModuleSettings.get("folder", "icon", "folder") === "dots" ? "more" : "folder"
    text: BarLayout.faceText("folder", root.ids.length > 0 ? String(root.ids.length) : "")
    tint: root.ids.length > 0 ? Theme.foreground0 : Theme.gray

    // unseen mark: a small red square on the folder's corner
    Rectangle {
      radius: Theme.pill(height)
      visible: root.attention && ShellSettings.barFolderDot
      x: Theme.fontSize - 3
      y: 0
      width: 6
      height: 6
      color: Theme.notifyDot(ShellSettings.barDotColor)
      border.width: Theme.frameWidth
      border.color: Theme.background0
    }
  }

  Repeater {
    id: tucked
    model: root.ids

    // the folder's own size, transparent and under its click area: nothing
    // shows, and their popups (own windows) line up exactly with the folder's
    Loader {
      required property string modelData
      readonly property bool attention: item?.attention ?? false
      opacity: 0
      width: root.width
      height: root.height
      sourceComponent: root.modules[modelData] ?? null
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); popup.toggle(); }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "folder"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    FolderPopup {
      id: content
      anchors.fill: parent
      ids: root.ids
      onPicked: id => {
        popup.visible = false;
        Qt.callLater(() => root.moduleItem(id)?.openPopup?.());
      }
    }
  }
}
