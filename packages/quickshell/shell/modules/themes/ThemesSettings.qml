import QtQuick
import qs.bar
import qs.config
import qs.kit

// Themes options in the Shell Manager: what the bar shows, how the popup
// looks and how it is driven.
Column {
  spacing: Theme.sectionGap

  KitLabel { text: "BAR" }
  BarTextRow { module: "themes" }

  KitToggleRow { visible: ModuleSettings.get("themes", "text", "content") === "content"; module: "themes"; key: "name"; fallback: true; label: "Show theme name"; hint: "Next to the brush icon" }
  KitToggleRow { module: "themes"; key: "barWheel"; fallback: true; label: "Wheel on the bar"; hint: "Switches to the next theme" }

  KitLine {}

  KitLabel { text: "POPUP" }

  KitPickerViewRow { module: "themes" }

  KitEnglishRow { module: "themes" }
  KitToggleRow { module: "themes"; key: "wheel"; fallback: true; label: "Wheel picks"; hint: "Over the cards or the list" }

  KitGrouper {}
}
