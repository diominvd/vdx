import QtQuick
import qs.config
import qs.kit

// Icons, in the Themes frame: the sets on the left (three of its icons, the name, a check on
// the one in use), the picked set on the right as the shell draws it — a sheet of icons, the
// style and the menu's two switches at the card's foot. A pick applies at once: the sheet is
// the live result, not a second preview.
KitPicker {
  id: root

  readonly property string icon: "icons"
  readonly property string title: "Icons"
  readonly property string description: "One icon set for the bar, popups and windows."
  readonly property var jumps: []
  readonly property var resetKeys: ["iconSet", "solidIcons", "menuIcons", "iconTiles"]
  readonly property bool changed: ShellSettings.changed(resetKeys)
  function reset() { ShellSettings.reset(resetKeys); }

  readonly property var sets: [
    { key: "material", label: "Material Symbols", sub: "Outline · solid" },
    { key: "phosphor", label: "Phosphor", sub: "Outline · solid" },
    { key: "mingcute", label: "Mingcute", sub: "Outline · solid" },
    { key: "lucide",   label: "Lucide",   sub: "Outline only" },
    { key: "tabler",   label: "Tabler",   sub: "Outline only" }
  ]
  readonly property bool hasStyle: !["lucide", "tabler"].includes(ShellSettings.iconSet)
  readonly property var current: sets.find(s => s.key === ShellSettings.iconSet) ?? sets[0]

  selected: ShellSettings.iconSet
  marked: ShellSettings.iconSet
  placeholder: "Search icon sets"
  emptyIcon: "icons"
  emptyTitle: "No matching sets"
  model: sets
  thumbWidth: 44
  thumb: Component {
    Rectangle {
      property var entry: ({})
      radius: Theme.radiusControl
      color: Theme.background0
      border.width: Theme.hairline
      border.color: Theme.controlLine
      KitIcon {
        anchors.centerIn: parent
        set: parent.entry.key ?? "material"
        name: "settings"
        size: 20
        tint: Theme.foreground0
      }
    }
  }
  onPicked: key => ShellSettings.set("iconSet", key)
  Component.onCompleted: visibleChanged()
  onVisibleChanged: if (visible) search.input.forceActiveFocus()

  KitPickerHead {
    id: head
    title: root.current.label
    phase: "inuse"

    KitLabel { text: "STYLE"; visible: false }      // the search index finds the group by it
    KitPickerOption {
      label: "Style"
      dimmed: !root.hasStyle
      KitSegments {
        width: parent.width
        disabled: !root.hasStyle
        model: [{ label: "Outline", value: false }, { label: "Solid", value: true }]
        current: root.hasStyle ? ShellSettings.solidIcons : false
        onPicked: value => ShellSettings.set("solidIcons", value)
      }
    }
    KitPickerOption {
      label: "List icons"
      KitSegments {
        width: parent.width
        model: [{ label: "Off", value: "off" }, { label: "Plain", value: "plain" }, { label: "Framed", value: "framed" }]
        current: !ShellSettings.menuIcons ? "off" : ShellSettings.iconTiles ? "framed" : "plain"
        onPicked: value => {
          ShellSettings.set("menuIcons", value !== "off");
          if (value !== "off") ShellSettings.set("iconTiles", value === "framed");
        }
      }
    }
  }

  Rectangle {
    id: well
    width: parent.width
    height: parent.height - y
    radius: Theme.radiusCard
    color: Theme.background0
    border.width: Theme.hairline
    border.color: Theme.controlLine
    clip: true

    IconScene {
      anchors { fill: parent; margins: Theme.gapGroup }
    }
  }
}
