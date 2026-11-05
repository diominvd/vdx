import QtQuick
import Quickshell
import qs.config
import qs.kit

// How one of the shell's windows opens (Apps › WINDOW): Window (floating / tiled)
// and, floating, Size (its own, a preset share of the screen, custom pixels) and
// Position (a spot on the screen, at the pointer, custom x, y). Choices apply at once, numbers on Enter; it shows the next
// time the window opens.
KitColumn {
  id: root

  required property var app                 // ShellAppsService.windows entry
  property bool labelled: true              // its WINDOW label (a dialog has a header)

  readonly property var s: app.settings
  readonly property bool floating: s.mode !== "tiled"
  readonly property bool screenSpot: s.position !== "cursor" && s.position !== "custom"
  readonly property var px: ShellAppsService.sizeOf(app, s)

  // the numbers being typed, until Enter
  property string wDraft: String(s.width)
  property string hDraft: String(s.height)
  property string xDraft: String(s.x)
  property string yDraft: String(s.y)

  function set(change) { ShellAppsService.set(app, change); }

  spacing: Theme.gapGroup

  KitLabel {
    visible: root.labelled
    text: "WINDOW"
    value: root.floating ? ("FLOATING · " + root.px[0] + " × " + root.px[1]) : "TILED"
  }

  KitRow {
    wide: true
    label: "Window"
    hint: root.floating ? "Over others, where you put it" : "Takes its place in the layout"

    KitSegments {
      model: [{ label: "Floating", value: "floating" }, { label: "Tiled", value: "tiled" }]
      current: root.s.mode
      onPicked: value => root.set({ mode: value })
    }
  }

  KitRow {
    visible: root.floating
    wide: true
    label: "Size"
    hint: root.s.size === "preset" ? "A share of the screen"
        : root.s.size === "custom" ? "Your own, in pixels" : root.app.width + " × " + root.app.height + ", the app's own"

    KitSegments {
      model: [{ label: "Default", value: "default" }, { label: "Preset", value: "preset" }, { label: "Custom", value: "custom" }]
      current: root.s.size
      onPicked: value => root.set({ size: value })
    }
  }

  KitRow {
    visible: root.floating && root.s.size === "preset"
    wide: true
    label: "Preset"
    hint: {
      const p = ShellAppsService.presets[root.s.preset] ?? [0, 0];
      return Math.round(p[0] * 100) + " × " + Math.round(p[1] * 100) + "% of the screen";
    }

    KitSegments {
      model: [{ label: "Small", value: "small" }, { label: "Medium", value: "medium" }, { label: "Large", value: "large" }]
      current: root.s.preset
      onPicked: value => root.set({ preset: value })
    }
  }

  PairRow {
    visible: root.floating && root.s.size === "custom"
    label: "Width × height"
    hint: valid ? "Press Enter to apply" : "At least " + ShellAppsService.minWidth + " × " + ShellAppsService.minHeight
    first: root.wDraft
    second: root.hDraft
    onEdited: (a, b) => { root.wDraft = a; root.hDraft = b; }
    onAccepted: (a, b) => root.set({ size: "custom", width: a, height: b })
  }

  KitRow {
    visible: root.floating
    wide: true
    label: "Position"
    hint: root.s.position === "cursor" ? "Centred on the pointer"
        : root.s.position === "custom" ? "Exact screen coordinates" : "A spot on the screen"

    KitSegments {
      model: [{ label: "Screen", value: "screen" }, { label: "Pointer", value: "cursor" }, { label: "Custom", value: "custom" }]
      current: root.screenSpot ? "screen" : root.s.position
      onPicked: value => root.set({ position: value === "screen" ? (ShellAppsService.spots[root.s.position] ? root.s.position : "center") : value })
    }
  }

  // the nine spots, in reading order
  KitSelect {
    visible: root.floating && root.screenSpot
    label: "Spot"
    hint: "Where on the screen it opens"
    model: [["top-left", "Top left"], ["top", "Top"], ["top-right", "Top right"],
            ["left", "Left"], ["center", "Centre"], ["right", "Right"],
            ["bottom-left", "Bottom left"], ["bottom", "Bottom"], ["bottom-right", "Bottom right"]]
      .map(p => ({ label: p[1], value: p[0] }))
    current: root.s.position
    onPicked: value => root.set({ position: value })
  }

  PairRow {
    visible: root.floating && root.s.position === "custom"
    label: "X, Y"
    hint: valid ? "Enter applies; kept on screen" : "Whole pixels"
    separator: ","
    first: root.xDraft
    second: root.yDraft
    onEdited: (a, b) => { root.xDraft = a; root.yDraft = b; }
    onAccepted: (a, b) => root.set({ position: "custom", x: a, y: b })
  }

  KitText {
    width: parent.width
    visible: ShellAppsService.error !== "" && ShellAppsService.errorApp === root.app.id
    text: ShellAppsService.error
    color: Theme.red
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSize - 1
  }

  KitGrouper {}
}
