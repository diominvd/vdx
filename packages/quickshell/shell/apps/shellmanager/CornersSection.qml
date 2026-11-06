import QtQuick
import qs.config
import qs.kit

// Appearance › SHAPE (with IconsSection): sharp or round, for
// the whole shell — popups, windows, controls, rows, the island, the icons (the
// Rounded set). Round sets one radius on a ticked slider; smaller things take a
// share of it (Theme). Separately: a slider per part (windows, cards, controls,
// the bar, the hub), each read in the same proportion. The group's label lives in AppearancePage.
KitColumn {
  id: root

  readonly property var stops: Theme.cornerStops
  readonly property bool round: ShellSettings.corners === "round"

  spacing: Theme.gapGroup


  KitRow {
    wide: true
    label: "Corners"
    hint: "Every part at once, icons too"

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

  // the one slider: every part; while each part has its own it stands dimmed (turning Separately off brings it back)
  KitSliderRow {
    id: radius
    visible: root.round
    enabled: !ShellSettings.cornerSplit
    opacity: ShellSettings.cornerSplit ? 0.4 : 1
    Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
    label: "Radius"
    snaps: root.stops.map((s, i) => i / (root.stops.length - 1))
    value: root.pos(ShellSettings.cornerRadius)
    text: root.px(radius.pressed ? radius.dragValue : radius.value) + " px"
    onMoved: value => {
      const px = root.px(value);
      if (px !== ShellSettings.cornerRadius) ShellSettings.set("cornerRadius", px);
    }
  }

  // the parts, each with the px its R makes (the cards' and the previews' numbers)
  readonly property var parts: [
    { part: "windows",  label: "Windows and popups", short: "Windows",  px: r => r },
    { part: "cards",    label: "Cards and boxes",    short: "Cards",    px: r => Math.round(r * (Theme.material ? 1 : 0.6)) },
    { part: "controls", label: "Controls",           short: "Controls", px: r => Theme.scaled(Theme.controlHeight, r * Theme.softness) },
    { part: "bar",      label: "Bar",                short: "Bar",      px: r => Theme.scaled(Theme.islandHeight, r) },
    { part: "hub",      label: "Hub",                short: "Hub",      px: r => Math.round(r * 1.5) }
  ]

  // the row unfolds a slider per part under it: a Live activity's dropdown (KitReorderList of one
  // KitFoldRow); folded, its hint is what one radius makes of each part
  KitReorderList {
    id: partsList
    visible: root.round
    boxTop: false
    rowHeight: Theme.rowHeight

    keys: ["parts"]
    onOpenChanged: {
      const on = open === "parts";
      if (on !== ShellSettings.cornerSplit) ShellSettings.set("cornerSplit", on);
    }
    Component.onCompleted: open = ShellSettings.cornerSplit ? "parts" : ""
    Connections {
      target: ShellSettings
      function onCornerSplitChanged() { partsList.open = ShellSettings.cornerSplit ? "parts" : ""; }
    }

    delegate: KitFoldRow {
      id: row
      label: "Set each part"
      hint: ShellSettings.cornerSplit ? "Each part has its own radius"
                                      : root.parts.map(p => p.short + " " + p.px(ShellSettings.cornerRadius)).join(" · ")
      checked: true
      hasSwitch: false
      draggable: false
      flush: true
      foldable: true
      sunken: true

      Column {
        id: opts
        width: parent ? parent.width : 0
        spacing: Theme.settingsRowInset

        Repeater {
          model: root.parts

          Column {
            id: part
            required property var modelData
            required property int index
            readonly property int r: ShellSettings.cornerRadii[modelData.part] ?? ShellSettings.cornerRadius
            width: opts.width
            spacing: Theme.settingsRowInset

            Rectangle { visible: part.index > 0; width: parent.width; height: Theme.dividerThickness; color: Theme.dividerColor }
            KitSliderRow {
              id: slider
              x: row.indent + row.edge
              width: parent.width - 2 * x
              rowStyle: true
              label: part.modelData.label
              snaps: root.stops.map((s, i) => i / (root.stops.length - 1))
              value: root.pos(part.r)
              text: part.modelData.px(root.px(slider.pressed ? slider.dragValue : slider.value)) + " px"
              onMoved: value => {
                const px = root.px(value);
                if (px !== part.r) ShellSettings.set("cornerRadii", Object.assign({}, ShellSettings.cornerRadii, { [part.modelData.part]: px }));
              }
            }
          }
        }
      }
    }
  }

  KitGrouper {}
}
