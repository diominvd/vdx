import QtQuick
import qs.config

// A group of outlined buttons, one per choice; the one matching `current` is
// filled (a row of tabs, scale or orientation pickers). Model:
// [{label, value, icon?}]. `busyValue` spins that button while it applies;
// `stretch` makes the buttons share the full width. Material: connected pills, the
// picked one filled (Theme.primary). Wider than its parent at their own widths (a popup's
// section), the buttons share the parent's width instead of running past its edge.
Row {
  id: root

  property var model: []
  property var current: null
  property var busyValue: null
  property bool disabled: false
  property bool stretch: false

  signal picked(var value)
  readonly property bool kitFree: true
  property real kitShift: 0              // KitFrame: a footer's way down past a section's edge
  transform: Translate { y: root.kitShift }
  readonly property bool m3: Theme.material

  spacing: m3 ? Theme.gapTight : Theme.gapSmall

  // the buttons' own widths side by side, and the room the parent leaves beside this row
  readonly property real naturalWidth: {
    let w = 0;
    for (let i = 0; i < buttons.count; i++) w += buttons.itemAt(i)?.implicitWidth ?? 0;
    return w + spacing * Math.max(0, buttons.count - 1);
  }
  readonly property real room: parent ? parent.width - x : naturalWidth
  readonly property bool squeezed: !stretch && room > 0 && naturalWidth > room
  readonly property real span: stretch ? width : room

  Repeater {
    id: buttons
    model: root.model

    KitButton {
      required property var modelData
      required property int index

      width: root.stretch || root.squeezed ? (root.span - root.spacing * (root.model.length - 1)) / root.model.length : implicitWidth
      icon: modelData.icon ?? ""
      text: modelData.label
      selected: modelData.value === root.current
      segment: true
      joinLeft: index > 0
      joinRight: index < root.model.length - 1
      busy: root.busyValue !== null && modelData.value === root.busyValue
      disabled: root.disabled
      onClicked: if (!selected) root.picked(modelData.value)
    }
  }
}
