import QtQuick
import qs.config
import qs.kit
import "../../kit/colour.js" as Colour

// Appearance › ACCENT: on or off (monochrome when off). On: Fill (Solid or
// Gradient), then one row for the colours: a field per stop (Gradient: From and
// To, side by side, with a swap between them). A field's chip or chevron opens
// the picker under the row, for that stop only. Then where the accent goes
// (APPLIES TO). The rows under the switch fade in and out.
KitColumn {
  id: root

  readonly property var names: ["theme", "red", "orange", "yellow", "green", "aqua", "blue", "purple", "custom"]
  readonly property var targets: [
    { value: "switches",   label: "Switches",      hint: "The ones that are on" },
    { value: "sliders",    label: "Sliders",       hint: "The filled part" },
    { value: "choices",    label: "Choices",       hint: "The picked one" },
    { value: "selects",    label: "Dropdowns",     hint: "The open one's frame" },
    { value: "modules",    label: "Bar modules",   hint: "Active states, the equalizer; not warnings" }
  ]
  readonly property var onKeys: targets.map(t => t.value).filter(k => ShellSettings.accentWhere[k] === true)
  readonly property var stops: ShellSettings.accentStops
  readonly property bool gradient: ShellSettings.accentGradient

  // the stop whose picker is open (0 From, 1 To), -1 none
  property int active: -1

  function colourOf(name, slot) { return Theme.accentColour(name, slot); }
  // a stop's colour as its field shows it
  function hexOf(slot) { return Colour.hexOfColour(colourOf(stops[slot] ?? "theme", slot)); }
  // "THEME", "BLUE", "#D79921": a stop as the group's value (caps)
  function caps(slot) {
    const name = stops[slot] ?? "theme";
    if (name === "custom") return (ShellSettings.accentCustom[slot] || hexOf(slot)).toUpperCase();
    return name === "theme" ? "THEME" : name.toUpperCase();
  }
  // "Theme", "Blue", "Custom": a stop's name as a hint (sentence case)
  function nameOf(name) {
    return name === "custom" ? "Custom" : name.charAt(0).toUpperCase() + name.slice(1);
  }
  // the palette's next colour after `name`, for a new gradient's end
  function neighbour(name) {
    const palette = names.slice(0, -1);
    const next = palette[(palette.indexOf(name) + 1) % palette.length];
    return next === name ? "purple" : next;
  }

  function setStop(slot, name) {
    const next = stops.slice();
    next[slot] = name;
    ShellSettings.set("accentStops", next);
  }

  // a typed or dragged colour is that stop's own custom colour
  function setCustom(slot, colour) {
    const custom = ShellSettings.accentCustom.slice();
    custom[slot] = colour;
    ShellSettings.set("accentCustom", custom);
    setStop(slot, "custom");
  }

  function choose(slot, name) {
    setStop(slot, name);
    if (name === "custom" && !ShellSettings.accentCustom[slot]) setCustom(slot, hexOf(slot));
  }

  function setGradient(on) {
    ShellSettings.set("accentGradient", on);
    if (!on) { active = active === 1 ? -1 : active; }
    // a gradient starts from a colour next to the first one, so the change shows at once
    if (on && stops[1] === stops[0]) setStop(1, neighbour(stops[0]));
  }

  // the ends trade places, typed values with them
  function swap() {
    ShellSettings.set("accentStops", [stops[1] ?? "theme", stops[0]]);
    ShellSettings.set("accentCustom", [ShellSettings.accentCustom[1], ShellSettings.accentCustom[0]]);
  }

  function toggle(slot) { active = active === slot ? -1 : slot; }

  function setTarget(key, on) {
    ShellSettings.set("accentWhere", Object.assign({}, ShellSettings.accentWhere, { [key]: on }));
  }

  spacing: Theme.gapGroup

  KitLabel {
    width: parent.width
    text: "ACCENT"
    value: !ShellSettings.accent ? "OFF"
      : caps(0) + (root.gradient ? " → " + caps(1) : "") + " · " + onKeys.length + " OF " + targets.length
  }

  KitRow {
    label: "Accent"
    hint: "Off: monochrome"

    KitSwitch {
      accessibleName: "Accent"
      checked: ShellSettings.accent
      onToggled: ShellSettings.set("accent", !ShellSettings.accent)
    }
  }

  KitRow {
    visible: ShellSettings.accent
    wide: true
    label: "Fill"

    KitSegments {
      model: [
        { label: "Solid", value: false },
        { label: "Gradient", value: true }
      ]
      current: root.gradient
      onPicked: value => root.setGradient(value)
    }
  }

  // the colours: one field, or From | swap | To. The row holds only the fields, so
  // its label sits level with them; the picker opens as a block under the row
  KitRow {
    visible: ShellSettings.accent
    wide: true
    label: root.gradient ? "Gradient" : "Colour"
    hint: root.gradient ? "Click a field to edit it" : root.nameOf(root.stops[0] ?? "theme")

    Row {
      id: fields
      spacing: Theme.gapSmall

      KitColourField {
        id: fromField
        width: root.gradient ? Math.max(0, (fields.width - swapButton.width - 2 * fields.spacing) / 2) : Math.max(0, fields.width)
        value: root.hexOf(0)
        placeholder: "#d79921"
        live: true
        open: root.active === 0
        onAccepted: colour => root.setCustom(0, colour)
        onChipClicked: root.toggle(0)
      }

      KitButton {
        id: swapButton
        visible: root.gradient
        anchors.verticalCenter: fromField.verticalCenter
        icon: "shuffle"
        iconTint: Theme.foreground2
        onClicked: root.swap()
      }

      KitColourField {
        id: toField
        visible: root.gradient
        width: Math.max(0, (fields.width - swapButton.width - 2 * fields.spacing) / 2)
        value: root.hexOf(1)
        placeholder: "#d79921"
        live: true
        open: root.active === 1
        onAccepted: colour => root.setCustom(1, colour)
        onChipClicked: root.toggle(1)
      }
    }
  }

  KitColourPicker {
    visible: ShellSettings.accent && root.active >= 0
    width: parent.width
    colour: root.active >= 0 ? root.hexOf(root.active) : ""
    palette: root.names
    icons: name => name === "theme" ? "palette" : name === "custom" ? "brush" : ""
    picked: root.active >= 0 ? root.stops[root.active] ?? "" : ""
    colours: name => [root.colourOf(name, root.active), root.colourOf(name, root.active)]
    onMoved: hex => root.setCustom(root.active, hex)
    onReleased: hex => root.setCustom(root.active, hex)
    onChosen: name => root.choose(root.active, name)
  }

  KitLabel {
    visible: ShellSettings.accent
    width: parent.width
    text: "APPLIES TO"
    value: root.onKeys.length + " OF " + root.targets.length
  }

  Repeater {
    model: root.targets

    KitRow {
      id: target
      visible: ShellSettings.accent
      readonly property bool targetOn: ShellSettings.accentWhere[modelData.value] === true

      label: modelData.label
      hint: modelData.hint

      KitSwitch {
        accessibleName: modelData.label
        checked: target.targetOn
        onToggled: root.setTarget(modelData.value, !target.targetOn)
      }
    }
  }

  KitGrouper {}
}
