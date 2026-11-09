import QtQuick
import qs.config
import qs.kit

// Icons: the icon set for the whole shell — Material, Phosphor or Mingcute
// (outline or solid), or Lucide / Tabler (outline only) — and the style.
KitColumn {
  spacing: Theme.gapGroup

  KitRow {
    wide: true
    label: "Icon set"
    hint: "Everywhere in the shell"

    KitSegments {
      model: [
        { label: "Material", value: "material" },
        { label: "Phosphor", value: "phosphor" },
        { label: "Lucide",   value: "lucide" },
        { label: "Tabler",   value: "tabler" },
        { label: "Mingcute", value: "mingcute" }
      ]
      current: ShellSettings.iconSet
      onPicked: value => ShellSettings.set("iconSet", value)
    }
  }

  KitRow {
    wide: true
    visible: !["lucide", "tabler"].includes(ShellSettings.iconSet)
    label: "Icon style"

    KitSegments {
      model: [
        { label: "Outline", value: false },
        { label: "Solid",   value: true }
      ]
      current: ShellSettings.solidIcons
      onPicked: value => ShellSettings.set("solidIcons", value)
    }
  }

  KitGrouper {}
}
