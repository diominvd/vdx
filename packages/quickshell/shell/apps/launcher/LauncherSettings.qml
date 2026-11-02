import QtQuick
import qs.apps.launcher
import qs.config
import qs.kit

// Launcher options in Shell apps (ModuleSettings "launcher"): the panel — rows
// in the list, width, where it sits; then its TABS: ORDER, the tabs in the order
// they show, and HIDDEN below them (KitChipBands). Drag a chip along a band to
// reorder it, into HIDDEN to hide it, back into ORDER to show it; one tab always
// stays shown. Then the tab it opens on and whether the search clears on close.
Column {
  id: root

  function opt(key, fallback) { return ModuleSettings.get("launcher", key, fallback); }

  spacing: Theme.sectionGap

  // the screen behind the panel: in the window, and behind the island's view
  KitToggleRow {
    module: "launcher"; key: "dim"; fallback: true
    label: "Dim the background"
    hint: "Off: the screen behind it stays as it is"
  }

  // Island style: the window opens from the island, inside it, like a module's popup
  KitLabel { text: "ISLAND"; visible: ShellSettings.barStyle === "island" }
  KitToggleRow {
    needs: ShellSettings.barStyle === "island" ? "" : "Island style only"
    needsAction: "Use Island"
    onNeedsActed: ShellSettings.set("barStyle", "island")
    module: "launcher"; key: "island"; fallback: true
    label: "Open from the island"
    hint: "On: opens inside the island, not a window"
  }

  // ---- tabs: what each band holds ----
  readonly property string focusId: chips.dragId !== "" ? chips.dragId : chips.hoverId

  readonly property var shownIds: LauncherService.tabs.map(t => t.value)
  readonly property var hiddenIds: LauncherService.orderAll.filter(v => LauncherService.hiddenTabs.includes(v))
  readonly property bool isDefault: LauncherService.orderAll.join() === LauncherService.defaultOrder.join()
                                    && LauncherService.hiddenTabs.length === 0

  function tab(id) { return LauncherService.allTabs.find(t => t.value === id) ?? { label: id, icon: "app-window" }; }
  function ids(zone) { return zone === "hidden" ? hiddenIds : shownIds; }
  function save(order, hidden) {
    ModuleSettings.set("launcher", "order", order);
    ModuleSettings.set("launcher", "hidden", hidden);
  }

  // the stored order holds hidden tabs too: the slot is translated through the
  // shown neighbours, as the Bar's
  function drop(id, zone, index) {
    if (zone === "hidden") {
      if (shownIds.includes(id) && shownIds.length > 1)
        save(LauncherService.orderAll, LauncherService.hiddenTabs.concat([id]));
    } else if (zone === "order") {
      const others = shownIds.filter(v => v !== id);
      const current = shownIds.indexOf(id);
      const slot = current >= 0 && index > current ? index - 1 : index;
      const full = LauncherService.orderAll.filter(v => v !== id);
      const at = slot < others.length ? full.indexOf(others[slot])
               : others.length > 0 ? full.indexOf(others[others.length - 1]) + 1
               : full.length;
      full.splice(at, 0, id);
      save(full, LauncherService.hiddenTabs.filter(v => v !== id));
    }
  }

  // ---- layout ----
  KitLabel { text: "LAYOUT" }

  KitOptionRow {
    module: "launcher"; key: "rows"; fallback: 8
    label: "Visible rows"; hint: "The rest scrolls"
    model: [6, 8, 10, 12].map(v => ({ label: String(v), value: v }))
  }

  KitOptionRow {
    module: "launcher"; key: "size"; fallback: "medium"
    label: "Width"; hint: ""
    model: [{ label: "Small", value: "small" }, { label: "Medium", value: "medium" }, { label: "Large", value: "large" }]
  }

  KitOptionRow {
    module: "launcher"; key: "position"; fallback: "top"
    label: "Position"; hint: ""
    model: [{ label: "Top", value: "top" }, { label: "Centre", value: "center" }, { label: "Bottom", value: "bottom" }]
  }

  KitLine {}

  // ---- tabs ----
  Item {
    width: parent.width
    height: tabsReset.height

    KitLabel {
      anchors { left: parent.left; right: tabsReset.left; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
      text: "TABS"
      // what the pointer is on, or how this works
      value: root.focusId !== "" ? root.tab(root.focusId).label.toUpperCase() : "DRAG TO ORDER OR HIDE"
      valueColor: root.focusId !== "" ? Theme.foreground2 : Theme.muted
    }

    KitButton {
      id: tabsReset
      anchors.right: parent.right
      icon: "rotate-ccw"
      text: "Reset"
      disabled: root.isDefault
      onClicked: root.save(LauncherService.defaultOrder, [])
    }
  }

  // two bands: ORDER (the tabs shown, in the order they show) and HIDDEN below
  KitChipBands {
    id: chips
    width: parent.width
    zones: ["order", "hidden"]
    idsOf: zone => root.ids(zone)
    labelOf: id => root.tab(id).label
    iconOf: id => root.tab(id).icon
    emptyText: zone => zone === "hidden" ? "nothing hidden" : "empty"
    onDropped: (id, zone, index) => root.drop(id, zone, index)
  }

  KitLine {}

  // ---- opening ----
  KitLabel { text: "OPENING" }

  KitSelect {
    width: parent.width
    label: "Opens on"; hint: "The tab shown first"
    model: LauncherService.allTabs.map(t => ({ label: t.label, value: t.value }))
    current: root.opt("opens", "apps")
    onPicked: value => ModuleSettings.set("launcher", "opens", value)
  }

  KitToggleRow { module: "launcher"; key: "clear"; fallback: true; label: "Clear search on close"; hint: "Off: the search stays as it was" }

  KitToggleRow { module: "launcher"; key: "english"; fallback: true; label: "English layout on open"; hint: "Switches the keyboard when it opens" }

  KitGrouper {}
}
