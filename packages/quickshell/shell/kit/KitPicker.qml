import QtQuick
import QtQuick.Controls as Controls
import qs.config

// A two-pane picker, the Themes page's frame: a search and a list of entries on the left
// (a thumbnail, a name, a line under it, a check on the one in use; sections as small
// captions), the picked one's preview on the right (the children). ↑ / ↓ pick, Enter
// activates, Esc clears the search, then asks to go back to the one in use. The list shows
// only the rows in view, so a hundred entries cost no more than ten. Fills its height.
//
// Model: [{key, label, sub?, section?}], sorted by section; static data only: what the
// picked / in-use rows look like comes from `selected` / `marked`.
Row {
  id: root

  property var model: []
  property string selected: ""
  property string marked: ""                  // the one in use: a check
  property string busyKey: ""                 // a spinner instead of the check
  property string placeholder: "Search"
  property string emptyIcon: "search"
  property string emptyTitle: "Nothing matches"
  property string emptyHint: "Try another name"
  property Component thumb: null              // a row's picture; `entry` is its model item
  property int thumbWidth: 0
  property int listWidth: 270
  property string query: ""
  readonly property var shown: {
    const q = query.trim().toLowerCase();
    return q === "" ? model : model.filter(e => e.label.toLowerCase().includes(q));
  }
  readonly property Item search: searchField
  default property alias detail: pane.data

  signal picked(string key)
  signal activated()
  signal escaped()                            // Esc with nothing to clear

  function step(delta) {
    const i = shown.findIndex(e => e.key === selected);
    const next = shown[Math.max(0, Math.min(shown.length - 1, i + delta))];
    if (!next) return;
    picked(next.key);
    list.positionViewAtIndex(shown.indexOf(next), ListView.Contain);
  }
  function focusSearch() { searchField.input.forceActiveFocus(); }

  spacing: Theme.gapGroup

  Column {
    id: side
    width: root.listWidth
    height: root.height - Theme.windowPadding
    spacing: Theme.gapMedium

    KitInput {
      id: searchField
      width: parent.width
      placeholder: root.placeholder
      icon: "search"
      text: root.query
      onTextEdited: {
        root.query = text;
        if (root.shown.length > 0 && !root.shown.some(e => e.key === root.selected)) root.picked(root.shown[0].key);
      }
      Keys.onUpPressed: root.step(-1)
      Keys.onDownPressed: root.step(1)
      Keys.onReturnPressed: root.activated()
      Keys.onEnterPressed: root.activated()
      Keys.onEscapePressed: event => {
        if (root.query !== "") { root.query = ""; searchField.text = ""; }
        else root.escaped();
      }
    }

    Rectangle {
      width: parent.width
      height: parent.height - searchField.height - parent.spacing
      radius: Theme.radiusCard
      color: Theme.groupFill
      border.width: Theme.frameWidth
      border.color: Theme.controlLine

      ListView {
        id: list
        Controls.ScrollBar.vertical: KitScrollBar {}
        anchors {
          fill: parent
          leftMargin: Theme.gapSmall
          rightMargin: Theme.gapSmall
          topMargin: Theme.gapSmall + Theme.gapMedium / 2
          bottomMargin: Theme.gapSmall + Theme.gapMedium / 2
        }
        clip: true
        spacing: Theme.gapTight
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 0
        model: root.shown

        section.property: "section"
        section.criteria: ViewSection.FullString
        section.delegate: Item {
          required property string section
          width: list.width
          height: section === "" ? 0 : 26
          visible: section !== ""
          KitText {
            anchors { left: parent.left; leftMargin: Theme.gapMedium; bottom: parent.bottom; bottomMargin: 4 }
            text: parent.section
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 2
            font.letterSpacing: 1
          }
        }

        KitEmptyState { visible: root.shown.length === 0; width: parent.width; icon: root.emptyIcon; title: root.emptyTitle; hint: root.emptyHint }

        delegate: Rectangle {
          id: item
          required property var modelData
          readonly property bool picked: modelData.key === root.selected
          readonly property bool active: modelData.key === root.marked

          width: list.width - Theme.gapMedium
          anchors.horizontalCenter: parent.horizontalCenter
          height: 56
          radius: Theme.radiusControl
          color: picked ? Theme.pickFill : area.containsMouse ? Theme.controlHover : Theme.clear
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

          Loader {
            id: thumbLoader
            anchors { left: parent.left; leftMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
            width: root.thumbWidth
            height: 44
            active: root.thumb !== null
            sourceComponent: root.thumb
            onLoaded: item.bind()
          }
          function bind() { if (thumbLoader.item) thumbLoader.item.entry = Qt.binding(() => item.modelData); }

          Column {
            anchors { left: parent.left; leftMargin: (root.thumbWidth > 0 ? root.thumbWidth + Theme.gapSmall : 0) + Theme.gapLoose; right: mark.left; rightMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
            spacing: Theme.gapHair

            KitText {
              width: parent.width
              elide: Text.ElideRight
              text: item.modelData.label
              color: item.picked || item.active ? Theme.foreground0 : Theme.foreground2
              font.weight: item.picked ? Theme.pickWeight : Font.Normal
            }
            KitText {
              width: parent.width
              visible: (item.modelData.sub ?? "") !== ""
              elide: Text.ElideRight
              text: item.modelData.sub ?? ""
              color: Theme.muted
              font.pixelSize: Theme.fontSize - 1
            }
          }

          Item {
            id: mark
            anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
            width: 16
            height: 16
            KitSpinner { anchors.centerIn: parent; visible: root.busyKey === item.modelData.key }
            KitIcon {
              anchors.centerIn: parent
              visible: root.busyKey !== item.modelData.key && (item.active || item.modelData.available === true)
              name: item.active ? "check" : "download"
              tint: item.active ? Theme.green : Theme.foreground2
              size: Theme.iconSmall
            }
          }

          MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.picked(item.modelData.key); root.focusSearch(); }
            onDoubleClicked: root.activated()
          }
        }
      }
    }
  }

  Column {
    id: pane
    width: root.width - side.width - root.spacing
    height: side.height
    spacing: Theme.gapWide
  }
}
