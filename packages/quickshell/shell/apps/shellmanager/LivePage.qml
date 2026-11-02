import QtQuick
import qs.config
import qs.kit

// Live activities (the Island style): what grows out of the pill while something runs, in
// priority order, and the rules for all of them. It was the Bar page's Live tab; its keys
// are the same.
Column {
  id: root
  readonly property Item previewItem: null

  readonly property string icon: "activity"
  readonly property string title: "Live activities"
  readonly property string description: "What grows out of the pill while something runs. The top row has priority."
  readonly property var jumps: []

  readonly property bool changed: ShellSettings.liveChanged || ModuleSettings.get("notifications", "appear", "card") !== "card"
  function reset() { ShellSettings.liveReset(); ModuleSettings.reset("notifications", ["appear"]); }

  spacing: Theme.sectionGap

  KitNotice {
    shown: !Theme.island
    title: "Live activities belong to the Island style"
    text: "The island is one pill with a hub and live activities. The strip has neither: these settings wait until you switch."
    action: "Use Island"
    onActed: ShellSettings.set("barStyle", "island")
  }

  // `shell open live:<kind>`: the activity's options unfold
  function jump(kind) { liveBlocks.jump(kind); }

  BarLive { id: liveBlocks; width: parent.width; visible: Theme.island }

  KitGrouper {}
}
