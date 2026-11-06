import QtQuick
import qs.config

// A setting row: a label and a dim hint under it on the left, a control (a
// switch, a button, a value) on the right (children).
//
// `wide`: the control is a set of choices or a field — it gets the standard
// width (Theme.controlWidth, so the right edges line up down a page); in a narrow
// place (under Theme.rowStackBelow) it goes under the text. Only the row's width decides,
// never its text: every wide row of a page sits the same way. Wide controls keep the same
// width inline and the row's whole width stacked. Give a wide KitChoices `stretch: true`.
//
// `needs`: what this row waits for, in one phrase ("Island style only", "Needs Live
// activities on"): the row stays in sight, its control out of reach, the phrase where the
// hint was and, if `needsAction` is set, one button that fixes it (needsActed()). The
// search index reads the phrase as the row's hint. The one dependency pattern of every page.
Item {
  id: root

  property string label: ""
  property string hint: ""
  property string tip: ""           // an explanation behind an info mark: a tooltip, the row stays one line
  property string tipLevel: "info"  // KitTip: info | ok | warn | danger
  property string hintLevel: "info" // warn | danger tint the hint: a caveat the reader must see, so it is never a tooltip
  property color labelColor: Theme.foreground0
  property bool wide: false
  property bool dimmed: false       // its option is unavailable (the adapter is off)
  property string needs: ""         // what it waits for: see above
  property string needsAction: ""   // the button that fixes it ("Use Island")
  signal needsActed()

  // The control goes under the text in a narrow row, in every wide row alike (a hint is
  // written for one line: design.md).
  readonly property bool stacked: wide && width < Theme.rowStackBelow

  // Wide controls share one width so their edges line up across the page. Clamp
  // it only when the whole settings column is narrower than the standard width.
  // Stacked, the control spans the row under its text: a narrower one at the right
  // edge reads as a diagonal from the label.
  readonly property real controlW: {
    if (stacked) return width;
    const c = slot.children.length > 0 ? slot.children[0] : null;
    const least = c && c.minWidth !== undefined ? c.minWidth : Theme.controlWidth;
    return Math.min(width, Math.max(least, Math.min(Theme.controlWidth, width - 12)));
  }

  default property alias trailing: slot.data

  width: parent ? parent.width : 0
  opacity: dimmed ? 0.4 : needs !== "" ? 0.6 : 1
  // stacked, the row fills its height, so it keeps the spare height a centred control has: every edge of the box is the same distance from what is in it
  readonly property int stackPad: Math.round((Theme.rowHeight - Theme.controlHeight) / 2)
  implicitHeight: stacked ? 2 * stackPad + text.implicitHeight + Theme.gapSmall + slot.height
                          : Math.max(Theme.rowHeight, text.implicitHeight, slot.height)

  Column {
    id: text
    anchors {
      left: parent.left
      right: root.stacked ? parent.right : fix.visible ? fix.left : slot.left
      rightMargin: root.stacked ? 0 : 12
    }
    y: root.stacked ? root.stackPad : (root.height - height) / 2
    spacing: Theme.gapTight

    Row {
      width: parent.width
      spacing: Theme.gapMedium

      KitText {
        id: labelItem
        width: Math.min(implicitWidth, parent.width - (tip.visible ? tip.width + parent.spacing : 0))
        text: root.label
        color: root.labelColor
        elide: Text.ElideRight
      }

      KitTip {
        id: tip
        visible: root.tip !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: root.tip
        level: root.tipLevel
      }
    }

    KitText {
      id: hintItem
      width: parent.width
      visible: root.hint !== "" || root.needs !== ""
      text: root.needs !== "" ? root.needs : root.hint
      color: root.hintLevel === "warn" ? Theme.yellow : root.hintLevel === "danger" ? Theme.red : Theme.hint
      wrapMode: Text.WordWrap
      font.pixelSize: Theme.fontSize - 1
    }
  }

  // the one button that fixes what the row needs
  KitButton {
    id: fix
    visible: root.needs !== "" && root.needsAction !== ""
    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
    text: root.needsAction
    onClicked: root.needsActed()
  }

  Row {
    id: slot
    visible: root.needs === ""
    anchors.right: parent.right
    y: root.stacked ? root.stackPad + text.height + Theme.gapSmall : (root.height - height) / 2
    spacing: Theme.gapMedium
  }

  // the one control of a wide row takes the standard width
  Binding {
    when: root.wide && slot.children.length > 0
    target: slot.children.length > 0 ? slot.children[0] : null
    property: "width"
    value: root.controlW
  }
}
