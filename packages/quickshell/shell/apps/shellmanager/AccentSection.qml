import QtQuick
import qs.config
import qs.kit

// One accent colour, independently enabled for each UI target. The windows' frame
// (its place "window") is chosen in Windows › Look (Frames: off | theme | accent).
Column {
  id: root

  spacing: Theme.sectionGap
  readonly property var names: ["theme", "red", "orange", "yellow", "green", "aqua", "blue", "purple"]
  readonly property var targets: [
    { value: "switches", sample: "switch", label: "Switches", hint: "On switches" },
    { value: "sliders", sample: "slider", label: "Sliders", hint: "Filled track" },
    { value: "choices", sample: "choices", label: "Choices", hint: "Selected option" },
    { value: "selects", sample: "select", label: "Dropdowns", hint: "Selected field" }
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
  // One clipped section owns its geometry, including its card backgrounds.
  Item {
    id: accentOptions
    property bool kitUnboxed: true
    property real reveal: ShellSettings.accent ? 1 : 0
    width: parent.width
    // Keep a minimal layout slot: removing a zero-height child also removes
    // Column spacing and changes the following caption's group inset.
    height: Math.max(1, (Theme.settingsRowInset + options.implicitHeight) * reveal)
    enabled: ShellSettings.accent
    clip: true
    opacity: reveal
    Behavior on reveal { enabled: Motion.controls; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }

    Column {
      id: options
      // The grouper draws the first card above its row by this inset.
      y: Theme.settingsRowInset
      width: parent.width
      spacing: Theme.sectionGap
      KitColourRow {
        label: "Colour"
        hint: "A named one, or your own"
        always: true
        names: root.names
        picked: root.selected
        colours: name => Theme.accentColour(name)
        onChosen: value => root.choose(value)
        onCustomRemoved: hex => { if (root.selected === hex) root.choose("theme"); }
      }

      KitLabel {
        text: "ACCENT TARGETS"
      }
      Item {
        id: tiles
        property bool kitUnboxed: true               // KitGrouper: stands on the page
        width: parent.width
        height: grid.height
        readonly property int columns: width >= 560 ? 4 : 2

        Grid {
          id: grid
          width: parent.width
          columns: tiles.columns
          spacing: Theme.gapMedium
          readonly property real cell: (width - (tiles.columns - 1) * spacing) / tiles.columns

          Repeater {
            model: root.targets
            delegate: KitTargetTile {
              required property var modelData
              width: grid.cell
              sample: modelData.sample
              label: modelData.label
              hint: modelData.hint
              checked: ShellSettings.accentWhere[modelData.value] === true
              onToggled: root.setTarget(modelData.value, !checked)
            }
          }
        }
      }
      KitGrouper {}
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
