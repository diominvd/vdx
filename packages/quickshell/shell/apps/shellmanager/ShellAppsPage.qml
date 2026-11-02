import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import qs.apps.keybinds
import qs.bar
import qs.config
import qs.kit

// Shell apps: the shell's own apps (ShellAppsService.entries) — the list on
// the left, the chosen one on the right: its name, what it is and the key
// that opens it; then its own options page (values in ModuleSettings, Reset
// brings the defaults back), its window options inline and its module in
// the bar (shown, where, its own options). Each pane scrolls on its own.
Column {
  id: root

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "grid"
  readonly property string title: "Apps"
  readonly property string description: "The shell's own programs: how each one opens and behaves."

  // its own list does the job of the sidebar's group links
  readonly property var jumps: []

  // an app with a page of its own (Lock screen) is set there, not here
  readonly property var listed: ShellAppsService.entries.filter(e => !e.page && e.listed !== false).sort((a, b) => a.label.localeCompare(b.label))
  property string selected: listed[0]?.id ?? ""
  property bool setupOpen: false
  readonly property var entry: listed.find(e => e.id === selected) ?? null
  // its window's settings (shellapps.py), when it has one
  readonly property var window: entry?.window ? (ShellAppsService.windows.find(a => a.id === entry.window.id) ?? null) : null

  // the tab: the app or its bar module (an app with a module only)
  readonly property bool hasModule: !!entry?.module

  // where its bar module stands on the main bar: hidden | folder | a zone
  readonly property string screen: BarLayout.mainScreen()
  readonly property string place: {
    const id = entry?.module ?? "";
    if (id === "" || BarLayout.hidden(screen).includes(id)) return "hidden";
    if (BarLayout.inFolder(screen).includes(id)) return "folder";
    const l = BarLayout.layout(screen);
    return BarLayout.zones.find(z => (l[z] ?? []).includes(id)) ?? "hidden";
  }

  // another page, scrolled to one of its groups (ShellManager.navigate)
  signal navigate(string tab, string target)
  // another page (or `ipc call shell open apps`) may name an app, or its
  // bar module's id; a module's id opens the app on its bar-module tab.
  // "<id>:bar" (Modules' Open) names the bar-module tab even when the module
  // has the app's id
  function jump(key) {
    const bar = key.endsWith(":bar");
    const id = bar ? key.slice(0, -4) : key;
    const e = ShellAppsService.entries.find(e => e.id === id || e.module === id);
    if (e?.page) { navigate(e.page, ""); return; }
    if (e && bar && e.module) { navigate("modules", e.module); return; }
    if (e) selected = e.id;
  }

  spacing: Theme.gapGroup

  onVisibleChanged: if (visible) { ShellAppsService.refresh(); KeybindsService.refresh(); }

  Row {
    width: parent.width
    height: root.height
    spacing: Theme.gapGroup

    EntryList {
      id: list
      compact: true
      height: parent.height - Theme.windowPadding
      model: root.listed.map(e => Object.assign({ off: !ShellAppsService.installed(e) }, e))
      selected: root.selected
      onPicked: id => root.selected = id
    }

    // the list's edge
    // — as far from the list as the list is from the pane's edge on the other side
    Item {
      id: edge
      width: Math.max(0, Theme.windowPadding - Theme.gapGroup) + Theme.dividerThickness
      height: parent.height - Theme.windowPadding

      Rectangle {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: Theme.dividerThickness
        color: Theme.dividerColor
      }
    }

    // ---- the chosen app: its name, key, window and options, scrolling on their own ----
    Flickable {
      id: pane
      visible: list.matches.length > 0
      Controls.ScrollBar.vertical: KitScrollBar {}
      width: parent.width - list.width - edge.width - 2 * parent.spacing + Theme.windowPadding
      height: parent.height
      contentHeight: details.implicitHeight
      bottomMargin: Theme.windowPadding  // the window's edge clips, not a line above it
      interactive: contentHeight + bottomMargin > height   // the margin scrolls too
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: details
        // the pane reaches the window's edge (the scrollbar sits there); its content ends where Bar modules' does
        width: pane.width - Theme.gapMedium - Theme.windowPadding
        spacing: Theme.sectionGap
        opacity: paneIn.shown

        // heading: icon, name and about; the key that opens it; Reset
        Item {
          readonly property Item kitCaption: heading
          property bool kitUnboxed: true    // KitGrouper: the heading stands on the page
          width: parent.width
          height: Math.max(heading.implicitHeight, trailing.height)

          Row {
            id: heading
            anchors { left: parent.left; right: trailing.left; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
            spacing: Theme.gapLoose

            KitIcon {
              id: headingIcon
              anchors.verticalCenter: parent.verticalCenter
              name: root.entry?.icon ?? ""
              size: 18
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: heading.width - headingIcon.width - heading.spacing
              spacing: Theme.gapTight

              KitText {
                width: parent.width
                elide: Text.ElideRight
                text: root.entry?.label ?? ""
                font.weight: Font.DemiBold
              }

              KitText {
                width: parent.width
                text: root.entry?.about ?? ""
                elide: Text.ElideRight
                maximumLineCount: 1
                color: Theme.muted
                font.pixelSize: Theme.fontSize - 1
              }
            }
          }

          Row {
            id: trailing
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Theme.gapSmall

            Repeater {
              model: KeybindsService.keysFor(root.entry?.bind ?? "")

              KeyCap {
                required property string modelData
                anchors.verticalCenter: parent.verticalCenter
                text: modelData
              }
            }

            Item { width: 6; height: 1; visible: !!root.entry?.settings }

            KitResetButton {
              visible: !!root.entry?.settings
              // an app with a bar module: every key but the module's (they stay)
              readonly property var moduleKeys: root.hasModule ? (ModuleSettings.keysOf(root.entry.moduleSettings) ?? []) : []
              readonly property var keys: root.hasModule
                ? Object.keys(ModuleSettings.values[root.selected] ?? {}).filter(k => !moduleKeys.includes(k)) : null
              changed: ModuleSettings.changed(root.selected, keys)
              onReset: ModuleSettings.reset(root.selected, keys)
            }
          }
        }

        KitLine { sectionBreak: false }

        // its components are off on this machine: nothing to set until installed
        KitRow {
          visible: root.entry !== null && !ShellAppsService.installed(root.entry)
          label: "Not installed"
          hint: "components add " + (BarLayout.notInstalled[root.entry?.module] ?? []).join(" or ")
          labelColor: Theme.foreground2
        }

        // ---- the app: how its window opens first, then its own options ----
        Column {
          width: parent.width
          visible: ShellAppsService.installed(root.entry)
          spacing: Theme.sectionGap

          // One-line summary; expand the full editor here in the app's settings.
          KitRow {
            visible: root.window !== null
            label: "Window"
            hint: !root.window ? "" : root.window.settings.mode === "tiled" ? "Tiled, in the layout"
                : "Floating · " + ShellAppsService.sizeOf(root.window, root.window.settings).join(" × ")
                  + " · " + ShellAppsService.placeName(root.window.settings)

            KitButton {
              width: Theme.buttonWidth
              icon: "app-window"
              text: root.setupOpen ? "Close" : "Set up"
              selected: root.setupOpen
              onClicked: root.setupOpen = !root.setupOpen
            }
          }

          // opens and closes by revealing: the height and the fade follow `shown`; the options
          // keep their final layout inside, so the group boxes never stretch
          Item {
            id: windowOptions
            property bool kitUnboxed: true
            property real shown: 0
            property bool snapping: false
            width: parent.width
            height: Math.round(optionsLoader.height * shown)
            visible: height > 0
            opacity: shown
            clip: true

            Behavior on shown {
              enabled: Motion.controls && !windowOptions.snapping
              NumberAnimation { duration: Motion.normal; easing.type: Motion.morph }
            }

            function snap(value) { snapping = true; shown = value; snapping = false; }

            Connections {
              target: root
              function onSetupOpenChanged() { windowOptions.shown = root.setupOpen && root.window !== null ? 1 : 0; }
              function onSelectedChanged() { windowOptions.snap(0); }
            }

            Loader {
              id: optionsLoader
              width: parent.width
              active: root.window !== null && (root.setupOpen || windowOptions.shown > 0)
              sourceComponent: WindowOptions {
                app: root.window
                labelled: false
                showPreview: true
              }
            }
          }

          KitLine { visible: root.window !== null && !!root.entry?.settings }

          Loader {
            width: parent.width
            visible: active
            active: !!root.entry?.settings
            source: active ? Quickshell.shellPath(root.entry.settings) : ""
          }

          KitGrouper { id: appOptionsGrouper }
        }

        // its bar module's options are in Bar modules (05), a group of its own
        KitLine {}

        KitLinkRow {
          visible: root.hasModule && ShellAppsService.installed(root.entry)
          label: "Bar module"
          hint: "In Bar modules › " + (root.entry?.label ?? "")
          target: "modules:" + (root.entry?.module ?? "")
        }

        // an app with nothing to set gets a row in their place, like one
        KitRow {
          visible: root.window === null && !root.entry?.settings && !root.entry?.module
          label: "No options"
          hint: "Opens with its key or the launcher"
          labelColor: Theme.foreground2
        }

        KitGrouper {}
      }
    }
    KitEmptyState {
      visible: list.matches.length === 0
      width: parent.width - list.width - edge.width - 2 * parent.spacing
      icon: "search"
      title: "No matching items"
      hint: "Try a shorter search"
    }
  }

  // the chosen app fades in like a page does (ShellManager's pageIn)
  QtObject { id: paneIn; property real shown: 1 }
  NumberAnimation { id: paneAnim; target: paneIn; property: "shown"; from: 0; to: 1; duration: Motion.ms(240); easing.type: Motion.easing }

  onSelectedChanged: {
    setupOpen = false;
    pane.contentY = 0;
    if (Motion.pages) paneAnim.restart();
  }
}
