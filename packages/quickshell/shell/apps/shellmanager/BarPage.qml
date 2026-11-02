import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import qs.apps.files
import qs.bar
import qs.config
import qs.kit

// Keep the live result, placed modules and the module catalogue distinct.
KitSettingsWorkspace {
  id: root
  readonly property bool fillsViewport: true
  showScrollBar: false
  readonly property Item previewItem: null
  readonly property var tabs: sections
  readonly property string icon: "menu"
  readonly property string title: "Bar"
  readonly property string description: "The bar's style, content, look and screens."
  property string tab: "layout"
  property string screenName: BarLayout.mainScreen()
  property string selectedModule: ""
  property string activeZone: island ? "start" : "left"
  property string availableQuery: ""
  property bool arranging: false
  property var undoStack: []
  function remember() {
    undoStack = undoStack.concat([{screen: screenName, layout: BarLayout.snapshot(screenName), dot: ShellSettings.barFolderDot}]).slice(-30);
  }
  function undo() {
    if (!undoStack.length) return;
    const previous = undoStack[undoStack.length - 1];
    undoStack = undoStack.slice(0, -1);
    BarLayout.update(previous.screen, previous.layout);
    ShellSettings.set("barFolderDot", previous.dot);
    layoutError = "";
  }
  readonly property bool island: Theme.island
  readonly property bool barOn: BarLayout.barOn(screenName)
  readonly property var roles: Quickshell.screens.map(s => s.name)
    .sort((a, b) => (BarLayout.roleOf(a) === "main" ? 0 : 1) - (BarLayout.roleOf(b) === "main" ? 0 : 1))
    .filter((n, i, all) => all.findIndex(o => BarLayout.roleOf(o) === BarLayout.roleOf(n)) === i)
  readonly property string other: roles.find(n => n !== screenName) ?? ""
  readonly property var layout: BarLayout.layout(screenName)
  readonly property var children: BarLayout.barsOn(screenName)
  readonly property var columnZones: (island ? ["start", "end", "hub", "tiles"] : ["left", "center", "right", "folder"])
    .concat(children.map(b => "bar:" + b.id), ["hidden"])
  function childOf(zone) { return zone.startsWith("bar:") ? zone.slice(4) : ""; }
  readonly property string selectedZone: columnZones.find(z => ids(z).includes(selectedModule)) ?? ""
  readonly property int selectedIndex: selectedZone ? ids(selectedZone).indexOf(selectedModule) : -1
  readonly property var available: ids("hidden").filter(id => canPlace(id, activeZone)
    && (module(id)?.label ?? "").toLowerCase().includes(availableQuery.trim().toLowerCase()))
  onScreenNameChanged: { selectedModule = ""; undoStack = []; }
  onIslandChanged: {
    undoStack = []; selectedModule = ""; activeZone = island ? "start" : "left";
  }
  onColumnZonesChanged: if (!columnZones.includes(activeZone)) activeZone = island ? "start" : "left"
  // Reset covers this page: the look of both styles and the right click. The style is the owner's
  // choice, and the hub and the live activities have their own pages and Resets.
  readonly property var lookKeys: ["barIconGrow", "barSeparators", "barGap", "pillHeight"]
  readonly property bool changed: ShellSettings.looksTouched(lookKeys, "solid") || ShellSettings.looksTouched(lookKeys, "island")
                                   || ShellSettings.changed(["barRightSettings"])
  function reset() {
    ShellSettings.looksReset(lookKeys, "solid");
    ShellSettings.looksReset(lookKeys, "island");
    ShellSettings.reset(["barRightSettings"]);
  }
  // the Layout, Look and Monitors tabs are sidebar pages (Shell Manager `pageTab`): a page lists its own
  readonly property var jumps: [
    { key: "layout", label: "Layout", y: 0 },
    { key: "look", label: "Look", y: 0 },
    { key: "behaviour", label: "Behaviour", y: 0 },
    { key: "monitor", label: "Monitor", y: 0 }
  ].filter(j => j.key === tab || (tab === "appearance" && j.key !== "layout" && j.key !== "monitor"))
  function jump(key) {
    if (key === "hubzone") { tab = "layout"; if (island) chooseZone("hub"); return; }
    tab = ["look", "behaviour", "appearance"].includes(key) ? "appearance" : key === "monitor" ? "monitor" : "layout";
  }
  function zoneLabel(zone) {
    return childOf(zone) ? "Bar " + (children.findIndex(b => b.id === childOf(zone)) + 2)
      : ({left: "Left", center: "Centre", right: "Right", start: "Left of clock", end: "Right of clock", hub: "Hub chips", tiles: "Hub tiles", folder: "Folder", hidden: "Not on the bar"})[zone] ?? zone;
  }
  function chooseZone(zone) { activeZone = zone; }
  function selectModule(id) {
    selectedModule = id;
    const zone = columnZones.find(z => z !== "hidden" && ids(z).includes(id));
    if (zone) activeZone = zone;
  }
  function nudgeModule(step) {
    if (selectedIndex < 0) return;
    drop(selectedModule, selectedZone, selectedIndex + (step > 0 ? 2 : -1));
  }
  function addModule(id) { drop(id, activeZone, ids(activeZone).length); selectedModule = id; }
  function removeModule(id) {
    remember();
    if (BarLayout.isSeparator(id)) BarLayout.removeSeparator(id, screenName);
    else applyDrop(id, "hidden", 0);
    if (selectedModule === id) selectedModule = "";
  }
  function module(id) { return BarLayout.modules.find(p => p.id === id) ?? null; }
  function ids(zone) {
    if (!zone) return [];
    if (["start", "end", "hub", "tiles"].includes(zone)) return BarLayout.islandIn(zone, screenName);
    if (childOf(zone) !== "") return BarLayout.barModules(screenName, childOf(zone));
    if (island) return zone === "hidden" ? BarLayout.islandHidden(screenName) : BarLayout.islandIn(zone, screenName);
    return zone === "hidden" ? BarLayout.unplaced(screenName)
         : zone === "folder" ? BarLayout.inFolder(screenName)
         : ["left", "center", "right"].includes(zone) ? BarLayout.visibleIn(zone, screenName) : [];
  }

  // A new separator is created only after a valid destination is chosen.
  readonly property string newSeparator: "sep-new"
  // the bands show placed modules only; the stored order holds the rest too,
  // so the slot is translated through its visible neighbours
  property string layoutError: ""
  function canPlace(id, zone) {
    if (id === "folder") return ["left", "center", "right"].includes(zone) || childOf(zone) !== "";
    if (BarLayout.isSeparator(id)) return !["folder", "hub", "tiles"].includes(zone) && childOf(zone) === "";
    if (zone === "tiles") return BarLayout.isTile(id);      // only a module that has a tile
    return columnZones.includes(zone);
  }
  function drop(id, zone, index) {
    if (!canPlace(id, zone)) return;
    remember();
    applyDrop(id, zone, index);
    selectedModule = id === newSeparator ? "" : id;
  }
  function applyDrop(id, zone, index) {
    if (!canPlace(id, zone)) { layoutError = "This module cannot be placed in that zone"; return; }
    layoutError = "";
    // a separator sits in the main bar's sides only: HIDDEN removes it, the rest
    // refuse it; the tray's chip becomes a new one where it lands
    if (BarLayout.isSeparator(id)) {
      if (zone === "folder" || childOf(zone) !== "" || zone === "hub" || zone === "tiles") return;
      if (zone === "hidden") { if (id !== newSeparator) BarLayout.removeSeparator(id, screenName); return; }
      if (id === newSeparator) id = BarLayout.newSeparator();
    }
    const child = childOf(zone);
    if (child !== "") {
      const current = BarLayout.barModules(screenName, child).indexOf(id);
      BarLayout.moveToBar(screenName, id, child, current >= 0 && index > current ? index - 1 : index);
      return;
    }
    // out of a child bar first: back on the main bar where it was
    if (BarLayout.taken(id, screenName)) BarLayout.moveToBar(screenName, id, "", 0);
    if (island) {
      // a slot among the band's chips is a slot in its list: no hidden ones in between
      const current = BarLayout.islandIn(zone, screenName).indexOf(id);
      BarLayout.islandMove(id, zone, current >= 0 && index > current ? index - 1 : index, screenName);
    } else if (zone === "hidden") {
      BarLayout.setEnabled(id, false, screenName);
    } else if (zone === "folder") {
      BarLayout.setFolder(id, index, screenName);
    } else {
      if (BarLayout.unplaced(screenName).includes(id)) BarLayout.setEnabled(id, true, screenName);
      const visible = BarLayout.visibleIn(zone, screenName);
      const current = visible.indexOf(id);
      const slot = current >= 0 && index > current ? index - 1 : index;
      const others = visible.filter(v => v !== id);
      const full = layout[zone].filter(v => v !== id);
      const at = slot < others.length ? full.indexOf(others[slot])
               : others.length > 0 ? full.indexOf(others[others.length - 1]) + 1
               : full.length;
      BarLayout.move(id, zone, at, screenName);
    }
  }


  // the tabs follow the style: the hub and the live activities are the island's
  // the strip's and the island's own pages: Layout, Look, Monitors. The hub and the live
  // activities are sidebar pages of their own (Island style).
  sections: [{label: "Layout", value: "layout"}, {label: "Look", value: "appearance"}, {label: "Monitors", value: "monitor"}]
  current: tab
  onPicked: value => tab = value

  settings: Component {
    Column {
      width: parent.width
      // the style decides what the rest of the page has: it sits above every tab
      Column {
        width: parent.width
        KitLabel { text: "STYLE" }
        KitRow {
          label: "Bar style"
          hint: (root.island ? "One pill with a hub and live activities" : "A strip along the screen edge")
          wide: true
          KitSegments {
            model: [{label: "Solid", value: "solid"}, {label: "Island", value: "island"}]
            current: ShellSettings.barStyle
            onPicked: value => ShellSettings.set("barStyle", value)
          }
        }
        KitGrouper {}
      }
      KitSelect {
        visible: root.roles.length > 1 && !BarLayout.shared && (root.tab === "layout" || root.tab === "monitor")
        label: "Monitor"
        hint: "The one Layout and Monitors edit"
        model: root.roles.map(n => ({label: (BarLayout.roleOf(n) === "main" ? "Main · " : "Extra · ") + n, value: n}))
        current: root.screenName
        onPicked: value => root.screenName = value
      }
      Column {
        property bool kitUnboxed: true
        width: parent.width
        spacing: Theme.settingsRowInset   // a section's own bottom padding is the other half of the standard gap
        visible: root.tab === "layout"
        Column {
          width: parent.width
          visible: root.island
          KitLabel { text: "CLOCK" }
          KitRow {
            label: "Show the clock"
            hint: "Off: the pill shows only its modules"
            KitSwitch { checked: BarLayout.islandClock(root.screenName); onToggled: BarLayout.setIslandClock(root.screenName, !checked) }
          }
          KitGrouper {}
        }
        // its own group: the caption takes the same inset as the other sections' (KitGrouper)
        Column {
          width: parent.width
          KitLabel { text: "LAYOUT"; about: "Drag modules between rows" }
          BarArrangement {
            id: editor
            showOverview: false
            showAvailable: true
            width: parent.width
            scope: root.screenName
            island: root.island
            clockVisible: BarLayout.islandClock(root.screenName)
            extraZones: root.children.map(b => "bar:" + b.id)
            extraBars: root.children
            onDraggingChanged: root.arranging = dragging
            selectedId: root.selectedModule
            idsOf: zone => root.ids(zone)
            labelOf: id => BarLayout.isSeparator(id) ? "Separator" : root.module(id)?.label ?? id
            iconOf: id => BarLayout.isSeparator(id) ? "layout" : BarLayout.icon(id)
            tileOf: id => root.island && BarLayout.isTile(id)
            accepts: (id, zone) => root.canPlace(id, zone)
            zoneLabel: zone => root.zoneLabel(zone)
            scrollViewport: root.viewport
            onSelected: id => root.selectModule(id)
            onMoved: (id, zone, index) => root.drop(id, zone, index)
            onRemoved: id => root.removeModule(id)
          }
          Item {
            property bool kitUnboxed: true    // KitGrouper: the buttons stand on the page, not a row
            width: parent.width
            height: layoutButtons.height
            Row {
              id: layoutButtons
              anchors.right: parent.right
              spacing: Theme.gapMedium
              KitButton { text: "Undo"; visible: root.undoStack.length > 0; onClicked: root.undo() }
              KitButton { icon: "plus"; text: "Separator"; onClicked: { const zone = root.island ? "end" : "right"; root.drop(root.newSeparator, zone, root.ids(zone).length); } }
              KitResetButton {
                changed: root.island ? BarLayout.islandCustomized(root.screenName) : BarLayout.customized(root.screenName)
                onReset: { root.remember(); root.island ? BarLayout.islandReset(root.screenName) : BarLayout.reset(root.screenName); }
              }
            }
          }
          KitGrouper {}
        }
      }
      Column {
  spacing: Theme.sectionGap

        width: parent.width
        visible: root.tab === "appearance"
        KitLabel { text: "LOOK" }
        KitRow {
          needs: root.island ? "" : "The pill belongs to the Island style"
          needsAction: "Use Island"
          onNeedsActed: ShellSettings.set("barStyle", "island")
          label: "Pill height"
          hint: "The island's height at rest"
          wide: true
          KitSegments {
            model: [{label: "Compact", value: 32}, {label: "Regular", value: 36}, {label: "Large", value: 40}]
            current: Theme.islandHeight
            onPicked: value => ShellSettings.setLook("pillHeight", value, "island")
          }
        }
        KitRow {
          label: "Icon size"
          hint: "The icons on the bar"
          wide: true
          KitSegments { model: [{label: "Small", value: 0}, {label: "Medium", value: 2}, {label: "Large", value: 4}]; current: ShellSettings.barIconGrow; onPicked: value => ShellSettings.setLook("barIconGrow", value) }
        }
        KitRow {
          label: "Separator spacing"
          hint: "Room on each side of a line"
          wide: true
          KitSegments { model: [{label: "Tight", value: 2}, {label: "Normal", value: 5}, {label: "Wide", value: 8}]; current: ShellSettings.barGap; onPicked: value => ShellSettings.setLook("barGap", value) }
        }
        KitRow {
          label: "Separator lines"
          hint: "Between neighbouring modules"
          needs: root.island ? "Solid style only" : ""
          needsAction: "Use Solid"
          onNeedsActed: ShellSettings.set("barStyle", "solid")
          KitSwitch { checked: ShellSettings.barSeparators; onToggled: ShellSettings.setLook("barSeparators", !checked) }
        }
        KitLine {}
        KitLabel { text: "BEHAVIOUR" }
        KitRow {
          label: "Right click opens options"
          hint: "On a module: its settings here"
          KitSwitch { checked: ShellSettings.barRightSettings; onToggled: ShellSettings.set("barRightSettings", !checked) }
        }
        KitGrouper {}
      }
      Column {
        width: parent.width
        visible: root.tab === "monitor"
        KitLabel { text: "MONITOR" }
        KitRow {
          label: "Show bar"
          hint: root.screenName
          KitSwitch { checked: root.barOn; onToggled: BarLayout.setBarOn(root.screenName, !checked) }
        }
        KitRow {
          visible: Quickshell.screens.length > 1
          label: "Same bar on every monitor"
          hint: "Off: each monitor gets its own"
          KitSwitch { checked: BarLayout.shared; onToggled: { BarLayout.setShared(!checked); root.screenName = BarLayout.mainScreen(); } }
        }
        KitSelect {
          visible: Quickshell.screens.length > 1
          label: "Main monitor"
          hint: "Automatic prefers an external monitor"
          model: [{label: "Automatic", value: ""}].concat(Quickshell.screens.map(s => ({label: s.name, value: s.name})))
          current: BarLayout.mainPick
          onPicked: value => { BarLayout.setMainPick(value); root.screenName = BarLayout.mainScreen(); }
        }
        KitText {
          property bool kitUnboxed: true
          width: parent.width
          text: Quickshell.screens.length > 1 ? "Choose the monitor above before editing a separate layout." : "Connect another monitor to configure a separate bar."
          color: Theme.muted
          wrapMode: Text.WordWrap
        }
        KitRow {
          visible: root.other !== "" && !BarLayout.shared
          label: "Copy layout"
          KitButton { text: "From " + root.other; onClicked: { root.remember(); root.island ? BarLayout.islandCopy(root.other, root.screenName) : BarLayout.copyLayout(root.other, root.screenName); } }
        }
        KitGrouper {}
      }
      KitText { width: parent.width; visible: root.layoutError !== ""; text: root.layoutError; color: Theme.red; wrapMode: Text.WordWrap }
      KitGrouper {}
    }
  }

}
