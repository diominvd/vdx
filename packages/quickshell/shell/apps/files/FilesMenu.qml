import QtQuick
import qs.config
import qs.kit

// The right-click menu of the file list: one row per item, its shortcut as a
// hint at the right; a row that can't act now is dimmed. A pick, Escape or a
// click outside (Files) closes it. `open(x, y, items)` with items
// [{label, hint, disabled, run}].
Rectangle {
  id: root

  property var items: []

  visible: false
  width: parent ? Math.min(260, parent.width) : 260
  height: Math.min(column.implicitHeight + 2 * Theme.gapLoose, parent ? parent.height : column.implicitHeight + 2 * Theme.gapLoose)
  radius: Theme.radiusSurface
  color: Theme.background0
  border.width: Theme.windowFrameWidth
  border.color: Theme.popupFrame

  function open(x, y, list) {
    items = list;
    // kept inside the window
    this.x = Math.max(0, Math.min(x, parent.width - width));
    this.y = Math.max(0, Math.min(y, parent.height - height));
    visible = true;
  }

  function close() { visible = false; }

  Flickable {
    id: scroller
    x: Theme.gapLoose
    y: Theme.gapLoose
    width: Math.max(0, root.width - 2 * Theme.gapLoose)
    height: Math.max(0, root.height - 2 * Theme.gapLoose)
    contentWidth: width
    contentHeight: column.implicitHeight
    clip: true
    interactive: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: column
      width: scroller.width

      Repeater {
      model: root.items

      Rectangle {
        id: item

        required property var modelData

        width: column.width
        height: 28
        radius: Theme.radiusControl
        color: area.containsMouse && !modelData.disabled ? Theme.controlHover : Theme.clear
        opacity: modelData.disabled ? 0.4 : 1
        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

        KitText {
          anchors { left: parent.left; leftMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
          width: Math.max(0, parent.width - (hint.visible ? hint.width + 2 * Theme.gapMedium : Theme.gapMedium))
          elide: Text.ElideRight
          text: item.modelData.label
        }

        KitText {
          id: hint
          anchors { right: parent.right; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
          width: Math.min(90, Math.max(0, parent.width * 0.35))
          horizontalAlignment: Text.AlignRight
          elide: Text.ElideLeft
          visible: !!item.modelData.hint
          text: item.modelData.hint ?? ""
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 2
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          enabled: !item.modelData.disabled
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.close();
            item.modelData.run();
          }
        }
      }
    }
    }
  }
}
