import QtQuick
import qs.bar
import qs.config
import qs.kit

// Wallpapers options in the Shell Manager: what the bar shows, how the popup
// looks and how it is driven.
Column {
  spacing: Theme.sectionGap

  KitLabel { text: "BAR" }
  BarTextRow { module: "wallpapers" }

  KitToggleRow { visible: ModuleSettings.get("wallpapers", "text", "content") === "content"; module: "wallpapers"; key: "name"; fallback: false; label: "Show picture name"; hint: "Next to the image icon" }
  KitToggleRow { module: "wallpapers"; key: "barWheel"; fallback: true; label: "Wheel on the bar"; hint: "Switches to the next picture" }

  KitLine {}

  KitLabel { text: "POPUP" }

  KitPickerViewRow { module: "wallpapers" }

  KitEnglishRow { module: "wallpapers" }
  KitToggleRow { module: "wallpapers"; key: "wheel"; fallback: true; label: "Wheel picks"; hint: "Over the cards or the list" }

  KitLine {}

  KitLinkRow {
    label: "Wallpaper"
    hint: "The popup switches; set it in Appearance"
    target: "appearance:wallpaper"
  }

  KitGrouper {}
}
