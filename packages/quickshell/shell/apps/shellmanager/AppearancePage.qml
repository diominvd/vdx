import QtQuick
import qs.config
import qs.kit

// Interface (style, density, fields, corners), Colours and Glow: three sidebar pages on one
// full-width form. Icons, Fonts and Wallpaper are pages of their own.
KitSettingsWorkspace {
  id: root
  readonly property bool fillsViewport: true
  readonly property Item previewItem: null
  readonly property var tabs: sections
  readonly property string icon: "sliders"
  readonly property string title: "Appearance"
  readonly property string description: "The colour, shape and style of the shell."
  property string tab: "style"
  readonly property var jumps: [
    { key: "style", label: "Interface", y: 0 },
    { key: "accent", label: "Colours", y: 0 },
    { key: "glow", label: "Glow", y: 0 },
    { key: "shape", label: "Shape", y: 0 }
  ].filter(j => tab === "style" ? ["style", "shape"].includes(j.key) : j.key === tab)   // the open tab's: a sidebar page each
  function jump(key) {
    tab = key === "accent" || key === "glow" ? key : "style";
  }
  // the header's Reset: the keys of the sidebar page shown (Interface, Colours or Glow), not the other two
  readonly property var tabKeys: ({
    style: ["corners", "cornerRadius", "cornerSplit", "cornerRadii", "material", "segmentedSliders", "density", "inputAlign"],
    accent: ["accent", "accentStops", "customColours", "shareColours", "customColoursMax", "accentWhere"],
    glow: ["glow", "glowStrength", "glowWhere"]
  })
  readonly property var resetKeys: tabKeys[tab] ?? []
  readonly property bool changed: ShellSettings.changed(resetKeys)
  function reset() { ShellSettings.reset(resetKeys); }

  sections: [{label: "Interface", value: "style"}, {label: "Colours", value: "accent"}, {label: "Glow", value: "glow"}]
  current: tab
  onPicked: value => tab = value

  settings: Component {
    Column {
      width: parent.width
      Column {
  spacing: Theme.sectionGap

        width: parent.width
        visible: root.tab === "style"
        KitLabel { text: "STYLE" }
        KitRow {
          label: "Interface style"
          hint: ShellSettings.material ? "Tonal surfaces and soft controls" : "Clean outlines and compact controls"
          wide: true
          KitSegments {
            model: [{label: "Strict", value: false}, {label: "Material 3", value: true}]
            current: ShellSettings.material
            onPicked: value => ShellSettings.set("material", value)
          }
        }
        KitRow {
          visible: !ShellSettings.material
          label: "Slider style"
          hint: ShellSettings.segmentedSliders ? "Split fill and remainder" : "Classic filled track"
          wide: true
          KitSegments {
            model: [{label: "Segmented", value: true}, {label: "Classic", value: false}]
            current: ShellSettings.segmentedSliders
            onPicked: value => ShellSettings.set("segmentedSliders", value)
          }
        }
        KitRow {
          wide: true; label: "Density"; hint: "Air between and inside things"
          KitSegments { model: [{ label: "Compact", value: "compact" }, { label: "Regular", value: "regular" }, { label: "Airy", value: "airy" }]; current: ShellSettings.density; onPicked: value => ShellSettings.set("density", value) }
        }
        KitRow {
          wide: true; label: "Input text"; hint: "Where text stands in a field; Auto: left"
          KitSegments { model: [{ label: "Auto", value: "auto" }, { label: "Left", value: "left" }, { label: "Centre", value: "center" }]; current: ShellSettings.inputAlign; onPicked: value => ShellSettings.set("inputAlign", value) }
        }
        KitLine {}
        KitLabel { text: "SHAPE" }
        CornersSection { width: parent.width }
        KitGrouper {}
      }
      AccentSection { width: parent.width; visible: root.tab === "accent" }
      GlowSection { width: parent.width; visible: root.tab === "glow" }
      KitGrouper {}
    }
  }
}
