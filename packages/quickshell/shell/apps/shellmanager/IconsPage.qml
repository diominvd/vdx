import QtQuick
import qs.config
import qs.kit

// Icons: the set (Material, Phosphor, Lucide, Tabler) and the style, for the whole shell.
// The icon section was Appearance › Shape; its keys are the same.
Column {
  id: root
  readonly property Item previewItem: null

  readonly property string icon: "icons"
  readonly property string title: "Icons"
  readonly property string description: "One icon set for the bar, popups and windows."
  readonly property var jumps: []

  readonly property var resetKeys: ["iconSet", "solidIcons", "menuIcons", "iconTiles"]
  readonly property bool changed: ShellSettings.changed(resetKeys)
  function reset() { ShellSettings.reset(resetKeys); }

  KitLabel { text: "ICONS"; about: "One set for everything; Lucide and Tabler use outline icons" }
  IconsSection { width: parent.width }

  KitLabel { text: "MENU"; about: "The Shell Manager's page list; the rail's group buttons keep theirs" }
  KitRow {
    label: "Framed icons"
    hint: "A tile around icons in lists"
    KitSwitch {
      accessibleName: "Framed icons"
      checked: ShellSettings.iconTiles
      onToggled: ShellSettings.set("iconTiles", !checked)
    }
  }

  KitRow {
    label: "Icons in the list"
    hint: "Off: the pages are names only"
    KitSwitch {
      accessibleName: "Icons in the list"
      checked: ShellSettings.menuIcons
      onToggled: ShellSettings.set("menuIcons", !checked)
    }
  }

  KitGrouper {}
}
