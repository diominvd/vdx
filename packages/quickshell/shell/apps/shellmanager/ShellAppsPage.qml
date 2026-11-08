import QtQuick
import Quickshell
import qs.apps.keybinds
import qs.bar
import qs.config
import qs.kit

// Apps: the shell's own apps (ShellAppsService.entries) as dropdowns (EntryFolds); a row
// unfolds in place: its key, how its window opens (WindowOptions), its own options page
// (values in ModuleSettings).
Item {
  id: root
  property real viewportRightInset: Theme.windowPadding

  // the window's fixed header shows these; the page fills the window and scrolls its views
  readonly property string icon: "grid"
  readonly property string title: "Apps"
  readonly property string description: "The shell's own programs: how each one opens and behaves."

  // its own index does the job of the sidebar's group links
  readonly property var jumps: []

  // an app with a page of its own (Lock screen) is set there, not here
  readonly property var listed: ShellAppsService.entries.filter(e => !e.page && e.listed !== false)
  readonly property var entries: listed.map(e => {
    const installed = ShellAppsService.installed(e);
    const keys = KeybindsService.keysFor(e.bind ?? "");
    return {
      id: e.id, label: e.label, icon: e.icon,
      off: !installed,
      state: !installed ? "Not installed" : keys.length > 0 ? keys.join(" + ") : "No key"
    };
  })

  // another page, scrolled to one of its groups (ShellManager.navigate)
  signal navigate(string tab, string target)
  // another page (or `ipc call shell open apps`) may name an app, or its bar module's id.
  // "<id>:bar" names the app's bar module: its options are in Bar modules
  function jump(key) {
    const bar = key.endsWith(":bar");
    const id = bar ? key.slice(0, -4) : key;
    const e = ShellAppsService.entries.find(e => e.id === id || e.module === id);
    if (e?.page) { navigate(e.page, ""); return; }
    if (e && bar && e.module) { navigate("modules", e.module); return; }
    if (e) browser.open(e.id);
  }

  // the Loader makes the page already visible: the first show is not a change
  Component.onCompleted: visibleChanged()
  onVisibleChanged: if (visible) { ShellAppsService.refresh(); KeybindsService.refresh(); }

  EntryFolds {
    id: browser
    viewportRightInset: root.viewportRightInset
    anchors.fill: parent
    model: root.entries
    searchHint: "Search apps…"

    options: Component {
      Column {
        id: body
        property string entryId: ""
        readonly property var entry: root.listed.find(e => e.id === entryId) ?? null
        readonly property bool installed: entry !== null && ShellAppsService.installed(entry)
        // its window's settings (shellapps.py), when it has one
        readonly property var window: entry?.window ? (ShellAppsService.windows.find(a => a.id === entry.window.id) ?? null) : null
        readonly property bool hasModule: !!entry?.module
        spacing: Theme.gapGroup

        // its components are off on this machine: nothing to set until installed
        KitRow {
          visible: body.entry !== null && !body.installed
          label: "Not installed"
          hint: "./install.py components add " + (BarLayout.notInstalled[body.entry?.module] ?? []).join(" or ")
          labelColor: Theme.foreground2
        }

        // how its window opens: the preview and its choices, in sight at once
        Loader {
          width: parent.width
          visible: active
          active: body.installed && body.window !== null
          sourceComponent: WindowOptions { app: body.window }
        }

        // its own options
        Loader {
          width: parent.width
          visible: active
          active: body.installed && !!body.entry?.settings
          source: active ? Quickshell.shellPath(body.entry.settings) : ""
        }

        // an app with nothing to set gets a row in their place, like one
        KitRow {
          visible: body.installed && body.window === null && !body.entry?.settings
          label: "No options"
          hint: "Opens with its key or the launcher"
          labelColor: Theme.foreground2
        }

        KitGrouper {}
      }
    }
  }
}
