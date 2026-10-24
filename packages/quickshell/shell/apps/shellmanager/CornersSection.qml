import QtQuick
import qs.config
import qs.kit

// Appearance › SHAPE (with IconsSection): sharp or round, for
// the whole shell — popups, windows, controls, rows, the island, the icons (the
// Rounded set). Round sets one radius on a ticked slider; smaller things take a
// share of it (Theme). Separately: a slider per part (windows, cards, controls,
// the bar), each read in the same proportion. The group's label lives in AppearancePage.
KitColumn {
  id: root

  readonly property var stops: Theme.cornerStops
  readonly property bool round: ShellSettings.corners === "round"

  spacing: Theme.gapGroup

  KitRow {
    wide: true
    label: "Corners"
    hint: "Also windows and toasts; Round rounds the icons"

    KitSegments {
      model: [
        { label: "Sharp", value: "sharp" },
        { label: "Round", value: "round" }
      ]
      current: ShellSettings.corners
      onPicked: value => ShellSettings.set("corners", value)
    }
  }

  // a radius on the ticks: index <-> px
  function pos(px) { return Math.max(0, stops.indexOf(px)) / (stops.length - 1); }
  function px(p) { return stops[Math.round(p * (stops.length - 1))]; }

  // the one slider: every part; hidden with Separately (turning it off brings this one back)
  KitSliderRow {
    id: radius
    visible: root.round && !ShellSettings.cornerSplit
    label: "Radius"
    snaps: root.stops.map((s, i) => i / (root.stops.length - 1))
    value: root.pos(ShellSettings.cornerRadius)
    text: root.px(radius.pressed ? radius.dragValue : radius.value) + " px"
    onMoved: value => {
      const px = root.px(value);
      if (px !== ShellSettings.cornerRadius) ShellSettings.set("cornerRadius", px);
    }
  }

  KitRow {
    visible: root.round
    label: "Separately"
    hint: "A slider per part, in one proportion"

    KitSwitch {
      accessibleName: "Separately"
      checked: ShellSettings.cornerSplit
      onToggled: ShellSettings.set("cornerSplit", !ShellSettings.cornerSplit)
    }
  }

  // a part on its own: the same tick looks the same on every part (the px differ)
  Repeater {
    model: [
      { part: "windows",  label: "Windows and popups", px: r => r },
      { part: "cards",    label: "Cards and boxes",    px: r => Math.round(r * 0.6) },
      { part: "controls", label: "Controls",           px: r => Theme.scaled(Theme.controlHeight, r) },
      { part: "bar",      label: "Bar",                px: r => Theme.scaled(Theme.islandHeight, r) }
    ]

    KitSliderRow {
      id: part
      required property var modelData
      readonly property int r: ShellSettings.cornerRadii[modelData.part] ?? ShellSettings.cornerRadius
      visible: root.round && ShellSettings.cornerSplit
      label: modelData.label
      snaps: root.stops.map((s, i) => i / (root.stops.length - 1))
      value: root.pos(r)
      text: modelData.px(root.px(part.pressed ? part.dragValue : part.value)) + " px"
      onMoved: value => {
        const px = root.px(value);
        if (px !== r) ShellSettings.set("cornerRadii", Object.assign({}, ShellSettings.cornerRadii, { [modelData.part]: px }));
      }
    }
  }

  KitGrouper {}
}
