import QtQuick
import qs.config

// The options every panel app shares (Launcher, Keybinds: ModuleSettings `module`): the
// dimmed screen behind it, opening from the island (Island style only: the row stays in
// sight, KitRow.needs), then LAYOUT — rows before the list scrolls, width, where it sits.
// A section: it joins the options page's groups (its own KitGrouper).
Column {
  id: root

  required property string module

  width: parent ? parent.width : 0
  spacing: Theme.sectionGap

  // the screen behind the panel: in the window, and behind the island's view
  KitToggleRow {
    module: root.module; key: "dim"; fallback: true
    label: "Dim the background"
    hint: "Off: the screen behind it stays as it is"
  }

  KitLine {}

  // Island style: the panel opens from the island, inside it, like a module's popup
  KitLabel { text: "ISLAND" }

  KitToggleRow {
    needs: ShellSettings.barStyle === "island" ? "" : "Island style only"
    needsAction: "Use Island"
    onNeedsActed: ShellSettings.set("barStyle", "island")
    module: root.module; key: "island"; fallback: true
    label: "Open from the island"
    hint: "On: inside the island, not a window"
  }

  KitLine {}

  KitLabel { text: "LAYOUT" }

  KitOptionRow {
    module: root.module; key: "rows"; fallback: 8
    label: "Visible rows"; hint: "The rest scrolls"
    model: [6, 8, 10, 12].map(v => ({ label: String(v), value: v }))
  }

  KitOptionRow {
    module: root.module; key: "size"; fallback: "medium"
    label: "Width"; hint: ""
    model: [{ label: "Small", value: "small" }, { label: "Medium", value: "medium" }, { label: "Large", value: "large" }]
  }

  KitOptionRow {
    module: root.module; key: "position"; fallback: "top"
    label: "Position"; hint: ""
    model: [{ label: "Top", value: "top" }, { label: "Centre", value: "center" }, { label: "Bottom", value: "bottom" }]
  }

  KitGrouper {}
}
