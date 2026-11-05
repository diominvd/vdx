import QtQuick
import qs.bar
import qs.bar.island
import qs.components
import qs.config
import qs.kit

// Hub (the Island style): the panel that opens from the clock — when it opens, how wide it
// is, its tiles and what it holds (the picture and name are Profile's). It was the Bar page's Hub tab; its keys are the same.
Column {
  id: root
  readonly property Item previewItem: null
  signal navigate(string tab, string target)

  readonly property string icon: "home"
  readonly property string title: "Hub"
  readonly property string description: "The panel that opens from the island's clock."
  readonly property var jumps: []

  // the hub's own keys, and the two looks it keeps beside them
  readonly property bool changed: ModuleSettings.changed("hub") || ShellSettings.looksTouched(["clockOpens", "hubPlayer"])
  function reset() { ModuleSettings.reset("hub"); ShellSettings.looksReset(["clockOpens", "hubPlayer"]); }

  // the tile modules in the hub row: what Tiles per row is for
  readonly property int tileCount: BarLayout.islandIn("tiles", BarLayout.mainScreen()).length

  spacing: Theme.sectionGap

  KitNotice {
    shown: !Theme.island
    title: "The hub belongs to the Island style"
    text: "The island is one pill with a hub and live activities. The strip has neither: these settings wait until you switch."
    action: "Use Island"
    onActed: ShellSettings.set("barStyle", "island")
  }

  KitNotice {
    shown: Theme.island && HubBlocks.shown("tiles") && root.tileCount === 0
    title: "No tile in the Hub row"
    text: "Put Wi-Fi, Bluetooth, VPN, Focus or Dark mode there."
    action: "Arrange"
    onActed: root.navigate("bar", "hubzone")
  }

  Column {
    width: parent.width
    spacing: Theme.sectionGap
    visible: Theme.island

    KitLabel { text: "SIZE" }
    KitSliderRow {
      label: "Hub width"
      snaps: [0, 0.25, 0.5, 0.75, 1]
      value: (ModuleSettings.get("hub", "width", 400) - 320) / 160
      text: Math.round(320 + (pressed ? dragValue : value) * 160) + " px"
      onMoved: value => ModuleSettings.set("hub", "width", Math.round(320 + value * 160))
    }
    KitGrouper {}
  }

  KitLine { visible: Theme.island }

  Column {
    width: parent.width
    spacing: Theme.sectionGap
    visible: Theme.island

    KitLabel { text: "BEHAVIOUR" }
    KitRow {
      label: "Opens on"
      hint: "Hover the clock, or click it"
      wide: true
      KitSegments {
        model: [{label: "Hover", value: "hover"}, {label: "Click", value: "click"}]
        current: ShellSettings.look("clockOpens", "island")
        onPicked: value => ShellSettings.setLook("clockOpens", value, "island")
      }
    }
    KitToggleRow { module: "hub"; key: "autoClose"; fallback: true; label: "Close when the pointer leaves"; hint: "Off: it stays until Escape or a click away" }
    KitSliderRow {
      visible: ModuleSettings.get("hub", "autoClose", true)
      label: "Close delay"
      snaps: [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1]
      value: (ModuleSettings.get("hub", "closeDelay", 500) - 200) / 1000
      text: ((pressed ? 200 + Math.round(dragValue * 10) * 100 : ModuleSettings.get("hub", "closeDelay", 500)) / 1000).toFixed(1) + " s"
      onMoved: value => ModuleSettings.set("hub", "closeDelay", 200 + Math.round(value * 10) * 100)
    }
    KitGrouper {}
  }

  KitLine { visible: Theme.island }

  Column {
    width: parent.width
    spacing: Theme.sectionGap
    visible: Theme.island

    KitLabel { text: "HEADER" }
    KitRow {
      wide: true
      label: "Under the time"
      hint: "Both: uptime and the date; None: the time alone"
      KitSegments {
        model: [{ label: "Both", value: "both" }, { label: "Date", value: "date" }, { label: "None", value: "none" }]
        current: ModuleSettings.get("hub", "subtitle", "both")
        onPicked: value => ModuleSettings.set("hub", "subtitle", value)
      }
    }
    KitGrouper {}
  }

  KitLine { visible: Theme.island }

  function jump(target) { blocks.jump(target); }

  Column {
    width: parent.width
    visible: Theme.island
    KitLabel { text: "ON THE HUB" }
    KitRow {
      label: "Edit on the hub"
      hint: "Arrange and add blocks on the hub itself"
      KitButton { text: "Edit…"; onClicked: IslandService.requested("hubedit", Hypr.focusedScreen?.name ?? "") }
    }
    KitGrouper {}
  }

  KitLine { visible: Theme.island }

  HubBlocksList { id: blocks; width: parent.width; visible: Theme.island; onArrange: root.navigate("bar", "hubzone") }

  KitLine { visible: Theme.island }

  KitGrouper {}
}
