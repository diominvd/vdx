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

  // dim, island, layout: as every panel app
  KitPanelOptions { module: "keybinds" }

  KitLine {}

  KitLabel { text: "OPENING" }

  KitOptionRow {
    module: "keybinds"; key: "opens"; fallback: "mode"
    label: "Opens on"; hint: "The tab shown first"
    model: [{ label: "Mode", value: "mode" }, { label: "Windows", value: "windows" }, { label: "Desktop", value: "desktop" }, { label: "Media", value: "media" }]
  }

  KitClearSearchRow { module: "keybinds" }

  KitEnglishRow { module: "keybinds" }

  KitGrouper {}
}
