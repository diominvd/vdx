import QtQuick
import qs.config
import qs.kit

// Equalizer options in the Shell Manager: one solid colour for all bars.
KitColumn {
  spacing: Theme.gapGroup

  KitLabel { text: "BAR" }

  KitColourRow {
    label: "Colour"
    hint: "One colour for all bars"
    names: Theme.colourSet
    picked: ["sea", "sunset"].includes(ModuleSettings.get("equalizer", "colour", "theme")) ? "theme" : ModuleSettings.get("equalizer", "colour", "theme")
    colours: name => Theme.equalizerColours(name)
    onChosen: value => ModuleSettings.set("equalizer", "colour", value)
  }

  KitToggleRow {
    module: "equalizer"; key: "showPaused"; fallback: true
    label: "Show when paused"; hint: "Off: shown only while it plays"
  }

  KitGrouper {}
}
