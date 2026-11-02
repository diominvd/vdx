import QtQuick
import Quickshell
import qs.bar
import qs.config
import qs.kit

// An app's tray menu (its DBusMenu, Quickshell's QsMenuOpener) in the shell's own
// look, a popup over the tray icon. A click runs the entry and closes the menu.
// Quickshell's native menus need the Qt application mode, so they are not used.
BarPopup {
  id: root

  property var handle: null          // the item's DBusMenu handle (SystemTrayItem.menu)
  readonly property int maxLabel: 320  // a longer label ends with an ellipsis

  // the narrowest the menu gets (a short label, separators only)
  readonly property int minWidth: Theme.controlHeight * 4

  implicitWidth: frame.implicitWidth
  implicitHeight: frame.implicitHeight

  function labelOf(entry) {
    return entry.text.replace(/_/g, "") + (entry.hasChildren ? "  ›" : "");
  }

  QsMenuOpener {
    id: opener
    menu: root.handle
  }

  KitFrame {
    id: frame

    // as wide as its widest row (KitFrame's default is Theme.modulePopupWidth): each
    // row is as wide as its own label, `rows` takes the widest, and a row's
    // body (highlight, line) spans the whole of `rows`
    fitWidth: true
    implicitWidth: rows.implicitWidth + 2 * frame.padding

    Column {
      id: rows
      width: parent.width
      spacing: Theme.gapGroup

      Repeater {
        model: opener.children

        delegate: Item {
          id: row

          required property QsMenuEntry modelData

          width: Math.max(root.minWidth, row.modelData.isSeparator ? 0
                          : Math.min(label.implicitWidth, root.maxLabel) + Theme.gapMedium * 2)
          height: modelData.isSeparator ? 1 + Theme.gapSmall * 2 : Theme.controlHeight

          Item {
            width: rows.width
            height: parent.height

            KitLine {
              visible: row.modelData.isSeparator
              anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
              anchors.fill: parent
              visible: !row.modelData.isSeparator
              radius: Theme.radiusControl
              color: entry.containsMouse && row.modelData.enabled ? Theme.hoverOn(false) : Theme.clear
              Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.normal; easing.type: Motion.easing } }
              opacity: row.modelData.enabled ? 1 : 0.4

              // implicitWidth is the whole label's, whatever its width
              KitText {
                id: label
                anchors { left: parent.left; leftMargin: Theme.gapMedium; right: parent.right; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
                elide: Text.ElideRight
                text: root.labelOf(row.modelData)
              }

              MouseArea {
                id: entry
                anchors.fill: parent
                hoverEnabled: true
                enabled: row.modelData.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  row.modelData.triggered();
                  root.visible = false;
                }
              }
            }
          }
        }
      }
    }
  }
}
