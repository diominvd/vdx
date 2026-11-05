import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.apps.capture
import qs.apps.shellmanager
import qs.bar.island
import qs.components
import qs.config
import qs.kit

// Top bar for one screen. Modules come from BarLayout (three zones, order,
// switched-off ones); separators sit between neighbours of a zone only. The
// Shell button opens the Shell Manager.
//
// Bar › Style island: no strip and no zones — the Island (bar/island) is the
// whole bar and every module opens out of it. The window is clear and as tall
// as the open island; its input mask is the island alone.
PanelWindow {
  id: root

  required property var modelData   // the screen, injected by Variants

  // id -> the module's Component, made for this bar
  readonly property var modules: faces.map

  ModuleFaces { id: faces; bar: root }

  // a module's options in the Shell Manager (a right click on it): an app's
  // module too, on its page under Bar modules (notifications: its own page)
  function openSettings(id) {
    // the hub's own: "hub" and "hub:<block>" open its page (a block's options unfolded);
    // "hubchip:<module>" is a chip or a tile, the module's options, else the hub page
    if (id === "hub" || id.startsWith("hub:")) { ShellIpc.call("shell", "open", [id]); return; }
    if (id.startsWith("hubchip:")) {
      const mod = id.slice(8);
      const known = ShellAppsService.entries.find(a => a.module === mod);
      const hasPage = known ? !!known.moduleSettings : !!BarLayout.modules.find(p => p.id === mod)?.settings;
      ShellIpc.call("shell", "open", [hasPage ? "modules:" + mod : "hub"]);
      return;
    }
    const app = ShellAppsService.entries.find(a => a.module === id) ?? null;
    const has = app ? !!app.moduleSettings : !!BarLayout.modules.find(p => p.id === id)?.settings;
    if (has) ShellIpc.call("shell", "open", ["modules:" + id]);
  }

  component Zone: Row {
    id: zone

    property string name
    property var modules: ({})

    readonly property var ids: Theme.island ? [] : BarLayout.visibleIn(zone.name, root.modelData.name)
    // folded into the Folder for want of room (BarLayout.overflow), and the rest
    readonly property var folded: BarLayout.overflow[root.modelData.name] ?? []
    readonly property var shown: ids.filter(id => !folded.includes(id))
    // shown modules whose face draws nothing (no width, or hidden): no
    // separator for them, the next one looks past them
    property var blank: []
    readonly property var drawn: shown.filter(id => !blank.includes(id))
    function setBlank(id, on) {
      const has = blank.includes(id);
      if (on && !has) blank = blank.concat([id]);
      else if (!on && has) blank = blank.filter(b => b !== id);
    }

    spacing: Theme.moduleSpacing
    onIdsChanged: root.scheduleFold()

    Repeater {
      model: zone.ids

      Row {
        id: cell

        required property string modelData
        readonly property bool custom: BarLayout.isSeparator(modelData)
        // folded: hidden, and no face here — the Folder makes it (one popup, one IPC target)
        readonly property bool folded: zone.folded.includes(modelData)
        readonly property bool blank: !custom && !folded && (slot.width <= 0 || !(slot.item?.visible ?? false))
        readonly property int at: zone.drawn.indexOf(modelData)

        onBlankChanged: zone.setBlank(modelData, blank)
        Component.onCompleted: zone.setBlank(modelData, blank)
        visible: !folded
        spacing: Theme.moduleSpacing

        // a custom separator is its own line, always drawn; the automatic one sits
        // between two modules (none next to a custom one)
        Separator {
          anchors.verticalCenter: parent.verticalCenter
          visible: cell.custom || (cell.at > 0 && !BarLayout.isSeparator(zone.drawn[cell.at - 1]))
          ruled: cell.custom || ShellSettings.barSeparators
        }

        // the module; a right click on it opens its options. A pointer handler,
        // not an overlay: hover, the cursor and the wheel stay with the module
        Item {
          visible: !cell.custom
          anchors.verticalCenter: parent.verticalCenter
          width: slot.width
          height: slot.height

          Loader {
            id: slot
            sourceComponent: cell.folded ? null : zone.modules[cell.modelData] ?? null
            // the width it takes, kept for when it is folded
            onWidthChanged: if (!cell.folded && !cell.custom) root.noteWidth(cell.modelData, width)
          }

          TapHandler {
            acceptedButtons: Qt.RightButton
            enabled: ShellSettings.barRightSettings
            onTapped: root.openSettings(cell.modelData)
          }
        }
      }
    }
  }

  screen: modelData
  anchors {
    top: true
    left: true
    right: true
  }
  // island style: tall enough for a module's popup opened in the island
  // while the island's launcher or keybinds are dimming the screen, the window is the whole screen
  implicitHeight: Theme.island ? Math.round(modelData.height * (islandItem?.dimming ? 1 : 0.92)) : Theme.barHeight
  // a hidden island (no clock, nothing beside it) with no child bar showing
  // leaves the edge to windows
  readonly property bool childrenShown: edgeLeft.width + edgeRight.width + besideLeft.width + besideRight.width > 0
  exclusiveZone: islandItem?.hidden && !childrenShown ? 0 : Theme.barEdge
  // while a popup is open, a click into it (a text field) takes the keyboard;
  // otherwise the bar never does
  WlrLayershell.keyboardFocus: PopupManager.current || (islandItem?.takesKeys ?? false)
    ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  color: Theme.island || morphing ? "transparent" : Theme.background0

  mask: Theme.island ? islandMask : null

  // the dimmed screen behind the island (its launcher / keybinds): a click on it closes the island's view
  Rectangle {
    id: dimLayer
    anchors.fill: parent
    z: -1
    color: Theme.scrim
    opacity: root.islandItem?.dimming ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { enabled: Motion.panels; NumberAnimation { duration: Motion.ms(160); easing.type: Motion.easing } }

    MouseArea {
      anchors.fill: parent
      enabled: root.islandItem?.dimming ?? false
      onClicked: root.islandItem?.collapse()
    }
  }

  Region {
    id: islandMask
    item: root.islandItem && !root.islandItem.hidden ? root.islandItem.shape : null

    Region { item: root.islandItem?.dimming ? dimLayer : null }

    Region { item: root.islandItem?.bubble ?? null }
    Region { item: edgeLeft }
    Region { item: edgeRight }
    Region { item: besideLeft }
    Region { item: besideRight }
  }

  // ---- child bars ----
  // the child bars already on show, by spot: one that is new there (its first
  // module, a drop on another spot) grows in
  property KitSeen childSeen: KitSeen { motion: Theme.island ? Motion.island : Motion.bar }
  // BarLayout.barsOn this screen, in this bar's row: a side (left | right) at the screen's
  // edge or beside the centre (the island, the centre zone). Island style: an
  // island each (IslandChild), framed like the island; solid: a raised group in the strip.
  component ChildGroup: Row {
    id: group

    property string side
    property string place

    readonly property real band: Theme.island ? Theme.islandHeight : Theme.barHeight - 8

    y: Theme.island ? Theme.islandTop : Math.round((Theme.barHeight - band) / 2)
    spacing: Theme.gapMedium

    Repeater {
      model: BarLayout.barsOn(root.modelData.name).filter(b => b.side === group.side && b.place === group.place
                                                                && BarLayout.barModules(root.modelData.name, b.id).length > 0)

      IslandChild {
        id: child
        bar: root
        band: group.band

        property real grown: 1
        opacity: grown
        scale: 0.8 + 0.2 * grown
        NumberAnimation { id: growIn; target: child; property: "grown"; from: 0; to: 1; duration: Motion.normal; easing.type: Motion.easing }
        Component.onCompleted: if (root.childSeen.arrived(child.modelData.id + "/" + group.side + "/" + group.place)) growIn.start()
      }
    }
  }

  // island style: where a module's popup opens — the child bar's island it
  // sits in (IslandChild), or the island
  function popupHost(item) {
    for (let p = item; p; p = p.parent)
      if (p.hostsPopups === true) return p;
    return root.islandItem;
  }

  // the centre the "beside" groups hold on to, and the gap they keep
  readonly property real centreX: Theme.island ? islandLoader.x : centerZone.x
  readonly property real centreWidth: Theme.island ? islandLoader.width : centerZone.width
  readonly property real childGap: Theme.gapMedium
  // the island's back bubble takes room on its left while a module is open
  readonly property real bubbleRoom: (root.islandItem?.bubble?.reveal ?? 0) * (Theme.islandHeight + Theme.gapMedium)

  ChildGroup {
    id: edgeLeft
    side: "left"; place: "edge"
    x: Theme.island ? Theme.islandTop * 2 : leftZone.x + leftZone.width + (leftZone.width > 0 ? root.childGap : 0)
  }
  ChildGroup {
    id: edgeRight
    side: "right"; place: "edge"
    x: Theme.island ? root.width - width - Theme.islandTop * 2
                    : rightZone.x - width - (rightZone.width > 0 ? root.childGap : 0)
  }
  // no centre to hold on to (a hidden island, an empty centre zone): the
  // groups meant for it meet in the middle of the screen instead
  readonly property bool centreGone: Theme.island ? (root.islandItem?.hidden ?? false) : centerZone.width === 0
  readonly property real besideJoin: besideLeft.width > 0 && besideRight.width > 0 ? root.childGap : 0
  readonly property real besideStart: (root.width - besideLeft.width - besideRight.width - besideJoin) / 2

  ChildGroup {
    id: besideLeft
    side: "left"; place: "island"
    x: root.centreGone ? root.besideStart : root.centreX - width - root.childGap - root.bubbleRoom
  }
  ChildGroup {
    id: besideRight
    side: "right"; place: "island"
    x: root.centreGone ? root.besideStart + besideLeft.width + root.besideJoin
                       : root.centreX + root.centreWidth + root.childGap
  }

  Zone {
    id: leftZone
    name: "left"
    modules: root.modules
    anchors { left: parent.left; leftMargin: Theme.edgeMargin; verticalCenter: parent.verticalCenter }
  }

  Zone {
    id: centerZone
    name: "center"
    modules: root.modules
    anchors.centerIn: parent
  }

  Zone {
    id: rightZone
    name: "right"
    modules: root.modules
    anchors { right: parent.right; rightMargin: Theme.edgeMargin; verticalCenter: parent.verticalCenter }
  }

  // ---- overflow ----
  // Solid style: LEFT and RIGHT keep to their side of the centre (and of the
  // child bars); what does not fit folds into the Folder, from the centre
  // outwards, and comes back once there is room. Worked out from each face's
  // last width, so a folded face (not made here) still counts. No Folder on
  // this bar: nothing folds.
  readonly property int foldGap: 24            // kept free between a side and the centre
  property var faceWidths: ({})                // module id -> px

  function noteWidth(id, w) {
    if (w <= 0 || faceWidths[id] === w) return;
    faceWidths[id] = w;
    scheduleFold();
  }
  function scheduleFold() { Qt.callLater(root.computeFold); }

  // a zone's width with these ids, as Zone lays them out
  function zoneWidth(ids) {
    let w = 0;
    for (let i = 0; i < ids.length; i++) {
      if (i > 0) w += Theme.moduleSpacing;
      if (BarLayout.isSeparator(ids[i])) { w += separatorProbe.implicitWidth; continue; }
      if (i > 0 && !BarLayout.isSeparator(ids[i - 1])) w += separatorProbe.implicitWidth + Theme.moduleSpacing;
      w += faceWidths[ids[i]] ?? 0;
    }
    return w;
  }

  // what leaves `ids` (taken in `outward` order) until it fits `room`
  function fold(ids, room, outward) {
    let kept = ids.slice();
    const out = [];
    for (const id of outward) {
      if (zoneWidth(kept) <= room) break;
      if (id === "folder") continue;
      out.push(id);
      kept = kept.filter(x => x !== id);
    }
    return out;
  }

  function computeFold() {
    const screen = root.modelData.name;
    const left = BarLayout.visibleIn("left", screen);
    const right = BarLayout.visibleIn("right", screen);
    const folder = left.concat(BarLayout.visibleIn("center", screen), right).includes("folder");
    if (Theme.island || !folder || root.width <= 0) { BarLayout.setOverflow(screen, []); return; }
    const centreStart = centerZone.x - (besideLeft.width > 0 ? besideLeft.width + root.childGap : 0);
    const centreEnd = centerZone.x + centerZone.width + (besideRight.width > 0 ? besideRight.width + root.childGap : 0);
    const leftRoom = centreStart - Theme.edgeMargin - root.foldGap - (edgeLeft.width > 0 ? edgeLeft.width + root.childGap : 0);
    const rightRoom = root.width - Theme.edgeMargin - centreEnd - root.foldGap - (edgeRight.width > 0 ? edgeRight.width + root.childGap : 0);
    BarLayout.setOverflow(screen, fold(left, leftRoom, left.slice().reverse()).concat(fold(right, rightRoom, right)));
  }

  onWidthChanged: scheduleFold()
  Connections { target: centerZone; function onWidthChanged() { root.scheduleFold(); } }
  Connections { target: edgeLeft; function onWidthChanged() { root.scheduleFold(); } }
  Connections { target: edgeRight; function onWidthChanged() { root.scheduleFold(); } }
  Connections { target: besideLeft; function onWidthChanged() { root.scheduleFold(); } }
  Connections { target: besideRight; function onWidthChanged() { root.scheduleFold(); } }
  Connections { target: Theme; function onIslandChanged() { root.scheduleFold(); } }

  // the width of one "|" with its room, for zoneWidth
  Separator {
    id: separatorProbe
    visible: false
    onImplicitWidthChanged: root.scheduleFold()
  }

  // ---- capture ----
  // Window in the capture overlay picks the shell's own surfaces too: an open
  // popup, the island, the child bars' islands, the strip. Layout coordinates;
  // the window sits at the screen's top left.
  Connections {
    target: CaptureService
    function onTargetsAsked() { CaptureService.addTargets(root.captureTargets()); }
  }

  function captureTargets() {
    const sx = root.modelData.x, sy = root.modelData.y;
    const rectOf = item => {
      const p = item.mapToItem(root.contentItem, 0, 0);
      return { x: sx + p.x, y: sy + p.y, width: item.width, height: item.height };
    };
    const out = [];
    const pop = PopupManager.current;
    if (pop?.visible && pop.bar === root && !pop.inIsland && pop.anchorX >= 0)
      out.push({ x: sx + (pop.alignLeft ? pop.anchorX : pop.anchorX + 1 - pop.width), y: sy + Theme.barEdge + Theme.popupGap,
                 width: pop.width, height: pop.height });
    if (!Theme.island) {
      out.push({ x: sx, y: sy, width: root.width, height: Theme.barHeight });
      return out;
    }
    if (root.islandItem && !root.islandItem.hidden) out.push(rectOf(root.islandItem.shape));
    const walk = item => {
      for (let i = 0; i < item.children.length; i++) {
        const c = item.children[i];
        if (!c.visible) continue;
        if (c.hostsPopups === true) { if (c.width > 0 && c.opacity > 0.5) out.push(rectOf(c)); }
        else walk(c);
      }
    };
    walk(root.contentItem);
    return out;
  }

  // island style: the Island; BarPopup opens a module's popup in it
  readonly property Item islandItem: islandLoader.item

  Loader {
    id: islandLoader
    active: Theme.island
    anchors.horizontalCenter: parent.horizontalCenter
    y: Theme.islandTop

    sourceComponent: Island {
      bar: root
      modules: root.modules
      onSettings: id => root.openSettings(id)
    }
  }

  // ---- modules asked for by id ----
  // A module no bar draws (a hub tile, a live activity's target) has no popup. Asked to
  // open by BarLayout.openModule, it is made here, its `openPopup()` is called (every module
  // with a popup has one; without it, its options open), and it is let go once no popup is open.
  property var hosted: []
  Connections {
    target: BarLayout
    function onHostRequested(id, screen) {
      if (screen !== "" && screen !== root.modelData.name) return;
      if (!root.hosted.includes(id)) root.hosted = root.hosted.concat([id]);
    }
  }
  Connections {
    target: PopupManager
    function onCurrentChanged() { if (PopupManager.current === null) root.hosted = []; }
  }
  // an `openPopup()` that opens no popup (the capture overlay) leaves nothing to wait for
  Timer { id: hostedSettle; interval: 100; onTriggered: if (PopupManager.current === null) root.hosted = [] }
  Repeater {
    model: root.hosted
    Loader {
      required property string modelData
      visible: false
      sourceComponent: root.modules[modelData] ?? null
      onLoaded: {
        if (item.openPopup) { item.openPopup(); hostedSettle.restart(); }
        else { root.hosted = root.hosted.filter(h => h !== modelData); root.openSettings(modelData); }
      }
    }
  }

  // ---- solid ⇄ island ----
  // Switching the style: a plate in the bar's colour stretches between the strip and the
  // pill (the strip shrinks into the pill, the pill spreads into the strip), then fades to
  // show the new bar. `morph` is 1 at the strip, 0 at the pill. Off with Animations › Bar.
  property bool morphing: false
  property real morph: 1
  property rect pillRect: Qt.rect(width / 2 - 60, Theme.islandTop, 120, Theme.islandHeight)

  // the pill as it last was (it is gone in the strip)
  function samplePill() {
    const shape = islandItem?.shape;
    if (!Theme.island || !shape || shape.width <= 0) return;
    const p = shape.mapToItem(root.contentItem, 0, 0);
    pillRect = Qt.rect(p.x, p.y, shape.width, shape.height);
  }
  Connections {
    target: root.islandItem?.shape ?? null
    ignoreUnknownSignals: true
    function onWidthChanged() { root.samplePill(); }
    function onHeightChanged() { root.samplePill(); }
    function onXChanged() { root.samplePill(); }
  }
  onIslandItemChanged: Qt.callLater(samplePill)

  Connections {
    target: Theme
    function onIslandChanged() {
      if (!Motion.bar) return;
      root.samplePill();
      morphAnim.stop();
      root.morphing = true;
      plate.opacity = 1;
      root.morph = Theme.island ? 1 : 0;
      morphAnim.from = root.morph;
      morphAnim.to = Theme.island ? 0 : 1;
      morphAnim.restart();
      fadeAnim.restart();
    }
  }

  NumberAnimation { id: morphAnim; target: root; property: "morph"; duration: Motion.ms(420); easing.type: Easing.InOutCubic }
  SequentialAnimation {
    id: fadeAnim
    PauseAnimation { duration: Motion.ms(300) }
    NumberAnimation { target: plate; property: "opacity"; to: 0; duration: Motion.ms(200); easing.type: Motion.easing }
    ScriptAction { script: root.morphing = false }
  }

  Rectangle {
    id: plate
    z: 100
    visible: root.morphing
    readonly property rect pill: root.pillRect
    readonly property real m: root.morph
    x: pill.x * (1 - m)
    y: pill.y * (1 - m)
    width: pill.width + (root.width - pill.width) * m
    height: pill.height + (Theme.barHeight - pill.height) * m
    radius: Math.min(height / 2, Theme.islandRadius) * (1 - m)
    color: Theme.background0
    border.width: Theme.islandFrameWidth * (1 - m)
    border.color: Theme.background2
  }
}
