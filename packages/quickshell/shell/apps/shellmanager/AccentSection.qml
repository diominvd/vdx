import QtQuick
import qs.config
import qs.kit

// One palette token selects a solid accent throughout the shell.
KitColumn {
  spacing: Theme.sectionGap

  id: root
  readonly property var names: ["theme", "red", "orange", "yellow", "green", "aqua", "blue", "purple"]
  readonly property var targets: [
    { value: "switches",   label: "Switches",      hint: "The ones that are on" },
    { value: "sliders",    label: "Sliders",       hint: "The filled part" },
    { value: "choices",    label: "Choices",       hint: "The picked one" },
    { value: "selects",    label: "Dropdowns",     hint: "The open one's frame" },
    { value: "window",     label: "Window frames", hint: "The focused window's frame" }
  ]
  readonly property string selected: names.includes(ShellSettings.accentStops[0]) || ShellSettings.customColours.includes(ShellSettings.accentStops[0]) ? ShellSettings.accentStops[0] : "theme"
  function choose(name) {
    ShellSettings.set("accentStops", [name, name]);
    ShellSettings.set("accentGradient", false);
  }
  function setTarget(key, on) {
    ShellSettings.set("accentWhere", Object.assign({}, ShellSettings.accentWhere, { [key]: on }));
  }
  KitLabel { text: "OWN COLOURS"; about: "Colours you make with the plus dot, up to the limit" }
  KitRow {
    label: "Share own colours"
    hint: "Show them in every colour choice"
    KitSwitch { checked: ShellSettings.shareColours; onToggled: ShellSettings.set("shareColours", !checked) }
  }
  KitRow {
    wide: true
    label: "Own colours"
    hint: "How many can be saved"
    KitSegments {
      model: [1, 2, 3, 4, 5].map(n => ({ label: String(n), value: n }))
      current: ShellSettings.customColoursMax
      onPicked: value => ShellSettings.set("customColoursMax", value)
    }
  }
  KitLine {}
  KitLabel { text: "ACCENT" }
  KitRow {
    label: "Accent"
    hint: "Highlight active controls across the shell"
    KitSwitch { checked: ShellSettings.accent; onToggled: ShellSettings.set("accent", !checked) }
  }
  KitColourRow {
    visible: ShellSettings.accent
    label: "Colour"
    hint: "A named one, or your own"
    always: true
    names: root.names
    picked: root.selected
    colours: name => Theme.accentColour(name)
    onChosen: value => root.choose(value)
    onCustomRemoved: hex => { if (root.selected === hex) root.choose("theme"); }
  }
  KitLine { visible: ShellSettings.accent }
  KitLabel { text: "USE ACCENT ON"; visible: ShellSettings.accent }
  Repeater {
    model: root.targets
    KitRow {
      id: target
      required property var modelData
      visible: ShellSettings.accent
      label: modelData.label
      hint: modelData.hint
      KitSwitch {
        checked: ShellSettings.accentWhere[target.modelData.value] === true
        onToggled: root.setTarget(target.modelData.value, !checked)
      }
    }
  }
  KitGrouper {}
}
