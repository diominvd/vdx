import QtQuick
import Quickshell
import qs.apps.keybinds
import qs.bar
import qs.config
import qs.kit

// Apps: the shell's own apps (ShellAppsService.entries) as cards (EntryBrowser); a card
// opens the app across the pane: its key and Reset in the heading, how its window opens
// (WindowOptions, with its preview), its own options page (values in ModuleSettings) and
// a link to its bar module's options in Bar modules.
Item {
  id: root

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
      id: e.id, label: e.label, icon: e.icon, about: e.about,
      off: !installed, ok: false,
      section: installed ? "apps" : "absent",
      state: !installed ? "Not installed" : keys.length > 0 ? keys.join(" + ") : windowState(e),
      note: installed ? "" : "Not installed"   // the heading shows its keys, the page its window
    };
  })

  // how an app's window opens, in a few words ("" without a window of its own)
  function windowState(e) {
    const w = e?.window ? ShellAppsService.windows.find(a => a.id === e.window.id) : null;
    if (!w) return "";
    return w.settings.mode === "tiled" ? "Tiled" : "Floating · " + ShellAppsService.sizeOf(w, w.settings).join(" × ");
  }

  property string selected: ""
  readonly property var entry: listed.find(e => e.id === selected) ?? null
  readonly property bool installed: entry !== null && ShellAppsService.installed(entry)
  // its window's settings (shellapps.py), when it has one
  readonly property var window: entry?.window ? (ShellAppsService.windows.find(a => a.id === entry.window.id) ?? null) : null
  readonly property bool hasModule: !!entry?.module

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
    if (e) selected = e.id;
  }

  // the Loader makes the page already visible: the first show is not a change
  Component.onCompleted: visibleChanged()
  onVisibleChanged: if (visible) { ShellAppsService.refresh(); KeybindsService.refresh(); }

  EntryBrowser {
    anchors.fill: parent
    model: root.entries
    sections: [
      { key: "apps", label: "APPS" },
      { key: "absent", label: "NOT INSTALLED" }
    ]
    selected: root.selected
    backLabel: "All apps"
    searchHint: "Search apps…"
    onPicked: id => root.selected = id

    trailing: [
      Repeater {
        model: KeybindsService.keysFor(root.entry?.bind ?? "")

        KeyCap {
          required property string modelData
          anchors.verticalCenter: parent.verticalCenter
          text: modelData
        }
      },
      Item { width: Theme.gapSmall; height: 1; visible: !!root.entry?.settings },
      KitResetButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: !!root.entry?.settings && root.installed
        // an app with a bar module: every key but the module's (they stay)
        readonly property var moduleKeys: root.hasModule ? (ModuleSettings.keysOf(root.entry.moduleSettings) ?? []) : []
        readonly property var keys: root.hasModule
          ? Object.keys(ModuleSettings.values[root.selected] ?? {}).filter(k => !moduleKeys.includes(k)) : null
        changed: ModuleSettings.changed(root.selected, keys)
        onReset: ModuleSettings.reset(root.selected, keys)
      }
    ]

    // its components are off on this machine: nothing to set until installed
    KitRow {
      visible: root.entry !== null && !root.installed
      label: "Not installed"
      hint: "./install.py components add " + (BarLayout.notInstalled[root.entry?.module] ?? []).join(" or ")
      labelColor: Theme.foreground2
    }

    // how its window opens: the preview and its choices, in sight at once
    Loader {
      width: parent.width
      visible: active
      active: root.installed && root.window !== null
      sourceComponent: WindowOptions { app: root.window }
    }

    KitLine { visible: root.installed && root.window !== null }

    // its own options
    Loader {
      width: parent.width
      visible: active
      active: root.installed && !!root.entry?.settings
      source: active ? Quickshell.shellPath(root.entry.settings) : ""
    }

    KitLine { visible: root.installed && !!root.entry?.settings }

    // its bar module's options are in Bar modules, as every module's
    KitLinkRow {
      visible: root.hasModule && root.installed
      label: "Bar module"
      hint: "In Bar modules › " + (root.entry?.label ?? "")
      target: "modules:" + (root.entry?.module ?? "")
    }

    // an app with nothing to set gets a row in their place, like one
    KitRow {
      visible: root.installed && root.window === null && !root.entry?.settings && !root.entry?.module
      label: "No options"
      hint: "Opens with its key or the launcher"
      labelColor: Theme.foreground2
    }

    KitGrouper {}
  }
}
