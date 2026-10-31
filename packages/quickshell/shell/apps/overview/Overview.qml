import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.apps.shellmanager
import qs.components
import qs.config
import qs.kit
import qs.modules.windows
import Quickshell.Widgets
import "overview.js" as OverviewLogic

// Floating mode: TaskView (the workspaces as a strip, the chosen one's windows
// in a grid). The other modes:
// Niri's overview as one canvas: every workspace of the focused
// monitor is a row, and each window sits where it really is, so a scrolling
// workspace runs sideways past the screen. Rows include empty workspace gaps
// and a spare workspace at each end, on the dimmed wallpaper. The wheel
// held down pans, the wheel turned scrolls (shift: sideways, Ctrl: zoom),
// arrows or hjkl step a row. A click on a window focuses it, on a workspace goes
// there; a window dragged with the left button onto another workspace moves there,
// the canvas scrolling by itself near the edges. Enter goes to
// the workspace in the middle, Escape or a click on the dimmed screen closes.
ScrimWindow {
  id: root

  property var sessionMonitor: null
  readonly property var monitor: sessionMonitor ?? Hyprland.focusedMonitor
  readonly property real mw: (monitor?.width ?? 1920) / (monitor?.scale ?? 1)
  readonly property real mh: (monitor?.height ?? 1080) / (monitor?.scale ?? 1)

  // Canvas units are logical pixels; each row is one monitor high.
  readonly property real gap: 90
  readonly property real pitch: mh + gap
  // floating windows overlap, so that mode gets the task view instead of the canvas
  readonly property bool taskView: WindowsService.mode === "floating"

  // Shell Manager › Windows › Overview (ModuleSettings "overview")
  readonly property bool previews: ModuleSettings.get("overview", "previews", true)
  readonly property bool names: ModuleSettings.get("overview", "names", true)
  readonly property bool dimOthers: ModuleSettings.get("overview", "dim", true)
  readonly property real wheelSpeed: ({ slow: 0.5, normal: 1, fast: 1.7 })[ModuleSettings.get("overview", "wheel", "normal")] ?? 1

  // + / - and Ctrl + wheel: fewer rows big, or more rows small
  property real zoomLevel: 1
  Behavior on zoomLevel { enabled: Motion.panels && root.glide; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }

  // 0 -> 1 as it opens: the rows come in one after another, from the middle one out
  property real intro: 1
  NumberAnimation { id: introAnim; target: root; property: "intro"; from: 0; to: 1; duration: Motion.slow; easing.type: Motion.easing }
  readonly property real zoom: height * 0.42 / mh * zoomLevel

  // the rows: the monitor's workspaces that hold a window, and the one in use, lowest
  // first; and, like Niri, an empty one past each end that holds windows (the next
  // workspace to move a window to; ten at most)
  readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
  // Freeze row identities for one overview session. If a move empties a workspace,
  // removing that row can reset the Repeater and recreate every remaining preview.
  property var sessionRows: []
  readonly property var rowIds: sessionRows.length ? sessionRows : [activeId]
  readonly property int rowCount: rowIds.length
  // the view: the canvas point in the middle of the screen
  property real camX: 0
  property real camY: 0
  // a key step glides, the wheel and a drag follow the hand
  property bool glide: false
  readonly property int centreIndex: Math.max(0, Math.min(rowCount - 1, Math.round((camY - mh / 2) / pitch)))
  readonly property int centreId: rowIds[centreIndex] ?? activeId

  Behavior on camX { enabled: Motion.panels && root.glide; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
  Behavior on camY { enabled: Motion.panels && root.glide; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }

  function rowTop(i) { return i * pitch; }
  function pan(dx, dy) {
    camX = Math.max(extent[0], Math.min(extent[1], camX + dx));
    const firstRowCentre = mh / 2;
    const lastRowCentre = (rowCount - 1) * pitch + mh / 2;
    camY = Math.max(firstRowCentre - pitch / 2, Math.min(lastRowCentre + pitch / 2, camY + dy));
  }
  function step(dx, dy) { touched = true; glide = true; pan(dx, dy); }
  function drag(dx, dy) { touched = true; glide = false; pan(dx, dy); }
  // the wheel: Ctrl zooms; a touchpad gives pixels on both axes, a wheel notches
  // (Shift turns them sideways)
  function scroll(e) {
    if (taskView) return;
    if (e.modifiers & Qt.ControlModifier) {
      zoomBy(e.angleDelta.y > 0 ? 1.1 : 1 / 1.1);
      return;
    }
    const smooth = e.pixelDelta.x !== 0 || e.pixelDelta.y !== 0;
    // a notch is 120 units: three of them carry a row across the screen's height
    const k = (smooth ? 1.5 : 3) * wheelSpeed;
    let dx = k * (smooth ? e.pixelDelta.x : e.angleDelta.x);
    let dy = k * (smooth ? e.pixelDelta.y : e.angleDelta.y);
    if ((e.modifiers & Qt.ShiftModifier) && dx === 0) {
      dx = dy;
      dy = 0;
    }
    touched = true;
    glide = !smooth;
    pan(-dx / zoom, -dy / zoom);
  }
  function zoomBy(factor) {
    touched = true;
    zoomLevel = Math.max(0.1, Math.min(1.6, zoomLevel * factor));
  }

  // ---- viewport geometry ----
  // The full horizontal stretch of the overview, including a possible append slot.
  property bool touched: false
  readonly property var extent: {
    let lo = 0, hi = mw;
    for (const w of displayWindows) {
      lo = Math.min(lo, w.x); hi = Math.max(hi, w.x + w.width);
    }
    if (dragPhase === "dragging" && WindowsService.mode === "scrolling" && carriedWindow) {
      for (const id of rowIds) {
        const slot = OverviewLogic.appendSlot(displayWindows, id, carriedWindow, mw, mh, columnGap);
        if (slot) hi = Math.max(hi, slot.x + slot.width);
      }
    }
    return [lo, hi];
  }
  function fit() {
    const span = extent[1] - extent[0];
    camX = (extent[0] + extent[1]) / 2;
    if (width > 0 && height > 0) zoomLevel = Math.max(0.1, Math.min(1, width * 0.9 / (span * height * 0.42 / mh)));
  }
  onWidthChanged: if (open && !touched) fit()
  onHeightChanged: if (open && !touched) fit()
  // the windows' places arrive just after it opens: fit again until the view is touched
  onExtentChanged: if (open && !touched) fit();
  function goTo(id) {
    open = false;
    Hypr.call("hl.dispatch(hl.dsp.focus({ workspace = " + id + " }))");
  }
  function focus(t) {
    if (!t) return;
    open = false;
    Hypr.call("hl.dispatch(hl.dsp.focus({ window = \"" + Hypr.target(t) + "\" }))");
  }

  // ---- window geometry snapshot ----
  // One geometry snapshot drives both hit testing and the visible cards. During
  // a drop it stays frozen until the compositor has finished its transaction.
  property var displayWindows: []
  ListModel { id: windowModel }
  readonly property var displayRects: OverviewLogic.rectMap(displayWindows)
  readonly property real columnGap: Math.max(2, WindowsService.opts.gapsIn * 2 + (WindowsService.opts.borders ? 4 : 0))
  property string moveError: ""
  function readWindows() {
    const result = [];
    for (const t of Hyprland.toplevels.values) {
      const ipc = t.lastIpcObject;
      if (t.workspace?.monitor !== monitor || t.workspace.id < 1 || !ipc?.at || !ipc?.size) continue;
      result.push({ address: t.address, workspace: t.workspace.id,
        x: ipc.at[0] - monitor.x, y: ipc.at[1] - monitor.y,
        width: Math.max(1, ipc.size[0]), height: Math.max(1, ipc.size[1]), floating: ipc.floating === true });
    }
    return result;
  }
  function acceptGeometry(windows) {
    displayWindows = windows;
    const addresses = windows.map(w => w.address);
    for (let i = windowModel.count - 1; i >= 0; i--) {
      if (!addresses.includes(windowModel.get(i).address)) windowModel.remove(i);
    }
    const present = new Set();
    for (let i = 0; i < windowModel.count; i++) present.add(windowModel.get(i).address);
    for (const w of windows) if (!present.has(w.address)) windowModel.append({ address: w.address });
    // Add newly needed rows at the ends, preserving existing row identities.
    const next = OverviewLogic.rows(windows, activeId);
    if (!sessionRows.length) sessionRows = next;
    else {
      const first = Math.min(sessionRows[0], next[0]);
      const last = Math.max(sessionRows[sessionRows.length - 1], next[next.length - 1]);
      const ids = [];
      for (let id = first; id <= last; id++) ids.push(id);
      if (ids.join() !== sessionRows.join()) sessionRows = ids;
    }
  }
  signal settled()
  Timer { id: captureTimer; interval: 120; onTriggered: root.settled() }
  Timer {
    id: geometryRefresh
    interval: 45
    onTriggered: { Hyprland.refreshToplevels(); geometryRead.restart(); }
  }
  Timer {
    id: geometryRead
    interval: 80
    onTriggered: if (root.open && root.dragPhase === "") {
      root.acceptGeometry(root.readWindows()); captureTimer.restart();
    }
  }
  Connections {
    target: root.open ? Hyprland : null
    function onRawEvent(event) {
      if (root.dragPhase === "" && ["movewindowv2", "openwindow", "closewindow", "changefloatingmode", "fullscreen", "configreloaded"].includes(event.name)) geometryRefresh.restart();
    }
  }

  // ---- drag transaction ----
  // idle -> dragging -> committing -> landing -> capturing -> releasing.
  // Cancellation returns the same frozen picture to its source card.
  property string dragPhase: ""
  // Hyprland refuses focus(window) while an exclusive layer is present. The
  // scrolling width dispatchers operate on the focused column, so release the
  // keyboard until the compositor transaction has finished. Keep the pointer
  // surface and the overview itself in place throughout.
  WlrLayershell.keyboardFocus: open && dragPhase !== "committing"
    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  property string carriedAddress: ""
  property var carriedCard: null
  property var carriedWindow: null
  property point dragPos: Qt.point(0, 0)
  property point dragGrab: Qt.point(0, 0)
  property size dragTextureSize: Qt.size(1, 1)
  readonly property point dragWorld: Qt.point((dragPos.x - world.x) / zoom, (dragPos.y - world.y) / zoom)
  readonly property var dropIntent: dragPhase === "dragging"
    ? OverviewLogic.intent(displayWindows, rowIds, carriedWindow, dragWorld, mw, mh, pitch, columnGap,
        WindowsService.mode === "scrolling", WindowsService.opts.mfact, WindowsService.opts.newStatus === "master") : null
  property var pendingDrop: null
  property real phaseStarted: 0
  property string lastGeometryKey: ""
  property int stableSamples: 0
  readonly property bool dropping: ["landing", "capturing", "releasing", "returning"].includes(dragPhase)
  readonly property var landingRect: displayRects[carriedAddress] ?? carriedWindow

  function beginDrag(card, x, y) {
    if (!card || dragPhase !== "" || moveProcess.running || !displayRects[card.address]) return false;
    touched = true; glide = false; moveError = "";
    geometryRefresh.stop(); geometryRead.stop(); captureTimer.stop();
    carriedWindow = Object.assign({}, displayRects[card.address]);
    carriedCard = card; carriedAddress = card.address;
    dragGrab = Qt.point(x, y);
    dragPos = card.mapToItem(canvas, x, y);
    dragTextureSize = Qt.size(Math.max(1, Math.ceil(card.width * zoom)), Math.max(1, Math.ceil(card.height * zoom)));
    dragPhase = "dragging";
    dragImage.scheduleUpdate();
    return true;
  }
  function resetDrag() {
    dragPhase = ""; carriedAddress = ""; carriedCard = null; carriedWindow = null; pendingDrop = null;
    lastGeometryKey = ""; stableSamples = 0;
  }
  function stopSessionTimers() {
    geometryRefresh.stop(); geometryRead.stop(); captureTimer.stop();
    dispatchTimer.stop(); landingTimer.stop(); releaseTimer.stop();
  }
  function cancelDrag() {
    if (dragPhase !== "dragging") return;
    dragPhase = "returning";
    landingTimer.restart();
  }
  function releaseDrag() {
    if (dragPhase !== "dragging") return;
    if (!dropIntent) { cancelDrag(); return; }
    pendingDrop = Object.assign({}, dropIntent);
    dragPhase = "committing"; phaseStarted = Date.now();
    lastGeometryKey = ""; stableSamples = 0;
    moveProcess.command = ["hyprctl", "eval", OverviewLogic.moveCommand(carriedWindow, pendingDrop, displayWindows, WindowsService.mode === "scrolling")];
    // Give the layer-surface commit a turn to reach the compositor before its
    // focus dispatchers run. moveCommand also checks that focus really changed.
    dispatchTimer.restart();
  }
  function sampleCommitGeometry() {
    Hyprland.refreshToplevels();
    const windows = readWindows();
    const moved = windows.find(window => window.address === carriedAddress);
    const key = OverviewLogic.geometryKey(windows);
    stableSamples = key === lastGeometryKey ? stableSamples + 1 : 0;
    lastGeometryKey = key;
    if (dispatchTimer.running || moveProcess.running) return;
    if (moved?.workspace === pendingDrop.workspace && (stableSamples >= 2 || Date.now() - phaseStarted > 1600)) {
      acceptGeometry(windows);
      dragPhase = "landing";
      landingTimer.restart();
    } else if (Date.now() - phaseStarted > 2000) {
      moveError = "Could not move window";
      acceptGeometry(windows);
      dragPhase = "returning";
      landingTimer.restart();
    }
  }
  function finishPreviewCaptureIfReady() {
    if (Date.now() - phaseStarted <= 80
      || !(carriedCard?.previewReady || Date.now() - phaseStarted > 800)) return;
    dragPhase = "releasing";
    releaseTimer.restart();
  }
  Timer {
    id: dispatchTimer
    interval: 50
    onTriggered: if (root.open && root.dragPhase === "committing") moveProcess.running = true
  }
  Process {
    id: moveProcess
    stdout: StdioCollector { id: moveOutput }
    stderr: StdioCollector { id: moveErrors }
    onExited: (code, exitStatus) => {
      if (root.dragPhase !== "committing") return;
      if (code !== 0) {
        root.moveError = "Could not move window";
        console.warn("Overview move:", moveOutput.text, moveErrors.text);
        root.dragPhase = "returning"; landingTimer.restart();
      }
    }
  }
  Timer {
    interval: 60
    repeat: true
    running: root.open && root.dragPhase === "committing"
    onTriggered: root.sampleCommitGeometry()
  }
  Timer {
    id: landingTimer
    interval: (Motion.panels ? Motion.normal : 0) + 30
    onTriggered: {
      if (root.dragPhase === "returning") { root.resetDrag(); geometryRefresh.restart(); return; }
      if (root.dragPhase !== "landing") return;
      root.settled(); root.phaseStarted = Date.now(); root.dragPhase = "capturing";
    }
  }
  Timer {
    interval: 40
    repeat: true
    running: root.open && root.dragPhase === "capturing"
    onTriggered: root.finishPreviewCaptureIfReady()
  }
  Timer { id: releaseTimer; interval: Motion.panels ? Motion.quick : 0; onTriggered: root.resetDrag() }
  // Time-based auto-pan: no permanent frame timer and no speed change with FPS.
  Timer {
    interval: 16
    repeat: true
    running: root.open && root.dragPhase === "dragging"
    property real lastTick: 0
    onRunningChanged: lastTick = Date.now()
    onTriggered: {
      if (!root.carriedCard || !root.carriedCard.modelData) { root.resetDrag(); return; }
      const now = Date.now(), dt = Math.min(0.05, (now - lastTick) / 1000); lastTick = now;
      const margin = Math.min(canvas.width, canvas.height) * 0.12;
      const edge = (v, size) => v < margin ? -Math.min(1, 1 - v / margin) : v > size - margin ? Math.min(1, (v - size + margin) / margin) : 0;
      const dx = edge(root.dragPos.x, canvas.width), dy = edge(root.dragPos.y, canvas.height);
      if (dx || dy) root.drag(dx * 900 * dt / root.zoom, dy * 900 * dt / root.zoom);
    }
  }

  onOpenChanged: {
    Hypr.call("MouseBinds(" + !open + ")");
    if (!open) {
      resetDrag();
      stopSessionTimers();
      return;
    }
    sessionMonitor = Hyprland.focusedMonitor;
    sessionRows = [];
    acceptGeometry(readWindows());
    intro = Motion.panels ? 0 : 1;
    if (Motion.panels) introAnim.restart();
    const active = Math.max(0, rowIds.indexOf(activeId));
    glide = false; touched = false; moveError = "";
    fit(); camY = mh / 2 + active * pitch;
    Qt.callLater(() => { if (tasksLoader.item) tasksLoader.item.reset(); });
    geometryRefresh.restart();
    canvas.forceActiveFocus();
  }
  onVisibleChanged: if (!visible) { windowModel.clear(); displayWindows = []; sessionRows = []; sessionMonitor = null; }
  Component.onCompleted: Hypr.call("MouseBinds(true)")

  // the wallpaper awww draws under the windows: this monitor's own picture or the theme's
  readonly property string picture: {
    if (ShellSettings.wallpaperMode !== "image") return "";
    const own = WallpaperService.outputsFor(ThemeService.current)[monitor?.name ?? ""];
    const rel = own ?? WallpaperService.inUse;
    return rel ? WallpaperService.pathOf(rel) : "";
  }

  dim: false
  namespace: "overview"
  onDismissed: open = false

  IpcHandler {
    target: "overview"
    function toggle(): void { root.open = !root.open; }
    function open(): void { root.open = true; }
    function close(): void { root.open = false; }
  }

  Item {
    id: canvas
    anchors.fill: parent
    focus: true
    Keys.onUpPressed: root.taskView ? tasksLoader.item?.moveWin(0, -1) : root.step(0, -root.pitch)
    Keys.onDownPressed: root.taskView ? tasksLoader.item?.moveWin(0, 1) : root.step(0, root.pitch)
    Keys.onLeftPressed: root.taskView ? tasksLoader.item?.moveDesk(-1) : root.step(-root.mw / 2, 0)
    Keys.onRightPressed: root.taskView ? tasksLoader.item?.moveDesk(1) : root.step(root.mw / 2, 0)
    Keys.onPressed: event => {
      if (root.taskView) {
        if (event.key === Qt.Key_H) tasksLoader.item?.moveWin(-1, 0);
        else if (event.key === Qt.Key_L) tasksLoader.item?.moveWin(1, 0);
        else if (event.key === Qt.Key_K) tasksLoader.item?.moveWin(0, -1);
        else if (event.key === Qt.Key_J) tasksLoader.item?.moveWin(0, 1);
        else return;
        event.accepted = true;
        return;
      }
      if (event.key === Qt.Key_PageUp || event.key === Qt.Key_K) root.step(0, -root.pitch);
      else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_J) root.step(0, root.pitch);
      else if (event.key === Qt.Key_H) root.step(-root.mw / 2, 0);
      else if (event.key === Qt.Key_L) root.step(root.mw / 2, 0);
      else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) root.zoomBy(1.25);
      else if (event.key === Qt.Key_Minus) root.zoomBy(0.8);
      else return;
      event.accepted = true;
    }
    Keys.onReturnPressed: root.taskView ? tasksLoader.item?.pick() : root.goTo(root.centreId)
    Keys.onEscapePressed: root.dragPhase === "dragging" ? root.cancelDrag() : root.open = false


    // the wallpaper, dimmed: it hides the windows behind, so only the overview shows.
    // Wider than the screen: the panel grows from 96 % as it opens
    Item {
      anchors.fill: parent
      anchors.margins: -parent.width * 0.05
      clip: true

      Rectangle {
        anchors.fill: parent
        color: ShellSettings.wallpaperMode === "custom" ? ShellSettings.wallpaperColor : Theme.background1
      }
      Image {
        anchors.fill: parent
        source: root.open && root.picture !== "" ? "file://" + root.picture : ""
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.width
      }
      Rectangle { anchors.fill: parent; color: Theme.scrim }
    }

    // a click on the empty screen closes
    MouseArea {
      anchors.fill: parent
      onClicked: root.dismissed()
      // the windows' own areas leave the wheel alone, so it reaches this one from anywhere
      onWheel: wheel => root.scroll(wheel)
    }

    // the wheel held down pans the canvas
    DragHandler {
      target: null
      enabled: !root.taskView
      acceptedButtons: Qt.MiddleButton
      property real lastX: 0
      property real lastY: 0
      onActiveChanged: { lastX = 0; lastY = 0; }
      onTranslationChanged: {
        root.drag(-(translation.x - lastX) / root.zoom, -(translation.y - lastY) / root.zoom);
        lastX = translation.x;
        lastY = translation.y;
      }
    }

    // the rail: one mark per workspace, the one in the middle long
    Column {
      z: 1
      visible: !root.taskView
      anchors.left: parent.left
      anchors.leftMargin: Theme.gapWide * 2
      anchors.verticalCenter: parent.verticalCenter
      spacing: Theme.gapMedium

      Repeater {
        model: root.rowCount

        Rectangle {
          required property int index
          readonly property bool centre: index === root.centreIndex
          width: 4
          height: centre ? 28 : 14
          radius: Theme.pill(width)
          color: centre ? Theme.foreground0 : Theme.gray
          Behavior on height { enabled: Motion.controls; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
        }
      }
    }

    // the keys, at the bottom
    Rectangle {
      z: 1
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Theme.gapWide * 2
      width: hints.implicitWidth + Theme.gapWide * 3
      height: hints.implicitHeight + Theme.gapWide * 1.5
      radius: Theme.pill(height)
      color: Theme.background1
      border.width: Theme.hairline
      border.color: Theme.popupFrame

      KitText {
        id: hints
        anchors.centerIn: parent
        text: root.moveError !== "" ? root.moveError : root.taskView ? "←→ workspace  ·  ↑↓ hjkl window  ·  Enter open  ·  Esc close"
                            : "Hold the wheel to pan  ·  Drag a window to a workspace  ·  ↑↓ workspaces  ·  + − zoom  ·  Enter open  ·  Esc close"
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 2
      }
    }

    Loader {
      id: tasksLoader
      z: 1
      anchors.fill: parent
      active: root.visible && root.taskView
      sourceComponent: Component { TaskView { overview: root } }
      onLoaded: item.reset()
    }

    // the canvas: rows of workspaces and the windows on them, panned and zoomed
    Item {
      id: world
      visible: !root.taskView
      transformOrigin: Item.TopLeft
      scale: root.zoom
      x: canvas.width / 2 - root.camX * root.zoom
      y: canvas.height / 2 - root.camY * root.zoom

      Repeater {
        model: root.visible && !root.taskView ? root.rowCount : 0
        Item {
          id: space
          required property int index
          readonly property int wsId: root.rowIds[index]
          readonly property var windows: OverviewLogic.members(root.displayWindows, wsId, "")
          readonly property var append: root.dragPhase === "dragging" && WindowsService.mode === "scrolling" && root.carriedWindow
            ? OverviewLogic.appendSlot(root.displayWindows, wsId, root.carriedWindow, root.mw, root.mh, root.columnGap) : null
          readonly property bool targetRow: root.dropIntent?.workspace === wsId
          readonly property real appear: Math.max(0, Math.min(1, root.intro * 1.8 - Math.abs(index - root.centreIndex) * 0.25))
          y: root.rowTop(index) + (1 - appear) * 80
          width: root.mw
          height: root.mh
          opacity: appear
          Rectangle {
            anchors.fill: parent
            radius: Theme.radiusCard / root.zoom
            color: space.windows.length ? Theme.clear : Theme.background1
            border.width: space.targetRow && root.dropIntent.kind === "join" ? Theme.ring / root.zoom : space.windows.length ? 0 : Theme.hairline / root.zoom
            border.color: space.targetRow ? Theme.foreground0 : Theme.gray
          }
          KitText {
            x: 8; y: -root.gap * 0.7
            text: space.wsId + "   ·   " + (space.windows.length ? space.windows.length + (space.windows.length === 1 ? " window" : " windows") : "Empty")
            color: space.targetRow || space.wsId === root.centreId ? Theme.foreground0 : Theme.muted
            font.pixelSize: 36
            font.letterSpacing: 2
          }
          MouseArea { anchors.fill: parent; onClicked: root.goTo(space.wsId) }
          Rectangle {
            visible: space.append !== null
            x: space.append?.x ?? 0; y: space.append?.y ?? 0
            width: space.append?.width ?? 0; height: space.append?.height ?? 0
            radius: Theme.radiusControl
            color: Theme.background1
            opacity: space.targetRow && root.dropIntent?.kind === "append" ? 0.9 : 0.45
            border.width: Theme.ring / root.zoom
            border.color: space.targetRow && root.dropIntent?.kind === "append" ? Theme.foreground0 : Theme.gray
            Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
            KitText { anchors.centerIn: parent; text: "New column"; color: Theme.muted; font.pixelSize: 30 }
          }
        }
      }

      // A single model owns every card. Changing workspaces never destroys a
      // card, its mouse grab or its captured frame.
      Repeater {
        model: root.visible && !root.taskView ? windowModel : null
        ClippingRectangle {
          id: win
          required property string address
          readonly property var modelData: Hyprland.toplevels.values.find(t => t.address === address) ?? null
          readonly property var geometry: root.displayRects[address]
          readonly property int row: root.rowIds.indexOf(geometry?.workspace ?? -1)
          readonly property bool carried: root.carriedAddress === address
          readonly property real appear: Math.max(0, Math.min(1, root.intro * 1.8 - Math.abs(row - root.centreIndex) * 0.25))
          readonly property bool previewReady: !root.previews || (shot.hasContent && Math.abs(shot.sourceSize.width / Math.max(1, shot.sourceSize.height) - width / Math.max(1, height)) < 0.02)
          property alias picture: picture
          z: 2
          visible: row >= 0 && geometry !== undefined
          // Hovering a destination only highlights its slot. Reflow starts once
          // the drop is confirmed, so passing across a row cannot squeeze it.
          x: geometry?.x ?? 0
          y: root.rowTop(Math.max(0, row)) + (geometry?.y ?? 0) + (1 - appear) * 80
          width: geometry?.width ?? 1
          height: geometry?.height ?? 1
          radius: Theme.radiusControl
          opacity: carried && root.dragPhase !== "releasing" ? 0 : appear * (root.dimOthers && geometry?.workspace !== root.centreId && root.dropIntent?.workspace !== geometry?.workspace ? 0.45 : 1)
          color: Theme.background2
          border.width: (Hyprland.activeToplevel === modelData || hover.containsMouse ? Theme.ring : Theme.hairline) / root.zoom
          border.color: Hyprland.activeToplevel === modelData || hover.containsMouse ? Theme.foreground0 : Theme.gray
          Behavior on x { enabled: Motion.panels && root.intro === 1; NumberAnimation { duration: Motion.normal; easing.type: Motion.morph } }
          Behavior on y { enabled: Motion.panels && root.intro === 1; NumberAnimation { duration: Motion.normal; easing.type: Motion.morph } }
          Behavior on width { enabled: Motion.panels; NumberAnimation { duration: Motion.normal; easing.type: Motion.morph } }
          Behavior on height { enabled: Motion.panels; NumberAnimation { duration: Motion.normal; easing.type: Motion.morph } }
          Behavior on opacity { enabled: Motion.controls && (!win.carried || root.dragPhase === "releasing"); NumberAnimation { duration: Motion.quick } }

          Item {
            id: picture
            anchors.fill: parent
            anchors.margins: 1
            clip: true
            ScreencopyView {
              id: shot
              anchors.left: parent.left
              anchors.top: parent.top
              // Crop a frozen frame while its tile changes shape, rather than
              // stretching the application. Its next frame has the new layout.
              readonly property real aspect: sourceSize.width / Math.max(1, sourceSize.height)
              width: hasContent ? Math.max(parent.width, parent.height * aspect) : parent.width
              height: hasContent ? width / Math.max(0.01, aspect) : parent.height
              captureSource: root.visible && root.previews && win.visible ? win.modelData?.wayland ?? null : null
              live: false
              Connections { target: root; function onSettled() { if (root.previews && win.visible) shot.captureFrame(); } }
            }
            Column {
              anchors.centerIn: parent
              width: Math.max(1, parent.width - 80)
              spacing: 24
              visible: !shot.hasContent
              Image { anchors.horizontalCenter: parent.horizontalCenter; width: 160; height: 160; sourceSize: Qt.size(160, 160); source: win.modelData ? Hypr.iconOf(win.modelData) : ""; asynchronous: true }
              KitText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: win.modelData?.title ?? ""; color: Theme.muted; font.pixelSize: 34; elide: Text.ElideRight }
            }
          }
          Rectangle {
            x: 16; y: 16
            width: Math.min(cap.implicitWidth + 28, win.width - 32)
            height: cap.implicitHeight + 12
            radius: Theme.pill(height)
            color: Theme.scrim
            visible: root.names && win.modelData !== null && Hypr.classOf(win.modelData) !== ""
            KitText { id: cap; anchors.centerIn: parent; width: parent.width - 28; text: win.modelData ? Hypr.classOf(win.modelData) : ""; color: Theme.muted; font.pixelSize: 26; elide: Text.ElideRight }
          }
          MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.open && (root.dragPhase === "" || win.carried && root.dragPhase === "dragging")
            cursorShape: win.carried ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            property point pressPos: Qt.point(0, 0)
            property bool carried: false
            onPressed: mouse => { pressPos = Qt.point(mouse.x, mouse.y); carried = false; }
            onClicked: if (!carried) root.focus(win.modelData)
            onPositionChanged: mouse => {
              if (!pressed) return;
              if (!carried) {
                const dx = mouse.x - pressPos.x, dy = mouse.y - pressPos.y;
                if (dx * dx + dy * dy < Qt.styleHints.startDragDistance ** 2) return;
                carried = root.beginDrag(win, pressPos.x, pressPos.y);
              }
              if (carried) root.dragPos = hover.mapToItem(canvas, mouse.x, mouse.y);
            }
            onReleased: if (carried) root.releaseDrag()
            onCanceled: if (carried) root.cancelDrag()
          }
        }
      }

      Rectangle {
        z: 1
        visible: root.dropIntent?.kind === "join" && root.dropIntent.existing !== undefined
        x: root.dropIntent?.x ?? 0
        y: root.rowTop(root.rowIds.indexOf(root.dropIntent?.workspace ?? -1)) + (root.dropIntent?.y ?? 0)
        width: root.dropIntent?.width ?? 0; height: root.dropIntent?.height ?? 0
        radius: Theme.radiusControl
        color: Theme.background1
        border.width: Theme.ring / root.zoom
        border.color: Theme.foreground0
      }

      ClippingRectangle {
        z: 10
        visible: root.carriedWindow !== null
        x: root.dropping && root.landingRect ? root.landingRect.x : root.dragWorld.x - root.dragGrab.x
        y: root.dropping && root.landingRect ? root.rowTop(root.rowIds.indexOf(root.landingRect.workspace)) + root.landingRect.y : root.dragWorld.y - root.dragGrab.y
        width: root.dropping && root.landingRect ? root.landingRect.width : root.carriedWindow?.width ?? 1
        height: root.dropping && root.landingRect ? root.landingRect.height : root.carriedWindow?.height ?? 1
        radius: Theme.radiusControl
        opacity: root.dragPhase === "releasing" ? 0 : 1
        color: Theme.background2
        border.width: Theme.ring / root.zoom
        border.color: Theme.foreground0
        Behavior on x { enabled: Motion.panels && root.dropping; NumberAnimation { duration: Motion.normal; easing.type: Motion.morph } }
        Behavior on y { enabled: Motion.panels && root.dropping; NumberAnimation { duration: Motion.normal; easing.type: Motion.morph } }
        Behavior on width { enabled: Motion.panels && root.dropping; NumberAnimation { duration: Motion.normal; easing.type: Motion.morph } }
        Behavior on height { enabled: Motion.panels && root.dropping; NumberAnimation { duration: Motion.normal; easing.type: Motion.morph } }
        Behavior on opacity { enabled: Motion.panels; NumberAnimation { duration: Motion.quick } }
        Item {
          anchors.fill: parent
          anchors.margins: 1
          clip: true
          ShaderEffectSource {
            id: dragImage
            anchors.left: parent.left
            anchors.top: parent.top
            readonly property real aspect: (root.carriedWindow?.width ?? 1) / Math.max(1, root.carriedWindow?.height ?? 1)
            width: Math.max(parent.width, parent.height * aspect)
            height: width / aspect
            sourceItem: root.carriedCard?.picture ?? null
            textureSize: root.dragTextureSize
            live: false
          }
        }
      }
    }
  }
}
