import QtQuick
import qs.config
import qs.kit

// The list on the left of Bar modules and Apps, drawn as the Themes page's: a
// search (typing jumps to the first match, arrows move through the matches),
// then the entries {id, label, icon, link?, off?} in one raised box down to the
// pane's foot; the chosen one filled and bold, a link (set elsewhere) muted with
// an arrow, an entry that is off (not installed) muted. A click or an arrow
// emits picked(id).
Column {
  id: root

  property var model: []
  property string selected: ""
  signal picked(string id)

  property string query: ""
  readonly property var matches: model.filter(p => p.label.toLowerCase().includes(query.trim().toLowerCase()))

  function step(delta) {
    const i = matches.findIndex(p => p.id === selected);
    if (matches.length > 0) picked(matches[Math.max(0, Math.min(matches.length - 1, i < 0 ? 0 : i + delta))].id);
  }

  function ensureVisible(item) {
    const top = item.mapToItem(scroller.contentItem, 0, 0).y;
    if (top < scroller.contentY) scroller.contentY = top;
    else if (top + item.height > scroller.contentY + scroller.height)
      scroller.contentY = top + item.height - scroller.height;
  }
  width: Theme.sideWidth
  height: parent.height
  spacing: Theme.gapMedium

  // typing jumps to the first match, arrows move through the matches
  KitInput {
    width: parent.width
    placeholder: "Search…"
    accessibleName: "Search entries"
    accessibleDescription: "Filter entries by name. Use Up and Down to change the selected entry."
    text: root.query
    onTextEdited: {
      root.query = text;
      if (root.matches.length > 0 && !root.matches.some(p => p.id === root.selected))
        root.picked(root.matches[0].id);
    }
    Keys.onDownPressed: root.step(1)
    Keys.onUpPressed: root.step(-1)
  }

  Rectangle {
    radius: Theme.radiusCard
    width: parent.width
    height: root.height - y
    color: Theme.background1
    border.width: Theme.frameWidth
    border.color: Theme.background2

    Flickable {
      id: scroller
      anchors { fill: parent; margins: Theme.gapSmall }
      contentHeight: rows.implicitHeight
      interactive: contentHeight > height
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: rows
        width: parent.width
        spacing: Theme.gapTight

        Repeater {
          model: root.matches

          Rectangle {
            radius: Theme.radiusControl
            id: row

            required property var modelData

            readonly property bool active: modelData.id === root.selected

            width: rows.width
            height: 34
            border.width: rowArea.activeFocus ? Theme.focusRingWidth : 0
            border.color: Theme.focusRing
            color: active ? Theme.background3 : rowArea.containsMouse ? Theme.background2 : Theme.clear
            Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

            KitIcon {
              id: rowIcon
              anchors { left: parent.left; leftMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
              name: row.modelData.icon
              tint: row.active ? Theme.foreground0 : row.modelData.link || row.modelData.off ? Theme.muted : Theme.foreground2
              size: Theme.iconSmall
            }

            KitText {
              anchors { left: rowIcon.right; leftMargin: Theme.gapMedium; right: parent.right; rightMargin: row.modelData.link ? 26 : 8; verticalCenter: parent.verticalCenter }
              text: row.modelData.label
              elide: Text.ElideRight
              color: row.active || rowArea.containsMouse ? Theme.foreground0 : row.modelData.link || row.modelData.off ? Theme.muted : Theme.foreground2
              Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
              font.weight: row.active ? Font.ExtraBold : Font.DemiBold
            }

            // set elsewhere: a click goes there
            KitIcon {
              anchors { right: parent.right; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
              visible: !!row.modelData.link
              name: "external"
              size: 12
              tint: rowArea.containsMouse ? Theme.foreground0 : Theme.muted
            }

            MouseArea {
              id: rowArea
              anchors.fill: parent
              hoverEnabled: true
              activeFocusOnTab: true
              Accessible.role: Accessible.RadioButton
              Accessible.name: row.modelData.label
              Accessible.description: row.modelData.link ? "Opens a linked settings page"
                : row.modelData.off ? "Currently unavailable" : row.active ? "Selected" : "Select this entry"
              Accessible.checked: row.active
              cursorShape: row.active ? Qt.ArrowCursor : Qt.PointingHandCursor
              onActiveFocusChanged: if (activeFocus) root.ensureVisible(row)
              onClicked: { forceActiveFocus(); root.picked(row.modelData.id); }
              Keys.onPressed: event => {
                if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
                if (!event.isAutoRepeat) root.picked(row.modelData.id);
                event.accepted = true;
              }
            }
          }
        }
      }
    }
  }
}
