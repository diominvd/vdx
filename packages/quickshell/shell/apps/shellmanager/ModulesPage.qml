import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import qs.bar
import qs.config
import qs.kit

// Bar modules: every bar module in a list on the left, the chosen one's options
// on the right — its own <Name>Settings.qml (the registry's `settings`, or its
// app's `moduleSettings` in apps/apps.json), values kept in ModuleSettings,
// Reset to the defaults (an app's module shares its id with the app: Reset
// brings back both). Notifications has a page of its own: a link there. Each
// pane scrolls on its own. Where a module sits is set on the Bar page.
Column {
  id: root

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "puzzle"
  readonly property string title: "Bar modules"
  readonly property string description: "What each bar module shows and how its popup behaves."

  // its own list does the job of the sidebar's group links
  readonly property var jumps: []

  signal navigate(string tab, string target)

  // another page names a module (Media's pause is Audio's): it is chosen here
  function jump(id) {
    if (pages[id]) navigate(pages[id], "");
    else if (BarLayout.modules.some(p => p.id === id)) selected = id;
  }

  // modules whose options live on a page of their own (no row here: a right click goes there)
  readonly property var pages: ({ notifications: "notifications" })
  readonly property var listed: BarLayout.modules.filter(p => !pages[p.id]).sort((a, b) => a.label.localeCompare(b.label))

  // the app a module belongs to (apps/apps.json), if any: its options page is the app's `moduleSettings`
  function appOf(id) { return ShellAppsService.entries.find(a => a.module === id) ?? null; }
  // a module's options page as a shell path, "" without one
  function optionsOf(p) {
    const app = appOf(p.id);
    if (app) return app.moduleSettings ?? "";
    if (!p.settings) return "";
    return p.settings.includes("/") ? p.settings : "modules/" + p.id + "/" + p.settings;
  }

  property string selected: listed[0]?.id ?? ""
  readonly property var module: BarLayout.modules.find(p => p.id === selected) ?? null
  readonly property string options: module ? optionsOf(module) : ""

  spacing: Theme.gapGroup

  Row {
    width: parent.width
    height: root.height
    spacing: Theme.gapGroup

    // ---- list: like the theme list — search, a narrow list with its edge ----
    EntryList {
      id: list
      compact: true
      height: parent.height - Theme.windowPadding
      model: root.listed.map(p => Object.assign({ off: !BarLayout.installed(p.id) }, p))
      selected: root.selected
      onPicked: id => root.jump(id)
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

    // ---- the chosen module: its name and options, scrolling on their own ----
    Flickable {
      id: pane
      visible: list.matches.length > 0
      Controls.ScrollBar.vertical: KitScrollBar {}
      width: parent.width - list.width - edge.width - 2 * parent.spacing
      height: parent.height
      contentHeight: details.implicitHeight
      bottomMargin: Theme.windowPadding  // the window's edge clips, not a line above it
      interactive: contentHeight + bottomMargin > height   // the margin scrolls too
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: details
        width: pane.width - Theme.gapMedium
        spacing: Theme.sectionGap
        opacity: paneIn.shown

        // heading: icon, name and about; Reset brings the options' defaults back
        Item {
          readonly property Item kitCaption: heading
          readonly property bool kitUnboxed: true
          width: parent.width
          height: Math.max(heading.implicitHeight, resetButton.height)

          Row {
            id: heading
            anchors { left: parent.left; right: resetButton.left; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
            spacing: Theme.gapLoose

            KitIcon {
              id: headingIcon
              anchors.verticalCenter: parent.verticalCenter
              name: root.module?.icon ?? ""
              size: 18
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: heading.width - headingIcon.width - heading.spacing
              spacing: Theme.gapTight

              KitText {
                width: parent.width
                elide: Text.ElideRight
                text: root.module?.label ?? ""
                font.weight: Font.DemiBold
              }

              KitText {
                width: parent.width
                text: root.module?.about ?? ""
                elide: Text.ElideRight
                maximumLineCount: 1
                color: Theme.muted
                font.pixelSize: Theme.fontSize - 1
              }
            }
          }

          KitResetButton {
            id: resetButton
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: root.options !== ""
            // an app's module: only its own keys, the app's stay
            readonly property var keys: root.appOf(root.selected) ? ModuleSettings.keysOf(root.options) : null
            changed: ModuleSettings.changed(root.selected, keys)
            onReset: ModuleSettings.reset(root.selected, keys)
          }
        }

        KitLine { sectionBreak: false }

        // where it is: its options mean little off the bar
        KitRow {
          id: placeRow
          visible: root.module !== null && BarLayout.installed(root.selected) && root.selected !== "folder"
          readonly property string place: BarLayout.placeOf(root.selected, BarLayout.mainScreen())
          label: place !== "" ? "On the bar" : "Not on the bar"
          hint: place !== "" ? (place === "In the hub, as a chip" ? "Hub chip" : place) : "Place to use its options"
          KitButton { width: Theme.controlWidth; text: placeRow.place !== "" ? "Move…" : "Place it"; onClicked: root.navigate("bar", "layout") }
        }

        // its components are off on this machine: nothing to set until installed
        KitRow {
          visible: root.module !== null && !BarLayout.installed(root.selected)
          label: "Not installed"
          hint: "Add with ./install.py components add " + (BarLayout.notInstalled[root.selected] ?? []).join(" or ")
          labelColor: Theme.foreground2
        }

        // hidden when off: a zero-height item still takes a Column gap
        Loader {
          width: parent.width
          visible: active
          active: root.options !== "" && BarLayout.installed(root.selected)
          source: active ? Quickshell.shellPath(root.options) : ""
        }

        // a module without options gets a row in their place, like one
        KitRow {
          visible: root.options === "" && BarLayout.installed(root.selected)
          label: "No options"
          hint: "Nothing to set here"
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

  // the chosen module fades in like a page does (ShellManager's pageIn), as in Apps
  QtObject { id: paneIn; property real shown: 1 }
  NumberAnimation { id: paneAnim; target: paneIn; property: "shown"; from: 0; to: 1; duration: Motion.ms(240); easing.type: Motion.easing }

  onSelectedChanged: {
    pane.contentY = 0;
    if (Motion.pages) paneAnim.restart();
  }
}
