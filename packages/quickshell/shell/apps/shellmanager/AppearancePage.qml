import QtQuick
import qs.config
import qs.kit

// Interface (style, fields, corners) and Colours: sidebar pages on one
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
    { key: "shape", label: "Shape", y: 0 }
  ].filter(j => tab === "style" ? ["style", "shape"].includes(j.key) : j.key === tab)   // the open tab's: a sidebar page each
  function jump(key) {
    tab = key === "accent" ? key : "style";
  }
  // the header's Reset: the keys of the sidebar page shown (Interface or Colours), not the other
  readonly property var tabKeys: ({
    style: ["corners", "cornerRadius", "cornerSplit", "cornerRadii", "material", "segmentedSliders", "inputAlign"],
    accent: ["accent", "accentStops", "customColours", "shareColours", "customColoursMax", "accentWhere"]
  })
  readonly property var resetKeys: tabKeys[tab] ?? []
  readonly property bool changed: ShellSettings.changed(resetKeys)
  function reset() { ShellSettings.reset(resetKeys); }

  sections: [{label: "Interface", value: "style"}, {label: "Colours", value: "accent"}]
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
        StyleCards { width: parent.width }
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
          wide: true; label: "Input text"; hint: "Where text stands in a field; Auto: left"
          KitSegments { model: [{ label: "Auto", value: "auto" }, { label: "Left", value: "left" }, { label: "Centre", value: "center" }]; current: ShellSettings.inputAlign; onPicked: value => ShellSettings.set("inputAlign", value) }
        }
        KitLine {}
        KitLabel { text: "SHAPE" }
        CornersSection { width: parent.width }
        KitGrouper {}
      }
      AccentSection { width: parent.width; visible: root.tab === "accent" }
      KitGrouper {}
    }
  }
}
