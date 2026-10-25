import QtQuick
import Quickshell
import qs.bar
import qs.config
import qs.kit

// Bar: LOOK first (solid or island, icon size, gap: every bar), then BEHAVIOUR
// (hover, right click), then what is set per monitor — MONITOR (which one, one
// bar everywhere, show it) and LAYOUT: a
// small preview of the bar with its child bars, then a row per band in groups —
// the main bar's (LEFT, CENTER, RIGHT, FOLDER), its child bars', HIDDEN — chips
// in bar order (KitChipBands). Drag a chip along a band or to another one; this
// page decides what each drop means. Island style: the main bar's bands are the
// island's — LEFT and RIGHT beside the clock in the resting pill, HUB for the
// chips when it opens. A separator (a custom "|") comes from the ADD tray under
// the bands; its chip's cross removes it.
KitColumn {
  id: root

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "layout"
  readonly property string title: "Bar"
  readonly property string subtitle: Quickshell.screens.filter(s => BarLayout.barOn(s.name)).length + " OF "
    + Quickshell.screens.length + " MONITORS"

  // groups for the Shell Manager's sidebar: a click scrolls to `y`
  // the header's Reset: these ShellSettings keys back to their defaults; the layout has its own Reset
  readonly property var resetKeys: ["barStyle", "looks", "barRightSettings"]
  readonly property bool changed: ShellSettings.changed(resetKeys)
  function reset() { ShellSettings.reset(resetKeys); }

  readonly property var jumps: [
    { key: "look",      label: "Look",      y: lookGroup.y },
    { key: "behaviour", label: "Behaviour", y: behaviourGroup.y },
    { key: "monitor",   label: "Monitor",   y: monitorGroup.y },
    { key: "layout",  label: "Layout",  y: root.barOn ? layoutGroup.y : -2 }
  ].filter(j => j.y > -2)

  readonly property string focusId: chips.dragId !== "" ? chips.dragId : chips.hoverId

  // a monitor in the role being set up (main first)
  property string screenName: BarLayout.mainScreen()
  readonly property var roles: Quickshell.screens.map(s => s.name)
    .sort((a, b) => (BarLayout.roleOf(a) === "main" ? 0 : 1) - (BarLayout.roleOf(b) === "main" ? 0 : 1))
    .filter((n, i, all) => all.findIndex(o => BarLayout.roleOf(o) === BarLayout.roleOf(n)) === i)
  readonly property string other: roles.find(n => n !== screenName) ?? ""
  readonly property var layout: BarLayout.layout(screenName)
  readonly property bool barOn: BarLayout.barOn(screenName)
  readonly property bool island: Theme.island
  // the main bar's bands, a band per child bar ("bar:<id>"), HIDDEN
  readonly property var children: BarLayout.barsOn(screenName)
  readonly property var columnZones: (island ? ["start", "end", "hub"] : ["left", "center", "right", "folder"])
    .concat(children.map(b => "bar:" + b.id), ["hidden"])
  function childOf(zone) { return zone.startsWith("bar:") ? zone.slice(4) : ""; }

  function module(id) { return BarLayout.modules.find(p => p.id === id) ?? null; }
  function ids(zone) {
    if (childOf(zone) !== "") return BarLayout.barModules(screenName, childOf(zone));
    if (island) return zone === "hidden" ? BarLayout.islandHidden(screenName) : BarLayout.islandIn(zone, screenName);
    return zone === "hidden" ? BarLayout.unplaced(screenName)
         : zone === "folder" ? BarLayout.inFolder(screenName)
         : BarLayout.visibleIn(zone, screenName);
  }

  // the ADD tray's chip: a separator still to make
  readonly property string newSeparator: "sep-new"
  // what the header says of a chip under the pointer
  function focusText(id) {
    if (id === newSeparator) return "SEPARATOR — DRAG IT BETWEEN MODULES";
    if (BarLayout.isSeparator(id)) return "SEPARATOR — A \"|\" OF ITS OWN · ITS CROSS REMOVES IT";
    return (module(id)?.label ?? "").toUpperCase() + " — " + (module(id)?.about ?? "").toUpperCase();
  }

  // the bands show placed modules only; the stored order holds the rest too,
  // so the slot is translated through its visible neighbours
  function drop(id, zone, index) {
    // a separator sits in the main bar's sides only: HIDDEN removes it, the rest
    // refuse it; the tray's chip becomes a new one where it lands
    if (BarLayout.isSeparator(id)) {
      if (zone === "folder" || childOf(zone) !== "" || zone === "hub") return;
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

  spacing: Theme.gapGroup

  // ---- look ----
  // the look of every bar: one strip, or the island alone with every module in it
  KitLabel { id: lookGroup; text: "LOOK"; value: (root.island ? "ISLAND" : "SOLID") + " · EVERY MONITOR" }

  KitRow {
    wide: true
    label: "Shape"
    hint: "Strip, or a morphing pill"

    KitSegments {
      accessibleName: "Bar shape"
      model: [
        { label: "Solid",  value: "solid" },
        { label: "Island", value: "island" }
      ]
      current: ShellSettings.barStyle
      onPicked: value => ShellSettings.set("barStyle", value)
    }
  }

  KitRow {
    wide: true
    label: "Icon size"
    hint: "Bar icons; kept for each shape"

    KitSegments {
      accessibleName: "Bar icon size"
      model: [
        { label: "Small",  value: 0 },
        { label: "Normal", value: 2 },
        { label: "Large",  value: 4 }
      ]
      current: ShellSettings.barIconGrow
      onPicked: value => ShellSettings.setLook("barIconGrow", value)
    }
  }

  KitRow {
    wide: true
    label: "Module gap"
    hint: "Kept for each shape"

    KitSegments {
      model: [
        { label: "Tight",  value: 2 },
        { label: "Normal", value: 5 },
        { label: "Wide",   value: 8 }
      ]
      current: ShellSettings.barGap
      onPicked: value => ShellSettings.setLook("barGap", value)
    }
  }

  KitRow {
    label: "Separators"
    hint: "Automatic line between modules"

    KitSwitch {
      accessibleName: "Separators"
      checked: ShellSettings.barSeparators
      onToggled: ShellSettings.setLook("barSeparators", !checked)
    }
  }

  KitLine {}

  // ---- behaviour ----
  // the clock opens the hub on a hover or a click; a right click on a module opens its options (its own page)
  KitLabel { id: behaviourGroup; text: "BEHAVIOUR" }

  KitRow {
    visible: root.island
    wide: true
    label: "Open the hub"
    hint: "Hover or click the clock"

    KitSegments {
      accessibleName: "Island hub opening behavior"
      model: [
        { label: "Hover", value: "hover" },
        { label: "Click", value: "click" }
      ]
      current: ShellSettings.clockOpens
      onPicked: value => ShellSettings.setLook("clockOpens", value)
    }
  }

  KitRow {
    visible: root.island
    label: "Show the player"
    hint: "Off: chips only"

    KitSwitch {
      accessibleName: "Show the player"
      checked: ShellSettings.hubPlayer
      onToggled: ShellSettings.setLook("hubPlayer", !checked)
    }
  }


  KitRow {
    label: "Right click opens options"
    hint: "On any bar module"

    KitSwitch {
      accessibleName: "Right click opens options"
      checked: ShellSettings.barRightSettings
      onToggled: ShellSettings.set("barRightSettings", !checked)
    }
  }

  KitLine {}

  // ---- monitor ----
  KitLabel { id: monitorGroup; text: "MONITOR" }

  KitChoices {
    visible: root.roles.length > 1 && !BarLayout.shared
    width: parent.width
    stretch: true
    model: root.roles.map(n => ({ label: (BarLayout.roleOf(n) === "main" ? "Main · " : "Extra · ") + n, value: n,
                                  icon: BarLayout.isInternal(n) ? "laptop" : "monitor" }))
    current: root.screenName
    onPicked: value => root.screenName = value
  }

  KitSelect {
    visible: Quickshell.screens.length > 1 && !BarLayout.shared
    label: "Main monitor"
    hint: "Automatic: the external one"
    model: [{ label: "Automatic", value: "" }].concat(Quickshell.screens.map(s => ({ label: s.name, value: s.name })))
    current: BarLayout.mainPick
    onPicked: value => {
      BarLayout.setMainPick(value);
      root.screenName = BarLayout.mainScreen();
    }
  }

  KitRow {
    visible: Quickshell.screens.length > 1
    label: "Same bar everywhere"
    hint: BarLayout.shared ? "Every monitor shows one bar" : "Main and extra differ"

    KitSwitch {
      accessibleName: "Same bar everywhere"
      checked: BarLayout.shared
      onToggled: {
        BarLayout.setShared(!BarLayout.shared);
        root.screenName = BarLayout.mainScreen();
      }
    }
  }

  KitRow {
    label: "Show bar"
    hint: root.barOn ? "On " + root.screenName : "No bar on " + root.screenName

    KitSwitch {
      accessibleName: "Show bar"
      checked: root.barOn
      onToggled: BarLayout.setBarOn(root.screenName, !root.barOn)
    }
  }

  // the island on this monitor: off with nothing beside it, no island at all
  KitRow {
    visible: root.island && root.barOn
    label: "Island clock"
    hint: "Off: island hides when empty"

    KitSwitch {
      accessibleName: "Island clock"
      checked: BarLayout.islandClock(root.screenName)
      onToggled: BarLayout.setIslandClock(root.screenName, !checked)
    }
  }

  KitLine { visible: root.barOn }

  // ---- layout ----
  Item {
    id: layoutGroup
    readonly property bool isKitLabel: true   // KitGrouper: the group's title
    visible: root.barOn
    width: parent.width
    height: layoutActions.height

    KitLabel {
      anchors { left: parent.left; right: layoutActions.left; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
      text: "LAYOUT"
      // what the pointer is on, or how this works
      value: root.focusId !== "" ? root.focusText(root.focusId)
                                 : root.children.length > 0 ? "DRAG A CHILD BAR TO PLACE IT · ITS CROSS REMOVES IT"
                                 : root.island ? "LEFT AND RIGHT SIT BESIDE THE CLOCK" : "DRAG CHIPS TO ARRANGE"
      valueColor: root.focusId !== "" ? Theme.foreground2 : Theme.muted
    }

    Row {
      id: layoutActions
      anchors.right: parent.right
      spacing: Theme.gapSmall

      KitButton {
        visible: root.other !== "" && !BarLayout.shared
        icon: BarLayout.isInternal(root.other) ? "laptop" : "monitor"
        text: "Same as " + root.other
        onClicked: root.island ? BarLayout.islandCopy(root.other, root.screenName)
                               : BarLayout.copyLayout(root.other, root.screenName)
      }

      KitResetButton {
        changed: root.island ? BarLayout.islandCustomized(root.screenName) : BarLayout.customized(root.screenName)
        onReset: root.island ? BarLayout.islandReset(root.screenName) : BarLayout.reset(root.screenName)
      }
    }
  }

  // a glance at the bar (what does not fit a side shows as +N) with its child
  // bars, dragged there to place them; the empty framed bar adds one
  // in a box, as the font's sample: the preview stands out from the bands
  Rectangle {
    visible: root.barOn
    width: parent.width
    height: preview.height + 2 * Theme.gapLoose
    property bool kitUnboxed: true
    radius: Theme.radiusControl
    color: Theme.controlFill
    border.width: Theme.frameWidth
    border.color: Theme.gray

    BarPreview {
      id: preview
      anchors { left: parent.left; right: parent.right; margins: Theme.gapLoose; verticalCenter: parent.verticalCenter }
      screenName: root.screenName
    }
  }

  // a band per zone, the folder and HIDDEN: chips in bar order, dragged between bands
  KitChipBands {
    id: chips
    property bool kitUnboxed: true
    visible: root.barOn
    scope: root.screenName
    width: parent.width
    zones: root.columnZones
    idsOf: zone => root.ids(zone)
    labelOf: id => BarLayout.isSeparator(id) ? "Separator" : root.module(id)?.label ?? id
    iconOf: id => BarLayout.icon(id)
    lineOf: id => BarLayout.isSeparator(id)
    removable: id => BarLayout.isSeparator(id)
    sources: [{ id: root.newSeparator, label: "Separator", icon: "plus" }]
    sourceHint: "drag into a band · a click adds it on the right"
    groupOf: zone => zone === "hidden" ? "hidden" : root.childOf(zone) !== "" ? "children" : "main"
    zoneLabel: zone => root.childOf(zone) !== ""
      ? "BAR " + (root.children.findIndex(b => b.id === root.childOf(zone)) + 2)
      : ({ start: "LEFT", end: "RIGHT" })[zone] ?? zone.toUpperCase()
    emptyText: zone => root.childOf(zone) !== "" ? "empty — drag modules here; the bar shows once it has one"
                     : zone === "hidden" ? "nothing hidden"
                     : zone === "start" || zone === "end" ? "empty — beside the clock while it rests"
                     : zone === "hub" ? "empty — chips when the island opens"
                     : zone === "folder" ? "empty — modules here open from the Folder icon" : "empty"
    onDropped: (id, zone, index) => root.drop(id, zone, index)
    onRemoved: id => BarLayout.removeSeparator(id, root.screenName)
    onPicked: id => BarLayout.addSeparator(root.screenName)
  }

  KitGrouper {}
}
