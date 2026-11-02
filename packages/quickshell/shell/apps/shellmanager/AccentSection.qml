import QtQuick
import qs.config
import qs.kit

// One accent colour, independently enabled for each UI target.
KitColumn {
  id: root

  spacing: Theme.sectionGap
  readonly property var names: ["theme", "red", "orange", "yellow", "green", "aqua", "blue", "purple"]
  readonly property var targets: [
    { value: "switches", label: "Switches", hint: "On switches" },
    { value: "sliders", label: "Sliders", hint: "Filled track" },
    { value: "choices", label: "Choices", hint: "Selected option" },
    { value: "selects", label: "Dropdowns", hint: "Selected field" },
    { value: "window", label: "Window frames", hint: "Focused window" }
  ]
  readonly property string selected: names.includes(ShellSettings.accentStops[0]) || ShellSettings.customColours.includes(ShellSettings.accentStops[0]) ? ShellSettings.accentStops[0] : "theme"

  function choose(name) {
    ShellSettings.set("accentStops", [name, name]);
  }
  function setTarget(key, on) {
    ShellSettings.set("accentWhere", Object.assign({}, ShellSettings.accentWhere, { [key]: on }));
  }

  KitLabel { text: "ACCENT" }
  KitRow {
    label: "Accent colour"
    hint: "Active and selected controls"
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

  KitLabel { text: "ACCENT TARGETS"; visible: ShellSettings.accent }
  Repeater {
    model: root.targets
    delegate: KitRow {
      required property var modelData
      width: parent.width
      label: modelData.label
      hint: modelData.hint
      visible: ShellSettings.accent
      KitSwitch {
        checked: ShellSettings.accentWhere[modelData.value] === true
        onToggled: root.setTarget(modelData.value, !checked)
      }
    }
  }

  KitLine {}
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
  KitGrouper {}
}
