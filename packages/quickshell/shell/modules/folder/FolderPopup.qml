import QtQuick
import qs.bar
import qs.config
import qs.kit

// The folder: a tile per tucked-away module (icon and name); a click opens
// that module's popup. Which modules live here is set on Shell Manager › Bar.
KitFrame {
  id: root

  property var ids: []

  signal picked(string id)

  KitHeader {
    icon: "folder"
    title: "Folder"
    subtitle: root.ids.length + (root.ids.length === 1 ? " MODULE" : " MODULES")
  }

  KitLine {}

  KitText {
    visible: root.ids.length === 0
    width: parent.width
    text: "Empty. Put modules here in Shell Manager › Bar, row FOLDER."
    color: Theme.muted
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSize - 1
  }

  Grid {
    id: tiles
    visible: root.ids.length > 0
    width: parent.width
    columns: 3
    spacing: Theme.gapSmall

    Repeater {
      model: root.ids

      Rectangle {
        radius: Theme.radiusCard
        id: tile

        required property string modelData

        readonly property var module: BarLayout.modules.find(p => p.id === modelData) ?? null

        width: Math.max(0, (root.width - 2 * root.padding - 2 * 6) / 3)   // three to a row, 6 between
        height: 58
        color: tileArea.containsMouse ? Theme.background3 : Theme.background1
        border.width: tile.activeFocus ? Math.max(2, Theme.frameWidth) : 0
        border.color: Theme.foreground0

        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: tile.module?.label ?? tile.modelData
        Accessible.description: "Open this bar module"

        Keys.onPressed: event => {
          if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
          if (!event.isAutoRepeat) { root.picked(tile.modelData); }
          event.accepted = true;
        }

        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

        Column {
          anchors.centerIn: parent
          spacing: Theme.gapSmall

          KitIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: tile.module?.icon ?? ""
            size: 18
          }

          KitText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.module?.label ?? tile.modelData
            font.pixelSize: Theme.fontSize - 2
          }
        }

        MouseArea {
          id: tileArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { tile.forceActiveFocus(); root.picked(tile.modelData); }
        }
      }
    }
  }
}
