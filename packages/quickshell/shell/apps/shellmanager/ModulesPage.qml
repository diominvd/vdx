import QtQuick
import Quickshell
import qs.bar
import qs.config
import qs.kit

// Bar modules: every bar module as a card (EntryBrowser) — on the bar, off it, not
// installed; a card opens the module across the pane: where it sits, then its own
// <Name>Settings.qml (the registry's `settings`, or its app's `moduleSettings` in
// apps/apps.json), values kept in ModuleSettings, Reset to the defaults (an app's module
// shares its id with the app: only the module's own keys). Notifications has a page of
// its own: a jump there. Where a module sits is set on the Bar page.
Item {
  id: root

  // the window's fixed header shows these; the page fills the window and scrolls its views
  readonly property string icon: "puzzle"
  readonly property string title: "Bar modules"
  readonly property string description: "What each bar module shows and how its popup behaves."

  // its own index does the job of the sidebar's group links
  readonly property var jumps: []

  signal navigate(string tab, string target)

  // another page names a module (Media's pause is Audio's, a right click on the bar): it opens here
  function jump(id) {
    if (pages[id]) navigate(pages[id], "");
    else if (BarLayout.modules.some(p => p.id === id)) selected = id;
  }

  // modules whose options live on a page of their own (no card here: a right click goes there)
  readonly property var pages: ({ notifications: "notifications" })

  // the app a module belongs to (apps/apps.json), if any: its options page is the app's `moduleSettings`
  function appOf(id) { return ShellAppsService.entries.find(a => a.module === id) ?? null; }
  // a module's options page as a shell path, "" without one
  function optionsOf(p) {
    const app = appOf(p.id);
    if (app) return app.moduleSettings ?? "";
    if (!p.settings) return "";
    return p.settings.includes("/") ? p.settings : "modules/" + p.id + "/" + p.settings;
  }

  readonly property string screen: BarLayout.mainScreen()
  // BarLayout.placeOf's words, short enough for a card (the heading keeps them whole)
  readonly property var short: ({
    "Left of the clock": "Left", "Right of the clock": "Right",
    "In the hub, as a chip": "Hub chip", "In the hub, as a tile": "Hub tile", "In the Folder": "Folder", "In the island": "Island"
  })
  readonly property var entries: BarLayout.modules.filter(p => !pages[p.id]).map(p => {
    const installed = BarLayout.installed(p.id);
    const place = installed ? BarLayout.placeOf(p.id, screen) : "";
    return {
      id: p.id, label: p.label, icon: p.icon, about: p.about,
      off: !installed, ok: place !== "",
      section: !installed ? "absent" : place !== "" ? "on" : "off",
      state: !installed ? "Not installed" : place !== "" ? (short[place] ?? place) : "Not on the bar",
      note: !installed ? "Not installed" : place !== "" ? place : "Not on the bar"
    };
  })

  property string selected: ""
  // an open entry: the window header's crumb ("‹ All modules / <name>") goes back to the index
  readonly property string backLabel: selected !== "" ? "All modules" : ""
  readonly property string here: entries.find(e => e.id === selected)?.label ?? ""
  function back() { selected = ""; }
  readonly property var module: BarLayout.modules.find(p => p.id === selected) ?? null
  readonly property bool installed: module !== null && BarLayout.installed(selected)
  readonly property string options: module ? optionsOf(module) : ""

  EntryBrowser {
    anchors.fill: parent
    model: root.entries
    sections: [
      { key: "on", label: "ON THE BAR" },
      { key: "off", label: "OFF THE BAR" },
      { key: "absent", label: "NOT INSTALLED" }
    ]
    selected: root.selected
    searchHint: "Search modules…"
    onPicked: id => root.selected = id

    trailing: KitResetButton {
      visible: root.options !== "" && root.installed
      // an app's module: only its own keys, the app's stay
      readonly property var keys: root.appOf(root.selected) ? ModuleSettings.keysOf(root.options) : null
      changed: ModuleSettings.changed(root.selected, keys)
      onReset: ModuleSettings.reset(root.selected, keys)
    }

    // where it sits: its options mean little off the bar (the Folder is a place itself)
    KitLinkRow {
      visible: root.installed && root.selected !== "folder"
      label: BarLayout.placeOf(root.selected, root.screen) !== "" ? "Move on the bar" : "Put on the bar"
      hint: "In Bar › Layout"
      target: "bar:layout"
    }

    // its components are off on this machine: nothing to set until installed
    KitRow {
      visible: root.module !== null && !root.installed
      label: "Not installed"
      hint: "./install.py components add " + (BarLayout.notInstalled[root.selected] ?? []).join(" or ")
      labelColor: Theme.foreground2
    }

    KitLine {}

    // hidden when off: a zero-height item still takes a Column gap
    Loader {
      width: parent.width
      visible: active
      active: root.options !== "" && root.installed
      source: active ? Quickshell.shellPath(root.options) : ""
    }

    // a module without options gets a row in their place, like one
    KitRow {
      visible: root.options === "" && root.installed
      label: "No options"
      hint: "Nothing to set here"
      labelColor: Theme.foreground2
    }

    KitGrouper {}
  }
}
