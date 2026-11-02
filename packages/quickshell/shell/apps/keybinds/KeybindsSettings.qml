import QtQuick
import qs.config
import qs.kit

// Keybinds options in Shell apps (ModuleSettings "keybinds"; the panel itself
// is apps/keybinds/Keybinds.qml, Super+B): the panel as the launcher's — rows
// before the list scrolls, its width and where it sits — then the tab it
// opens on and the search's clearing.
Column {
  id: root

  spacing: Theme.sectionGap

  // the screen behind the panel: in the window, and behind the island's view
  KitToggleRow {
    module: "keybinds"; key: "dim"; fallback: true
    label: "Dim the background"
    hint: "Off: the screen behind it stays as it is"
  }

  // Island style: the window opens from the island, inside it, like a module's popup
  KitLabel { text: "ISLAND"; visible: ShellSettings.barStyle === "island" }
  KitToggleRow {
    needs: ShellSettings.barStyle === "island" ? "" : "Island style only"
    needsAction: "Use Island"
    onNeedsActed: ShellSettings.set("barStyle", "island")
    module: "keybinds"; key: "island"; fallback: true
    label: "Open from the island"
    hint: "On: opens inside the island, not a window"
  }

  KitLabel { text: "LAYOUT" }

  KitOptionRow {
    module: "keybinds"; key: "rows"; fallback: 8
    label: "Visible rows"; hint: "The rest scrolls"
    model: [6, 8, 10, 12].map(v => ({ label: String(v), value: v }))
  }

  KitOptionRow {
    module: "keybinds"; key: "size"; fallback: "medium"
    label: "Width"; hint: ""
    model: [{ label: "Small", value: "small" }, { label: "Medium", value: "medium" }, { label: "Large", value: "large" }]
  }

  KitOptionRow {
    module: "keybinds"; key: "position"; fallback: "top"
    label: "Position"; hint: ""
    model: [{ label: "Top", value: "top" }, { label: "Centre", value: "center" }, { label: "Bottom", value: "bottom" }]
  }

  KitLine {}

  KitLabel { text: "OPENING" }

  KitOptionRow {
    module: "keybinds"; key: "opens"; fallback: "mode"
    label: "Opens on"; hint: "The tab shown first"
    model: [{ label: "Mode", value: "mode" }, { label: "Windows", value: "windows" }, { label: "Desktop", value: "desktop" }, { label: "Media", value: "media" }]
  }

  KitToggleRow { module: "keybinds"; key: "clear"; fallback: true; label: "Clear search on close"; hint: "Off: the search stays as it was" }

  KitToggleRow { module: "keybinds"; key: "english"; fallback: true; label: "English layout on open"; hint: "Switches the keyboard when it opens" }

  KitGrouper {}
}
