import QtQuick
import qs.config
import qs.kit

// Appearance › SHAPE, under the corners: Phosphor Regular or Fill icons for
// the whole shell. The existing solidIcons setting remains the compatibility key.
Column {
  spacing: Theme.gapGroup

  KitRow {
    wide: true
    label: "Icons"
    hint: "Phosphor weight · Regular or Fill"

    KitSegments {
      accessibleName: "Icon weight"
      model: [
        { label: "Regular", value: false },
        { label: "Fill",    value: true }
      ]
      current: ShellSettings.solidIcons
      onPicked: value => ShellSettings.set("solidIcons", value)
    }
  }

  KitGrouper {}
}
