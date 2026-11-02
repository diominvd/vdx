import QtQuick
import qs.config
import qs.kit

// Appearance › Glow: a soft halo behind the bright, accented elements — each
// glows in its own colour (KitGlow).
KitColumn {
  id: root
  spacing: Theme.sectionGap

  readonly property var targets: [
    { value: "switches",   label: "Switches",    hint: "The ones that are on" },
    { value: "sliders",    label: "Sliders",     hint: "The filled part" },
    { value: "workspaces", label: "Workspaces",  hint: "The focused one, in the shape styles" },
    { value: "live",       label: "Live activity", hint: "The island's bars, dots and icons" },
    { value: "dots",       label: "Status dots", hint: "The folder's mark and the tags' dots" }
  ]
  function setTarget(key, on) {
    ShellSettings.set("glowWhere", Object.assign({}, ShellSettings.glowWhere, { [key]: on }));
  }

  KitLabel { text: "GLOW" }
  KitRow {
    label: "Glow"
    hint: "A soft halo behind bright elements"
    KitSwitch { checked: ShellSettings.glow; onToggled: ShellSettings.set("glow", !checked) }
  }
  KitSliderRow {
    visible: ShellSettings.glow
    label: "Strength"
    value: ShellSettings.glowStrength / 100
    text: Math.round(pressed ? dragValue * 100 : ShellSettings.glowStrength) + "%"
    onMoved: value => ShellSettings.set("glowStrength", Math.round(value * 100))
  }
  KitLine { visible: ShellSettings.glow }
  KitLabel { text: "GLOW ON"; visible: ShellSettings.glow }
  Repeater {
    model: root.targets
    KitRow {
      id: target
      required property var modelData
      visible: ShellSettings.glow
      label: modelData.label
      hint: modelData.hint
      KitSwitch {
        checked: ShellSettings.glowWhere[target.modelData.value] !== false
        onToggled: root.setTarget(target.modelData.value, !checked)
      }
    }
  }
  KitGrouper {}
}
