import QtQuick
import qs.config

// A setting row: a label and a dim hint under it on the left, a control (a
// switch, a button, a value) on the right (children).
//
// `wide`: the control is a set of choices or a field — it gets the standard
// width (Theme.controlWidth, so the right edges line up down a page), and in
// a narrow place (under Theme.rowStackBelow) it goes under the label, full
// width. Give a wide KitChoices `stretch: true`.
Item {
  id: root

  property string label: ""
  property string hint: ""
  property color labelColor: Theme.foreground0
  property bool wide: false
  property bool dimmed: false       // its option is unavailable (the adapter is off)

  readonly property bool stacked: wide && width < Theme.rowStackBelow

  default property alias trailing: slot.data

  width: parent ? parent.width : 0
  opacity: dimmed ? 0.4 : 1
  implicitHeight: stacked ? text.implicitHeight + 8 + slot.height
                          : Math.max(text.implicitHeight, slot.height)

  Column {
    id: text
    anchors.left: parent.left
    // A fixed-width trailing control can exceed a compact row. Clamp the
    // label column instead of allowing anchor arithmetic to produce a
    // negative width before the row reaches its stacked layout threshold.
    width: Math.max(0, root.stacked ? root.width : root.width - slot.width - 12)
    y: root.stacked ? 0 : (root.height - height) / 2
    spacing: Theme.gapTight

    KitText {
      width: parent.width
      text: root.label
      color: root.labelColor
      elide: Text.ElideRight
    }

    KitText {
      width: parent.width
      visible: root.hint !== ""
      text: root.hint
      color: Theme.muted
      elide: root.stacked ? Text.ElideNone : Text.ElideRight
      wrapMode: root.stacked ? Text.WordWrap : Text.NoWrap
      font.pixelSize: Theme.fontSize - 2
    }
  }

  Row {
    id: slot
    anchors.right: parent.right
    y: root.stacked ? text.height + 8 : (root.height - height) / 2
    spacing: Theme.gapMedium
  }

  // A single switch inherits the row's label unless it already has an
  // explicit accessible name, without duplicating labels in every screen.
  Binding {
    when: slot.children.length === 1 && root.label !== ""
      && slot.children[0].checked !== undefined
      && slot.children[0].accessibleName === ""
    target: slot.children.length === 1 ? slot.children[0] : null
    property: "accessibleName"
    value: root.label
  }

  // the one control of a wide row takes the standard width
  Binding {
    when: root.wide && slot.children.length > 0
    target: slot.children.length > 0 ? slot.children[0] : null
    property: "width"
    value: root.stacked ? root.width : Theme.controlWidth
  }
}
