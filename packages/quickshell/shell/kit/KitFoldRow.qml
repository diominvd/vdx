import QtQuick
import qs.config

// A row of a reorderable list (KitReorderList) that may unfold: a drag handle, an optional
// `leading` item (a sample), the name and a dim line under it, a switch, and — when
// `foldable` — an arrow that unfolds its options (the children) under the row. One look for
// every such list (Live activities, the Hub's blocks).
//
// Outside a list it is a plain row that stays put (`draggable: false`; a `tag` in place of
// the switch: "ALWAYS ON"), so it lines up with the rows of the list under it.
Item {
  id: root

  required property string key
  required property int index

  property string label: ""
  property string hint: ""
  property bool checked: false
  property bool switchEnabled: true
  property string tag: ""                      // text in place of the switch (a block that cannot be turned off)
  property bool draggable: true
  property bool hasSwitch: true               // false: a row that only unfolds (an arrow, no switch)
  property bool foldable: false
  property Component leading: null
  signal toggled()

  default property alias options: slot.data

  // the list this row lives in, if any
  readonly property Item list: {
    for (let p = parent; p; p = p.parent) if (p.isReorderList) return p;
    return null;
  }
  readonly property int rowHeight: list ? list.rowHeight : 52
  readonly property int bodyGap: list ? list.bodyGap : 0
  readonly property bool unfolded: list !== null && list.open === key && foldable && checked
  readonly property bool dragging: grip.held
  property real slotY: 0                       // where the list puts it
  property real dragY: 0                       // where the pointer holds it
  property bool flush: false                   // no handle column: the name and the options start at the left edge
  readonly property real indent: flush ? 0 : 12 + Theme.gapWide   // the handle's column: the name and the options start here

  width: parent ? parent.width : 0
  height: rowHeight + (unfolded ? bodyGap + fold.bodyHeight : 0)
  z: dragging ? 5 : 0
  onHeightChanged: if (list) list.relayout()

  Behavior on height { enabled: Motion.controls && !root.dragging; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }

  // in a list the list places it; the slot it takes is animated when the order changes
  Binding { when: root.list !== null; target: root; property: "y"; value: root.dragging ? root.dragY : root.slotY }
  Behavior on y { enabled: Motion.controls && root.list !== null && !root.dragging && root.list.settling; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }

  // the hairline between rows, in the middle of the gap above
  Rectangle {
    visible: root.list !== null && root.index > 0 && !root.dragging
    y: root.list ? -root.list.gap / 2 : 0
    width: parent.width
    height: Theme.dividerThickness
    color: Theme.dividerColor
  }

  // lifted while dragged: a raised, rounded plate under the row
  Rectangle {
    anchors { fill: parent; margins: -Theme.gapSmall }
    z: -1
    radius: Theme.radiusCard
    color: Theme.pickFill
    border.width: Theme.frameWidth
    border.color: Theme.controlLineHover
    opacity: root.dragging ? 1 : 0
    scale: root.dragging ? 1.015 : 1
    Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
    Behavior on scale { enabled: Motion.controls; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
  }

  // the handle: two columns of three dots; it keeps its place while the options unfold
  Item {
    id: handle
    visible: root.draggable
    anchors { left: parent.left; top: parent.top; topMargin: (root.rowHeight - height) / 2 }
    width: 12
    height: 22
    opacity: grip.held ? 1 : 0.9
    Grid {
      anchors.centerIn: parent
      columns: 2
      spacing: 3
      Repeater { model: 6; Rectangle { width: 2; height: 2; color: grip.held ? Theme.foreground0 : Theme.dim } }
    }
    MouseArea {
      id: grip
      property bool held: false
      property real grab: 0
      anchors { fill: parent; margins: -8 }
      preventStealing: true
      enabled: root.list !== null
      cursorShape: held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
      onPressed: mouse => {
        root.list.open = "";                          // the rows stand the same height while one is dragged
        grab = root.list.mapFromItem(grip, mouse.x, mouse.y).y - root.y;
        root.dragY = root.y;
        held = true;
      }
      onPositionChanged: mouse => {
        if (!held) return;
        root.dragY = Math.max(0, Math.min(root.list.height - root.height, root.list.mapFromItem(grip, mouse.x, mouse.y).y - grab));
        root.list.dragTo(root.key, root.dragY);
      }
      onPressedChanged: if (!pressed && held) { root.list.settle(); held = false; }
    }
  }

  KitLeading { id: lead; component: root.leading }

  Column {
    id: names
    anchors {
      left: lead.item ? lead.right : parent.left
      leftMargin: lead.item ? Theme.gapWide : root.indent
      right: more.visible ? more.left : sw.visible ? sw.left : tagText.left
      rightMargin: Theme.gapWide
      top: parent.top
      topMargin: (root.rowHeight - height) / 2
    }
    spacing: Theme.gapTight
    opacity: root.checked || root.tag !== "" ? 1 : 0.5
    KitText { width: parent.width; text: root.label; elide: Text.ElideRight }
    KitText { width: parent.width; visible: root.hint !== ""; text: root.hint; color: Theme.muted; font.pixelSize: Theme.fontSize - 1; elide: Text.ElideRight }
  }

  // a click on the name or the arrow unfolds the options
  MouseArea {
    anchors { left: names.left; right: more.visible ? more.right : names.right; top: parent.top }
    height: root.rowHeight
    enabled: more.visible
    cursorShape: Qt.PointingHandCursor
    onClicked: root.list.open = root.unfolded ? "" : root.key
  }

  KitIcon {
    id: more
    visible: root.foldable && root.checked && root.list !== null
    anchors { right: sw.visible ? sw.left : parent.right; rightMargin: sw.visible ? Theme.gapWide : 0; top: parent.top; topMargin: (root.rowHeight - height) / 2 }
    name: "chevron-down"
    size: Theme.iconSmall
    tint: root.unfolded ? Theme.foreground0 : Theme.foreground2
    rotation: root.unfolded ? 180 : 0
    Behavior on rotation { enabled: Motion.controls; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
  }

  KitText {
    id: tagText
    visible: root.tag !== ""
    anchors { right: parent.right; top: parent.top; topMargin: (root.rowHeight - height) / 2 }
    text: root.tag
    color: Theme.dim
    font.pixelSize: Theme.fontSize - 2
    font.letterSpacing: 1
  }

  KitSwitch {
    id: sw
    visible: root.tag === "" && root.hasSwitch
    anchors { right: parent.right; top: parent.top; topMargin: (root.rowHeight - height) / 2 }
    checked: root.checked
    enabled: root.switchEnabled
    accessibleName: root.label
    onToggled: root.toggled()
  }

  // the options: a hairline, then the rows, clipped to the unfolding height. Below the last one
  // the list's own gap to the next hairline is all there is: the same inset as under the first line
  Item {
    id: fold
    readonly property real bodyHeight: body.implicitHeight
    anchors { left: parent.left; leftMargin: root.indent; right: parent.right; top: parent.top; topMargin: root.rowHeight + root.bodyGap }
    height: Math.max(0, root.height - root.rowHeight - root.bodyGap)
    clip: true
    opacity: root.unfolded ? 1 : 0
    Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }

    Column {
      id: body
      width: parent.width
      spacing: Theme.settingsRowInset          // the box's own row rhythm: a gap each side of a hairline
      Rectangle { width: parent.width; height: Theme.dividerThickness; color: Theme.dividerColor }
      Column { id: slot; width: parent.width; spacing: Theme.settingsRowInset }
    }
  }
}
