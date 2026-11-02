import QtQuick
import qs.config
import qs.kit

// Chips in bands — a settings-style row per band: its name on the left, its
// chips (icon + label) on the right, wrapping; thin lines, no boxes. Drag a chip
// along a band or to another one; a thin line marks where it lands. On release
// `dropped(id, zone, index)` says where it went — what that means is the page's.
// The band "hidden" is shown muted. Bands of another `groupOf` than the one
// above start after a hairline. A chip of `lineOf` is a line in its box (a
// separator); one `removable` shows a corner cross on hover (`removed(id)`).
// `sources` ({ id, label, icon }) sit in an ADD tray under the bands: dragged
// into a band they drop like a chip (`dropped` with the source's id), a click
// is `picked(id)`.
Column {
  id: board

  // the bands in order, and each band's chip ids in order
  property var zones: []
  property bool showIcons: true
  property bool countBadges: false
  property bool joinedRows: false
  property bool compactRows: false
  property var accepts: (id, zone) => true
  property Flickable scrollViewport: null
  property point pointerPosition
  property bool canceledGesture: false
  function cancelDrag() { dragId = ""; dropZone = ""; dropIndex = -1; canceledGesture = true; }
  Keys.onEscapePressed: event => { if (dragId !== "") { cancelDrag(); event.accepted = true; } else event.accepted = false; }
  Timer {
    interval: 16; repeat: true
    running: board.dragId !== "" && board.scrollViewport !== null
    onTriggered: {
      const view = board.scrollViewport;
      const p = board.mapToItem(view, board.pointerPosition.x, board.pointerPosition.y);
      const step = p.y < 40 ? -7 : p.y > view.height - 40 ? 7 : 0;
      const before = view.contentY;
      view.contentY = Math.max(0, Math.min(Math.max(0, view.contentHeight - view.height), before + step));
      board.track(board.pointerPosition.x, board.pointerPosition.y + view.contentY - before);
    }
  }
  property bool cards: false
  property bool stackedLabels: false
  property int mainZoneCount: 3
  property var idsOf: zone => []
  // a chip's label and icon; a band's text when it has no chips
  property var labelOf: id => id
  property var iconOf: id => ""
  property var tileOf: id => false             // a module the hub draws as a tile: a small mark on its chip
  // a chip that is a line in its box (a separator), not icon + label
  property var lineOf: id => false
  property var removable: id => false
  property var sources: []
  property string sourceHint: ""
  property string selectedId: ""
  signal inspected(string id)
  property var emptyText: zone => "empty"
  property var zoneLabel: zone => zone.toUpperCase()
  property var groupOf: zone => ""

  // the drag, and the chip under the pointer (the page can show it)
  property string dragId: ""
  property string dropZone: ""        // a band's zone, or "" off the bands
  property int dropIndex: -1
  property string hoverId: ""
  property int chipFontSize: Theme.fontSize - 1
  property int chipHeight: Theme.material ? 30 : 28
  readonly property bool stacked: stackedLabels || (!compactRows && width < 560)
  readonly property int labelWidth: stacked ? 0 : compactRows ? 112 : 104

  // bands and chips already on show: one that is new (a band added, a chip moved
  // into a band) fades in. `scope` (a monitor) starts it afresh.
  property string scope: ""
  property KitSeen seen: KitSeen {}
  onScopeChanged: { seen.reset(); cancelDrag(); }

  signal dropped(string id, string zone, int index)
  signal removed(string id)
  property var bandRemovable: zone => false   // a band that can be taken away whole (x by its name)
  signal bandRemoved(string zone)
  signal picked(string id)

  // where the pointer would drop: the band under y, then the chip slot in reading
  // order — chips on earlier lines, or left of the pointer on its line, come before it
  function track(x, y) {
    pointerPosition = Qt.point(x, y);
    ghost.x = x + 10;
    ghost.y = y - ghost.height / 2;
    for (let i = 0; i < bands.count; i++) {
      const band = bands.itemAt(i);
      const origin = band.mapToItem(board, 0, 0);
      if (x < origin.x || x > origin.x + band.width || y < origin.y || y > origin.y + band.height) continue;
      if (!board.accepts(board.dragId, band.zone)) { dropZone = ""; return; }
      let index = 0;
      const chips = band.chips;
      for (let j = 0; j < chips.count; j++) {
        const c = chips.itemAt(j);
        const p = c.mapToItem(board, c.width / 2, c.height / 2);
        if (y > p.y + c.height / 2 || (y >= p.y - c.height / 2 && y <= p.y + c.height / 2 && p.x < x)) index = j + 1;
      }
      dropZone = band.zone;
      dropIndex = index;
      return;
    }
    dropZone = "";
  }

  function release() {
    if (dragId !== "" && dropZone !== "" && accepts(dragId, dropZone)) dropped(dragId, dropZone, dropIndex);
    dragId = "";
    dropZone = "";
    dropIndex = -1;
  }

  spacing: 0

  Flow {
    width: board.width
    spacing: board.cards || board.stackedLabels ? Theme.gapMedium : 0
  Repeater {
    id: bands
    model: board.zones

    Item {
      id: band

      required property string modelData
      required property int index

      readonly property string zone: modelData
      readonly property var ids: board.idsOf(modelData)
      readonly property bool target: board.dragId !== "" && board.dropZone === modelData
      readonly property alias chips: chipRepeater
      // the first band of a group: a hairline over it
      readonly property int lead: !board.stackedLabels && !board.cards && index > 0 && board.groupOf(zone) !== board.groupOf(board.zones[index - 1]) ? 16 : 0

      width: !board.cards || board.width < 620 ? board.width
        : index < board.mainZoneCount ? (board.width - (board.mainZoneCount - 1) * Theme.gapMedium) / board.mainZoneCount
        : (board.width - Theme.gapMedium) / 2
      height: board.cards ? Math.max(index < board.mainZoneCount ? 112 : 90, area.height + 52)
        : area.height + (board.compactRows ? 16 : 24) + lead + (board.stacked ? 24 : 0)

      property real grown: 1
      opacity: grown
      NumberAnimation { id: bandIn; target: band; property: "grown"; from: 0; to: 1; duration: Motion.normal; easing.type: Motion.easing }
      Component.onCompleted: if (board.seen.arrived(zone)) bandIn.start()

      KitLine {
        visible: band.lead > 0
        y: band.lead / 2
        width: parent.width
        sectionBreak: false

      }

      Rectangle {
        x: 0; y: band.lead
        width: parent.width
        height: parent.height - band.lead - (board.cards ? 0 : Theme.gapMedium)
        radius: Theme.radiusCard
        color: board.joinedRows ? Theme.clear : board.stackedLabels ? Theme.background0 : Theme.groupFill
        border.width: board.joinedRows ? 0 : band.target ? Theme.ring : Theme.frameWidth
        border.color: band.target ? Theme.controlLineHover : Theme.controlLine
      }
      KitText {
        id: bandLabel
        x: Theme.gapWide
        y: band.lead + 8 + (board.cards || board.stacked ? 0 : (board.chipHeight - height) / 2)
        text: board.zoneLabel(band.zone) + (board.countBadges ? "" : " · " + band.ids.filter(id => !board.lineOf(id)).length)
        color: band.target ? Theme.foreground0 : Theme.muted
        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
        font.pixelSize: Theme.fontSize - 1
        font.letterSpacing: board.stackedLabels || board.compactRows ? 0 : 1
      }

      Rectangle {
        visible: board.countBadges
        x: bandLabel.x + bandLabel.implicitWidth + 6
        y: bandLabel.y + (bandLabel.height - height) / 2
        width: Math.max(16, countText.implicitWidth + 8); height: 16
        radius: Theme.pill(height)
        color: Theme.background2
        KitText {
          id: countText
          anchors.centerIn: parent
          text: band.ids.filter(id => !board.lineOf(id)).length
          font.pixelSize: Theme.fontSize - 3
          color: Theme.muted
        }
      }

      KitButton {
        visible: board.bandRemovable(band.zone) && board.dragId === ""
        x: board.labelWidth - 6; y: bandLabel.y + (bandLabel.height - height) / 2
        width: 20; height: 20
        icon: "x"
        Accessible.name: "Remove " + board.zoneLabel(band.zone)
        onClicked: board.bandRemoved(band.zone)
      }

      Rectangle {
        visible: board.joinedRows && band.index > 0
        x: Theme.gapWide; width: parent.width - 2 * Theme.gapWide
        height: Theme.hairline; color: Theme.controlLine
      }

      // the chips; a faint fill marks the band a chip is dragged over
      Rectangle {
        id: area
        x: (board.cards ? 0 : board.labelWidth) + Theme.gapWide
        y: band.lead + 8 + (board.cards || board.stacked ? 24 : 0)
        width: Math.max(0, parent.width - x - Theme.gapWide)
        height: Math.max(board.chipHeight, flow.implicitHeight)
        radius: Theme.radiusCard
        color: band.target ? Theme.pickFill : Theme.clear
        border.width: band.target ? Theme.hairline : 0
        border.color: Theme.controlLineHover
        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

        Flow {
          id: flow
          width: parent.width
          spacing: Theme.gapSmall

          Repeater {
            id: chipRepeater
            model: band.ids

            Rectangle {
              id: chip

              required property string modelData
              required property int index

              readonly property bool line: board.lineOf(modelData)
              readonly property bool hovered: (chipArea.containsMouse || closeArea.containsMouse) && board.dragId === ""
              width: Math.min(area.width, line ? 22 : Math.ceil(chipLabelMetrics.width) + (board.showIcons ? Theme.iconSmall + Theme.gapSmall : 0) + 28)
              height: line ? board.chipHeight : Math.max(board.chipHeight, chipText.implicitHeight + 12)
              radius: Theme.radiusControl
              activeFocusOnTab: true
              Accessible.role: Accessible.Button
              Accessible.name: board.labelOf(modelData) + ", " + board.zoneLabel(band.zone)
              Accessible.onPressAction: board.inspected(modelData)
              Keys.onReturnPressed: board.inspected(modelData)
              Keys.onSpacePressed: board.inspected(modelData)
              color: board.selectedId === modelData ? Theme.selectedFill : hovered ? Theme.hoverOn(true) : Theme.fillOn(true)
              border.width: activeFocus || board.selectedId === modelData ? Theme.hairline : Theme.frameWidth
              border.color: activeFocus ? Theme.focusRing : board.selectedId === modelData ? Theme.controlLineHover : Theme.controlLine
              property real grown: 1
              property real dim: board.dragId === modelData ? 0.25 : 1
              Behavior on dim { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
              Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
              opacity: dim * grown
              scale: 0.85 + 0.15 * grown
              NumberAnimation { id: chipIn; target: chip; property: "grown"; from: 0; to: 1; duration: Motion.normal; easing.type: Motion.easing }
              Component.onCompleted: if (board.seen.arrived(band.zone + "/" + modelData)) chipIn.start()

              TextMetrics {
                id: chipLabelMetrics
                text: board.labelOf(chip.modelData)
                font.family: Theme.fontFamily
                font.pixelSize: board.chipFontSize
                font.weight: Theme.fontWeight
              }

              // a line chip: the "|" it puts in the bar
              Rectangle {
                visible: chip.line
                anchors.centerIn: parent
                width: 2
                height: chip.height - 12
                radius: Theme.pill(width)
                color: band.zone === "hidden" ? Theme.muted : Theme.foreground0
              }

              Row {
                id: chipRow
                width: Math.max(0, chip.width - 20)
                visible: !chip.line
                anchors.centerIn: parent
                spacing: Theme.gapSmall

                KitIcon {
                  visible: board.showIcons
                  anchors.verticalCenter: parent.verticalCenter
                  name: board.iconOf(chip.modelData)
                  tint: band.zone === "hidden" ? Theme.muted : Theme.foreground2
                  size: Theme.iconSmall
                }

                KitText {
                  id: chipText
                  anchors.verticalCenter: parent.verticalCenter
                  width: Math.max(0, chipRow.width - (board.showIcons ? Theme.iconSmall + chipRow.spacing : 0))
                  wrapMode: Text.Wrap
                  text: board.labelOf(chip.modelData)
                  color: band.zone === "hidden" ? Theme.muted : Theme.foreground0
                  font.pixelSize: board.chipFontSize
                }
              }

              // the hub draws it as a tile
              Rectangle {
                visible: board.tileOf(chip.modelData) && !chip.line
                anchors { right: parent.right; rightMargin: 4; top: parent.top; topMargin: 4 }
                width: 7
                height: 7
                radius: Theme.pill(height)
                color: Theme.foreground2
              }

              // insertion marker before this chip, or after the last one
              Rectangle {
                readonly property bool after: chip.index === band.ids.length - 1 && board.dropIndex === band.ids.length
                visible: band.target && (board.dropIndex === chip.index || after)
                x: after ? parent.width + 2 : -4
                width: 2
                height: parent.height
                color: Theme.foreground0
              }

              MouseArea {
                id: chipArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                onEntered: board.hoverId = chip.modelData
                onExited: if (board.hoverId === chip.modelData) board.hoverId = ""
                property point origin
                onPressed: mouse => { origin = Qt.point(mouse.x, mouse.y); board.canceledGesture = false; }
                onPositionChanged: mouse => {
                  if (!pressed || board.canceledGesture) return;
                  if (board.dragId === "" && Math.abs(mouse.x - origin.x) + Math.abs(mouse.y - origin.y) > 6)
                    { board.dragId = chip.modelData; board.forceActiveFocus(); }
                  if (board.dragId === "") return;
                  const p = mapToItem(board, mouse.x, mouse.y);
                  board.track(p.x, p.y);
                }
                onReleased: {
                  if (board.dragId !== "") board.release();
                  else if (!board.canceledGesture) board.inspected(chip.modelData);
                }
                onCanceled: board.cancelDrag()
              }

              // a cross in the corner while the pointer is on it (as a child bar's)
              Rectangle {
                visible: chip.hovered && board.removable(chip.modelData)
                anchors { right: parent.right; top: parent.top; rightMargin: -6; topMargin: -6 }
                width: 18
                height: 18
                radius: Theme.pill(height)
                color: closeArea.containsMouse ? Theme.red : Theme.background3
                Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
                border.width: Theme.islandFrameWidth
                border.color: Theme.background0

                KitIcon {
                  anchors.centerIn: parent
                  name: "x"
                  size: 12
                  tint: closeArea.containsMouse ? Theme.background0 : Theme.foreground0
                }

                MouseArea {
                  id: closeArea
                  anchors { fill: parent; margins: -3 }
                  enabled: board.removable(chip.modelData)
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: board.hoverId = chip.modelData
                  onExited: if (board.hoverId === chip.modelData) board.hoverId = ""
                  onClicked: {
                    board.hoverId = "";
                    board.removed(chip.modelData);
                  }
                }
              }
            }
          }
        }

        KitText {
          visible: band.ids.length === 0
          anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
          width: Math.max(0, parent.width - 8)
          wrapMode: Text.WordWrap
          text: board.dragId !== "" ? "Drop here" : board.emptyText(band.zone)
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 1
        }
      }
    }
  }

  } // zone flow

  // the ADD tray: chips that make a new one, dragged into a band or clicked
  Item {
    visible: board.sources.length > 0
    width: board.width
    height: board.chipHeight + 12 + 16 + (board.stacked ? 24 : 0)

    KitLine {
      y: 8
      width: parent.width
      sectionBreak: false

    }

    KitText {
      y: 16 + 8 + (board.chipHeight - height) / 2
      text: "ADD"
      color: Theme.muted
      font.pixelSize: Theme.fontSize - 1
      font.letterSpacing: 1
    }

    Row {
      id: tray
      x: board.labelWidth
      y: 16 + 8 + (board.stacked ? 24 : 0)
      spacing: Theme.gapSmall

      Repeater {
        model: board.sources

        // outlined, no fill: a chip still to come
        Rectangle {
          id: source

          required property var modelData
          readonly property bool hovered: sourceArea.containsMouse && board.dragId === ""
          width: sourceRow.implicitWidth + 20
          height: board.chipHeight
          radius: Theme.radiusControl
          color: hovered ? Theme.background1 : Theme.clear
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
          border.width: Theme.islandFrameWidth   // either control style: the outline is the look
          border.color: hovered ? Theme.foreground2 : Theme.background3
          opacity: board.dragId === modelData.id ? 0.25 : 1

          Row {
            id: sourceRow
            anchors.centerIn: parent
            spacing: Theme.gapSmall

            KitIcon {
              anchors.verticalCenter: parent.verticalCenter
              name: source.modelData.icon ?? "plus"
              tint: Theme.foreground2
              size: Theme.iconSmall
            }

            KitText {
              anchors.verticalCenter: parent.verticalCenter
              text: source.modelData.label
              color: Theme.foreground0
              font.pixelSize: Theme.fontSize - 1
            }
          }

          MouseArea {
            id: sourceArea
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property point from
            property bool moved: false
            onEntered: board.hoverId = source.modelData.id
            onExited: if (board.hoverId === source.modelData.id) board.hoverId = ""
            onPressed: mouse => {
              from = Qt.point(mouse.x, mouse.y);
              moved = false;
              board.dragId = source.modelData.id;
              const p = mapToItem(board, mouse.x, mouse.y);
              board.track(p.x, p.y);
            }
            onPositionChanged: mouse => {
              if (board.dragId === "") return;
              if (Math.abs(mouse.x - from.x) + Math.abs(mouse.y - from.y) > 4) moved = true;
              const p = mapToItem(board, mouse.x, mouse.y);
              board.track(p.x, p.y);
            }
            onReleased: {
              const id = source.modelData.id;
              const click = !moved && board.dropZone === "";
              board.release();
              if (click) board.picked(id);
            }
          }
        }
      }
    }

    KitText {
      x: tray.x + tray.width + Theme.gapMedium
      y: tray.y + (board.chipHeight - height) / 2
      width: Math.max(0, parent.width - x)
      elide: Text.ElideRight
      text: board.sourceHint
      color: Theme.muted
      font.pixelSize: Theme.fontSize - 1
    }
  }

  // the chip being dragged, following the pointer
  KitText {
    id: ghost
    z: 10
    visible: board.dragId !== ""
    text: board.labelOf(board.dragId)
    font.weight: Font.DemiBold
  }
}
