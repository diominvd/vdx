import QtQuick
import qs.config
import qs.kit

// Interface (style, fields and corners) and Colours share the bounded settings form.
// Icons, Fonts and Wallpaper are pages of their own.
KitSettingsWorkspace {
  id: root
  readonly property bool fillsViewport: true
  readonly property Item previewItem: null
  readonly property var tabs: sections
  readonly property string icon: "sliders"
  readonly property string title: "Appearance"
  readonly property string description: "Style, shape and control layout preferences."
  property string tab: "interface"
  readonly property var jumps: [
    { key: "interface", label: "Interface", y: 0 },
    { key: "accent", label: "Colours", y: 0 },
    { key: "shape", label: "Shape", y: 0 }
  ].filter(j => tab === "interface" ? ["interface", "shape"].includes(j.key) : j.key === tab)   // the open tab's: a sidebar page each
  function jump(key) {
    tab = key === "accent" ? key : "interface";
  }
  // the header's Reset: the keys of the sidebar page shown (Interface or Colours), not the other
  readonly property var tabKeys: ({
    interface: ["material", "corners", "cornerRadius", "cornerSplit", "cornerRadii", "segmentedSliders", "inputAlign"],
    accent: ["accent", "accentStops", "customColours", "shareColours", "customColoursMax", "accentWhere"]
  })
  readonly property var resetKeys: tabKeys[tab] ?? []
  readonly property bool changed: ShellSettings.changed(resetKeys)
  function reset() { ShellSettings.reset(resetKeys); }

  sections: [{label: "Interface", value: "interface"}, {label: "Colours", value: "accent"}]
  current: tab
  onPicked: value => tab = value

  settings: Component {
    Column {
      width: parent.width
      Column {
        spacing: Theme.sectionGap
        width: parent.width
        visible: root.tab === "interface"
        KitLabel { text: "STYLE" }
        KitRow {
          label: "Interface style"
          hint: "Strict outlines or Material 3 surfaces"
          wide: true
          KitSegments {
            model: [{ label: "Strict", value: "strict" }, { label: "Material 3", value: "material" }]
            current: ShellSettings.material ? "material" : "strict"
            onPicked: value => ShellSettings.set("material", value === "material")
          }
        }
        KitLine {}
        KitLabel { text: "SHAPE"; about: "Corners used throughout the shell" }
        CornersSection { width: parent.width }
        KitLine {}
        KitLabel { text: "CONTROLS" }
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
          wide: true; label: "Input text"; hint: "Text position, Auto is left"
          KitSegments { model: [{ label: "Auto", value: "auto" }, { label: "Left", value: "left" }, { label: "Centre", value: "center" }]; current: ShellSettings.inputAlign; onPicked: value => ShellSettings.set("inputAlign", value) }
        }
        KitGrouper {}
      }
      AccentSection { width: parent.width; visible: root.tab === "accent" }
      KitGrouper {}
    }
  }
}
