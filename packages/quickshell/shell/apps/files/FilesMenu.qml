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
  property int activeIndex: -1

  visible: false
  width: parent ? Math.min(260, parent.width) : 260
  height: Math.min(column.implicitHeight + 2 * Theme.gapLoose, parent ? parent.height : column.implicitHeight + 2 * Theme.gapLoose)
  radius: Theme.radiusSurface
  color: Theme.background0
  border.width: Theme.windowFrameWidth
  border.color: Theme.popupFrame

  function open(x, y, list) {
    items = list;
    activeIndex = -1;
    // kept inside the window
    this.x = Math.max(0, Math.min(x, parent.width - width));
    this.y = Math.max(0, Math.min(y, parent.height - height));
    visible = true;
    for (let i = 0; i < items.length; i++) {
      if (!items[i].disabled) {
        focusItem(i);
        break;
      }
    }
  }

  function focusItem(index) {
    if (index < 0 || index >= items.length) return;
    activeIndex = index;
    const target = menuItems.itemAt(index);
    if (!target) return;
    target.forceActiveFocus();
    if (target.y < scroller.contentY) scroller.contentY = target.y;
    else if (target.y + target.height > scroller.contentY + scroller.height) {
      scroller.contentY = Math.min(scroller.contentHeight - scroller.height, target.y + target.height - scroller.height);
    }
  }

  function moveFocus(delta) {
    if (items.length === 0) return;
    let index = activeIndex;
    for (let step = 0; step < items.length; step++) {
      index = (index + delta + items.length) % items.length;
      if (!items[index].disabled) {
        focusItem(index);
        return;
      }
    }
  }

  function close() {
    visible = false;
    activeIndex = -1;
  }

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
        id: menuItems
        model: root.items

        Rectangle {
          id: item

          required property var modelData
          required property int index

          activeFocusOnTab: !modelData.disabled
          Accessible.role: Accessible.MenuItem
          Accessible.name: modelData.label
          Accessible.description: modelData.hint ?? ""
          border.width: activeFocus ? 2 : 0
          border.color: Theme.foreground0

          Keys.onPressed: event => {
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
              root.moveFocus(event.key === Qt.Key_Up ? -1 : 1);
              event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
              root.close();
              event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
              if (!event.isAutoRepeat && !modelData.disabled) {
                root.close();
                modelData.run();
              }
              event.accepted = true;
            }
          }
          onActiveFocusChanged: if (activeFocus) root.activeIndex = index

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
