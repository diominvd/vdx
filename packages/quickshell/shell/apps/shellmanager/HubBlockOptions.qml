import QtQuick
import qs.config
import qs.kit

// The options of one hub block, shown under its row in Hub › Blocks when the row is
// unfolded (a KitFoldRow). A block that has none is not foldable (`any`).
Column {
  id: root

  property string block: ""
  signal arrange()                              // the Hub row of Layout

  readonly property bool any: ["tiles", "week", "player", "night", "modules"].indexOf(block) >= 0

  width: parent ? parent.width : 0
  spacing: Theme.settingsRowInset

  KitRow {
    visible: root.block === "tiles"
    wide: true
    label: "Shown as"
    hint: "Discs: a row of states, filled when on"
    KitSegments {
      model: [{ label: "Discs", value: 6 }, { label: "Tiles 2 ×", value: 2 }, { label: "Tiles 4 ×", value: 4 }]
      current: ModuleSettings.get("hub", "tileColumns", 6)
      onPicked: value => ModuleSettings.set("hub", "tileColumns", value)
    }
  }
  KitRow {
    visible: root.block === "modules"
    label: "Rings"
    hint: "A module with a whole as a ring; off: chips"
    KitSwitch {
      checked: ModuleSettings.get("hub", "chipsRings", true)
      onToggled: ModuleSettings.set("hub", "chipsRings", !checked)
    }
  }
  KitRow {
    visible: root.block === "modules"
    label: "Fill each row"
    hint: "Chips stretch to the width; extras wrap"
    KitSwitch {
      checked: ModuleSettings.get("hub", "chipsFill", true)
      onToggled: ModuleSettings.set("hub", "chipsFill", !checked)
    }
  }
  KitRow {
    visible: root.block === "week"
    wide: true
    label: "Shows"
    KitSegments {
      model: [{ label: "Week", value: "week" }, { label: "Month", value: "month" }]
      current: ModuleSettings.get("hub", "calendarMode", "week")
      onPicked: value => ModuleSettings.set("hub", "calendarMode", value)
    }
  }
  KitRow {
    visible: root.block === "player"
    wide: true
    label: "Player size"
    KitSegments {
      model: [{ label: "Card", value: "card" }, { label: "Compact", value: "compact" }]
      current: ModuleSettings.get("hub", "playerSize", "card")
      onPicked: value => ModuleSettings.set("hub", "playerSize", value)
    }
  }
  KitRow {
    visible: root.block === "night"
    wide: true
    label: "Shown"
    KitSegments {
      model: [{ label: "Always", value: false }, { label: "With night mode", value: true }]
      current: ModuleSettings.get("hub", "nightAuto", true)
      onPicked: value => ModuleSettings.set("hub", "nightAuto", value)
    }
  }
  KitRow {
    visible: root.block === "modules" || root.block === "tiles"
    label: root.block === "tiles" ? "Which tiles" : "Which modules"
    KitButton { text: "Arrange…"; onClicked: root.arrange() }
  }
}
