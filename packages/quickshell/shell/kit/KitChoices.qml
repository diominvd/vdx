import QtQuick
import qs.config

// A group of outlined buttons, one per choice; the one matching `current` is
// filled (a row of tabs, scale or orientation pickers). Model:
// [{label, value, icon?}]. `busyValue` spins that button while it applies;
// `stretch` makes the buttons share the full width.
Row {
  id: root

  property var model: []
  property var current: null
  property var busyValue: null
  property bool disabled: false
  property bool stretch: false

  signal picked(var value)

  spacing: Theme.gapSmall

  Repeater {
    model: root.model

    KitButton {
      required property var modelData

      // A long choice list in a narrow window must not produce negative widths.
      width: root.stretch
        ? Math.max(0, (root.width - root.spacing * Math.max(0, root.model.length - 1)) / Math.max(1, root.model.length))
        : implicitWidth
      icon: modelData.icon ?? ""
      text: modelData.label
      selected: modelData.value === root.current
      busy: root.busyValue !== null && modelData.value === root.busyValue
      disabled: root.disabled
      onClicked: if (!selected) root.picked(modelData.value)
    }
  }
}
