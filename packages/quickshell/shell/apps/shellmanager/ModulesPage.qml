import QtQuick
import Quickshell
import qs.bar
import qs.config
import qs.kit

// Bar modules: every bar module as a dropdown (EntryFolds) — on the bar, off it, not
// installed; a row unfolds in place: where it sits, then its own
// <Name>Settings.qml (the registry's `settings`, or its app's `moduleSettings` in
// apps/apps.json), values kept in ModuleSettings. Notifications has a page of
// its own: a jump there. Where a module sits is set on the Bar page; a module's switch (`enabled`) takes it off every bar.
Item {
  id: root
  property real viewportRightInset: Theme.windowPadding

  // the window's fixed header shows these; the page fills the window and scrolls its views
  readonly property string icon: "assembly"
  readonly property string title: "Bar modules"
  readonly property string description: "What each bar module shows and how its popup behaves."

  // its own index does the job of the sidebar's group links
  readonly property var jumps: []

  signal navigate(string tab, string target)

  // another page names a module (Media's pause is Audio's, a right click on the bar): it opens here
  function jump(id) {
    if (pages[id]) navigate(pages[id], "");
    else if (BarLayout.modules.some(p => p.id === id)) browser.open(id);
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
  readonly property var entries: BarLayout.modules.filter(p => !pages[p.id]).map(p => {
    const installed = BarLayout.installed(p.id);
    const enabled = BarLayout.enabled(p.id);
    const place = installed && enabled ? BarLayout.placeOf(p.id, screen) : "";
    return {
      id: p.id, label: p.label, icon: p.icon,
      off: !installed, switchable: installed, on: enabled,
      state: !installed ? "Not installed" : !enabled ? "Switched off" : place !== "" ? place : "Not on the bar"
    };
  })

  EntryFolds {
    id: browser
    viewportRightInset: root.viewportRightInset
    anchors.fill: parent
    model: root.entries
    searchHint: "Search modules…"
    onSwitched: (id, on) => ModuleSettings.set(id, "enabled", on)

    options: Component {
      Column {
        id: body
        property string entryId: ""
        readonly property var module: BarLayout.modules.find(p => p.id === entryId) ?? null
        readonly property bool installed: module !== null && BarLayout.installed(entryId)
        readonly property string path: module ? root.optionsOf(module) : ""
        spacing: Theme.gapGroup

        // its components are off on this machine: nothing to set until installed
        KitRow {
          visible: body.module !== null && !body.installed
          label: "Not installed"
          hint: "./install.py components add " + (BarLayout.notInstalled[body.entryId] ?? []).join(" or ")
          labelColor: Theme.foreground2
        }

        // hidden when off: a zero-height item still takes a Column gap
        Loader {
          width: parent.width
          visible: active
          active: body.path !== "" && body.installed
          source: active ? Quickshell.shellPath(body.path) : ""
        }

        // a module without options gets a row in their place, like one
        KitRow {
          visible: body.path === "" && body.installed
          label: "No options"
          hint: "Nothing to set here"
          labelColor: Theme.foreground2
        }


        KitGrouper {}
      }
    }
  }
}
