import QtQuick
import qs.config
import qs.kit

// The options of one hub block, shown under its row in Hub › Blocks when the row is
// unfolded (a KitFoldRow). A block that has none is not foldable (`any`).
Column {
  id: root

  property string block: ""
  property int inset: 0                       // the options start this far in; the hairlines run the full width
  property bool shown: false                  // the row is unfolded: the options are built the first time
  property bool built: false
  onShownChanged: if (shown) built = true
  signal arrange()                              // the Hub row of Layout

  readonly property bool any: ["activities", "tiles", "week", "player", "night", "modules"].indexOf(block) >= 0

  width: parent ? parent.width : 0
  height: opts.item ? opts.item.implicitHeight : 0

  // built only once the row unfolds: every block carries these, and most are never opened
  Loader { id: opts; width: parent.width; active: root.built; sourceComponent: rowsComponent }

  Component {
    id: rowsComponent
    Item {
      width: root.width
      implicitHeight: col.implicitHeight
      height: implicitHeight

      Column {
        id: col
        x: root.inset
        width: parent.width - root.inset - Theme.gapLoose
        spacing: Theme.settingsRowInset

      KitRow {
        visible: root.block === "activities"
        wide: true
        label: "Most cards"
        hint: "The rest go to one line"
        KitSegments {
          model: [{ label: "2", value: 2 }, { label: "4", value: 4 }]
          current: ModuleSettings.get("hub", "activitiesMost", 2)
          onPicked: value => ModuleSettings.set("hub", "activitiesMost", value)
        }
      }
      KitRow {
        visible: root.block === "tiles"
        wide: true
        label: "Tiles per row"
        KitSegments {
          model: [{ label: "2 ×", value: 2 }, { label: "4 ×", value: 4 }]
          current: ModuleSettings.get("hub", "tileColumns", 2)
          onPicked: value => ModuleSettings.set("hub", "tileColumns", value)
        }
      }
      KitRow {
        visible: root.block === "modules"
        label: "Fill each row"
        hint: "Chips fill the width, extras wrap"
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
      Rectangle { visible: root.block === "modules" || root.block === "tiles"; x: -root.inset; width: root.width; height: Theme.dividerThickness; color: Theme.dividerColor }
      KitRow {
        visible: root.block === "modules" || root.block === "tiles"
        label: root.block === "tiles" ? "Which tiles" : "Which modules"
        KitButton { text: "Arrange…"; onClicked: root.arrange() }
      }
      }
    }
  }
}
