import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.apps.auth
import qs.apps.keybinds
import qs.apps.themepicker
import qs.apps.launcher
import qs.components
import qs.config
import qs.kit
import qs.modules.audio

// The whole bar in the island style: one dark pill that morphs between
// views. compact (LEFT · clock · RIGHT) is the resting face; hub (the
// date, the track and every module as a chip) opens on a hover over the clock;
// media (the player) from the equalizer; notice
// (a new notification) pass over it for a moment. A module's popup opens
// inside the island (module): its content moves in from the BarPopup and back
// once the island has folded. The launcher and the keybinds (the hub's Launcher and Keys chips)
// open as views of their own, the same panels as their windows. A clicked view stays until a click
// outside, Escape or a second click; Escape in an app view goes back to the hub when it came from there.
//
// Compact: middle — play / pause; a click on the bare island does nothing (the
// hub opens on a hover over the clock). The wheel is a module's own (the
// volume module's, a chip's), never the island's.
Item {
  id: root

  required property PanelWindow bar
  property var modules: ({})                   // Bar's module id -> Component

  signal settings(string id)                   // a chip's right click: the module's options

  property string view: "compact"              // compact | hub | media | power | module: what was asked for
  property bool pinned: false                  // opened by a click or IPC, not a hover
  property string flash: ""                    // notice: passes over compact and media
  readonly property string shown: flash !== "" && view !== "power" && view !== "module" && !appView ? flash : view
  readonly property bool open: shown !== "compact"
  // resting with nothing to show (no clock, no modules): gone until it has
  readonly property bool hidden: shown === "compact" && compact.empty
  // the shape, for the bar's input mask
  readonly property Item shape: shape
  // the launcher and the keybinds: a text field takes the keyboard
  readonly property bool appView: view === "launcher" || view === "keybinds" || view === "looks"
  // a pinned view takes the keyboard (Escape, the power menu's arrows)
  // (a module's popup has its own grab; an app view its field)
  readonly property bool grabbing: pinned && view !== "compact" && view !== "module" && !appView
  readonly property bool takesKeys: grabbing || (pinned && appView)
  // the launcher or the keybinds dim the screen behind the island (their "Dim the background" option)
  readonly property bool dimming: appView && view !== "looks" && (view === "launcher"
    ? ModuleSettings.get("launcher", "dim", true) : ModuleSettings.get("keybinds", "dim", true))

  function openView(v) {
    if (PopupManager.current) PopupManager.current.visible = false;
    view = v;
    pinned = true;
  }

  function collapse() {
    view = "compact";
    pinned = false;
    if (popup?.visible) popup.visible = false;
  }

  // ---- module popups ----
  readonly property var popup: moduleHost.popup // the BarPopup whose content is in the island
  readonly property Item popupContent: moduleHost.content // its root item (a KitFrame)

  // opened from the hub: Escape goes back there instead of closing
  property bool fromHub: false

  function showPopup(p) {
    restoreTimer.stop();
    fromHub = view === "hub";
    moduleHost.attach(p);
    flash = "";
    view = "module";
    pinned = true;
    moduleSlot.forceActiveFocus();
  }

  // the module's popup closes and the hub opens in its place
  function backToHub() {
    const p = popup;
    view = "hub";
    pinned = true;
    if (p?.visible) p.visible = false;
  }

  function hidePopup(p) {
    if (popup !== p) return;
    if (view === "module") collapse();
    restoreTimer.restart();
  }

  // the content goes home once it has faded out
  function restore() { moduleHost.release(); }

  Timer {
    id: restoreTimer
    interval: Motion.slow + 60
    onTriggered: if (root.view !== "module") root.restore()
  }

  function toggleView(v) {
    if (view === v && pinned) { collapse(); return; }
    if (v === "launcher" || v === "keybinds" || v === "looks") fromHub = view === "hub";
    openView(v);
  }

  // an app view's Escape: back to the hub it came from, else closed
  function appBack() { if (fromHub) backToHub(); else collapse(); }

  // ---- size ----
  readonly property int noticeRow: 68          // one notice in the stack
  readonly property int moreRow: 20            // the "N more" line under it
  function noticeHeight() {
    const rows = IslandService.notices.length;
    const stack = Math.max(1, rows) * noticeRow + Math.max(0, rows - 1) * Theme.gapTight;
    return stack + (IslandService.noticeMore > 0 ? Theme.gapTight + moreRow : 0);
  }
  readonly property var sizes: ({
    compact: [compact.implicitWidth, Theme.islandHeight],
    hub:     [Math.max(280, Math.min(hub.preferredWidth, ModuleSettings.get("hub", "width", 400), (bar.screen?.width ?? 1920) - 24)), hub.implicitHeight],
    launcher: [520, islandLauncher.implicitHeight],
    keybinds: [520, islandKeybinds.implicitHeight],
    media:   [420, 148],
    notice:  [400, noticeHeight()],
    power:   [434, 86],
    looks:   [looks.implicitWidth, looks.implicitHeight],
    root:    [420, rootView.implicitHeight],
    module:  [popupContent?.fitWidth ? popupContent.implicitWidth : Math.max(Theme.popupWidth, popupContent?.implicitWidth ?? 0), popupContent?.implicitHeight ?? Theme.islandHeight]
  })
  readonly property var size: sizes[shown]

  implicitWidth: shape.width
  implicitHeight: shape.height

  Rectangle {
    id: shape
    anchors.horizontalCenter: parent.horizontalCenter
    width: root.size[0]
    height: root.size[1]
    radius: Math.min(Theme.barRadiusFor(height), Theme.islandRadius)
    color: Theme.background0
    border.width: Theme.islandFrameWidth
    border.color: Theme.background2
    clip: true
    opacity: root.hidden ? 0 : 1
    visible: opacity > 0
    Behavior on opacity { enabled: Motion.island; NumberAnimation { duration: Motion.quick } }

    Behavior on width { enabled: Motion.island && !(root.shown === "compact" && compact.slotMoving); NumberAnimation { duration: Motion.normal; easing.type: Motion.morph } }
    Behavior on height { enabled: Motion.island; NumberAnimation { duration: Motion.normal; easing.type: Motion.morph } }
    Behavior on radius { enabled: Motion.island; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }

    HoverHandler { id: hover }

    // compact's clicks, under its face: its modules take their own. A click on
    // the bare island does nothing but middle (play / pause): a misclick must
    // not open the hub
    MouseArea {
      anchors.fill: parent
      enabled: root.shown === "compact"
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton) IslandService.togglePlay();
      }
    }

    // the face of each view: fades in once the shape is on its way
    IslandCompact {
      id: compact
      anchors.centerIn: parent
      modules: root.modules
      screen: root.bar.screen?.name ?? ""
      visible: root.shown === "compact" && opacity > 0
      opacity: root.shown === "compact" ? 1 : 0
      Behavior on opacity { enabled: Motion.island; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
      onSettings: id => root.settings(id)
      onClockClicked: root.openView("hub")
    }

    IslandHub {
      id: hub
      anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
      width: root.sizes.hub[0] - 2 * Theme.islandFrameWidth
      bar: root.bar
      modules: root.modules
      // a module's popup takes its place at once: the hub does not fade under it
      visible: root.shown === "hub" && opacity > 0
      opacity: root.shown === "hub" ? 1 : 0
      Behavior on opacity { enabled: Motion.island; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
      onPower: root.openView("power")
      onManager: { root.collapse(); ShellSettings.managerOpen = true; }
      onSettings: id => {
        root.collapse();
        root.settings(id);
      }
    }

    IslandMedia {
      anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
      width: root.sizes.media[0]
      height: root.sizes.media[1]
      visible: root.shown === "media" && opacity > 0
      opacity: root.shown === "media" ? 1 : 0
      Behavior on opacity { enabled: Motion.island; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
    }

    // the notices, a column of rows, newest on top
    Column {
      anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
      width: root.sizes.notice[0]
      spacing: Theme.gapTight
      visible: root.shown === "notice" && opacity > 0
      opacity: root.shown === "notice" ? 1 : 0
      Behavior on opacity { enabled: Motion.island; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }

      Repeater {
        model: IslandService.notices

        IslandNotice {
          required property var modelData

          n: modelData
          width: parent.width
          height: root.noticeRow
          onDismissed: IslandService.dismissNotice(modelData.key)
        }
      }

      // the fresh ones past the stack; a click opens the notifications popup
      KitText {
        width: parent.width
        height: root.moreRow
        visible: IslandService.noticeMore > 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: IslandService.noticeMore + " more notifications"
        color: Theme.muted

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { root.flash = ""; IslandService.openNotifications(); }
        }
      }
    }

    // a module's popup content (showPopup); when it came from the hub, the bubble
    // beside it and the mouse's back button go back there, Escape too
    Item {
      id: moduleSlot
      anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
      width: root.sizes.module[0]
      height: root.sizes.module[1]
      visible: root.shown === "module" && opacity > 0
      opacity: root.shown === "module" ? 1 : 0
      Behavior on opacity { enabled: Motion.island; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
      Keys.onEscapePressed: PopupManager.back(() => root.fromHub ? root.backToHub() : root.collapse())
      // the content's children land here (showPopup)

      PopupContentHost {
        id: moduleHost
        available: Theme.island
        width: parent.width
        height: root.popupContent?.implicitHeight ?? 0
      }

      TapHandler {
        acceptedButtons: Qt.BackButton
        enabled: root.fromHub
        onTapped: root.backToHub()
      }
    }

    LauncherPanel {
      id: islandLauncher
      inIsland: true
      anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
      width: root.sizes.launcher[0]
      visible: root.shown === "launcher" && opacity > 0
      opacity: root.shown === "launcher" ? 1 : 0
      Behavior on opacity { enabled: Motion.island; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
      onBack: root.appBack()
      onFinished: root.collapse()
    }

    KeybindsPanel {
      id: islandKeybinds
      inIsland: true
      anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
      width: root.sizes.keybinds[0]
      visible: root.shown === "keybinds" && opacity > 0
      opacity: root.shown === "keybinds" ? 1 : 0
      Behavior on opacity { enabled: Motion.island; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
      onBack: root.appBack()
    }

    // a root action to confirm, or running (RootService)
    IslandRoot {
      id: rootView
      onCloseAsked: root.collapse()
      anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
      width: root.sizes.root[0]
      visible: root.shown === "root" && opacity > 0
      opacity: root.shown === "root" ? 1 : 0
      Behavior on opacity { enabled: Motion.island; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
    }

    LooksPanel {
      id: looks
      anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
      width: root.sizes.looks[0]
      height: root.sizes.looks[1]
      visible: root.shown === "looks" && opacity > 0
      opacity: root.shown === "looks" ? 1 : 0
      onCloseAsked: root.collapse()
      Behavior on opacity { enabled: Motion.island; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
    }

    IslandPower {
      id: power
      anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
      width: root.sizes.power[0]
      height: root.sizes.power[1]
      visible: root.shown === "power" && opacity > 0
      opacity: root.shown === "power" ? 1 : 0
      Behavior on opacity { enabled: Motion.island; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
      onDone: root.collapse()
    }
  }

  // ---- back bubble ----
  // a module opened from the hub: a small round island splits off on the
  // left, an arrow back to it (a module opened from the bar has no hub)
  readonly property Item bubble: bubble
  Rectangle {
    id: bubble
    readonly property bool on: (root.shown === "module" || root.appView) && root.fromHub
    anchors { right: shape.left; rightMargin: Theme.gapMedium * bubble.reveal - Theme.islandHeight * (1 - bubble.reveal) }
    y: 0
    width: Theme.islandHeight
    height: Theme.islandHeight
    radius: Math.min(Theme.barRadiusFor(height), Theme.islandRadius)
    color: backArea.containsMouse ? Theme.background1 : Theme.background0
    Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
    border.width: Theme.islandFrameWidth
    border.color: Theme.background2
    visible: reveal > 0
    opacity: reveal
    scale: 0.6 + 0.4 * reveal

    property real reveal: on ? 1 : 0
    Behavior on reveal { enabled: Motion.island; NumberAnimation { duration: Motion.normal; easing.type: Motion.morph } }

    KitIcon {
      anchors.centerIn: parent
      name: "arrow-left"
      size: Theme.iconSmall + 2
    }

    MouseArea {
      id: backArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.backToHub()
    }
  }

  // ---- hover ----
  // resting on the clock opens the hub (the modules beside it keep their
  // own hover and clicks); leaving the island closes it unless clicked
  Timer {
    interval: 350
    running: ShellSettings.clockOpens === "hover" && compact.clockHovered && root.view === "compact" && root.flash === ""
             && !PopupManager.current
    // Hub › Behaviour › Close when the pointer leaves, off: a hover-opened hub stays until Escape or a click away
    onTriggered: { root.view = "hub"; root.pinned = !ModuleSettings.get("hub", "autoClose", true); }
  }
  Timer {
    interval: ModuleSettings.get("hub", "closeDelay", 500)             // Hub › Behaviour › Close delay
    running: !hover.hovered && !root.pinned && root.view !== "compact" && !PopupManager.holding
    onTriggered: root.collapse()
  }

  // ---- flashes ----
  // a notice waits while the pointer rests on it or while a view it can't pass
  // over (a module's popup, the power menu) is open: its time starts once shown
  Timer {
    id: flashTimer
    onTriggered: {
      if (root.flash === "notice" && (hover.hovered || root.shown !== "notice")) restart();
      else {
        if (root.flash === "notice") IslandService.clearNotices(false);
        root.flash = "";
      }
    }
  }
  onShownChanged: if (shown === "notice" && flashTimer.running) flashTimer.restart()

  Connections {
    target: IslandService
    // the last notice gone: the flash ends here, not in the delegate (its
    // root is gone once the Repeater rebuilds, so a write there is lost)
    function onNoticesChanged() {
      if (IslandService.notices.length === 0 && root.flash === "notice") root.flash = "";
    }
    function onFlashed(kind, ms) {
      root.flash = kind;
      // ms 0: stays until the notices are dismissed (onNoticesChanged ends it)
      flashTimer.stop();
      if (ms > 0) {
        flashTimer.interval = ms;
        flashTimer.restart();
      }
    }
    function onRequested(v, screen) {
      if (screen !== "" && screen !== root.bar.screen?.name) return;
      if (v === "compact") root.collapse();
      else root.toggleView(v);
    }
  }

  // ---- root actions ----
  // a request opens as a view on the focused monitor's island; Run folds it
  // into the live chip, the end closes it; leaving it unanswered cancels
  readonly property bool onFocused: bar.screen?.name === Hypr.focusedScreen?.name
  Connections {
    target: RootService
    function onPendingChanged() {
      if (RootService.pending && root.onFocused && !RootService.auto) root.openView("root");
      else if (!RootService.pending && root.view === "root") root.collapse();
    }
    function onRunningChanged() { if (RootService.running) foldTimer.restart(); }
    function onAskingChanged() {
      if (RootService.asking && root.onFocused && root.view !== "root") root.openView("root");
      else if (!RootService.asking) foldTimer.restart();
    }
  }
  // running without a password to ask (it comes within a moment): the view folds into the live chip
  Timer {
    id: foldTimer
    interval: 350
    onTriggered: if (RootService.running && !RootService.asking && root.view === "root") root.collapse()
  }

  // ---- keys ----
  property string lastView: "compact"
  onViewChanged: {
    if (lastView === "root" && view !== "root") {
      if (RootService.asking) RootService.stop();
      else if (RootService.pending && !RootService.running) RootService.cancel();
    }
    lastView = view;
    if (view === "looks") looks.reset();
    if (view === "power") power.reset();
    if (view === "launcher") islandLauncher.reset();
    if (view === "keybinds") islandKeybinds.reset();
  }
  onGrabbingChanged: if (grabbing) keys.forceActiveFocus()

  Item {
    id: keys
    focus: root.grabbing
    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape) PopupManager.back(() => root.collapse());
      else if (root.view === "root") {
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && RootService.pending && !RootService.running) RootService.run();
        else return;
      }
      else if (root.view === "power") power.key(event.key);
      else if (root.view !== "media") return;
      else if (event.key === Qt.Key_Space) IslandService.togglePlay();
      else if (event.key === Qt.Key_Left) IslandService.prev();
      else if (event.key === Qt.Key_Right) IslandService.next();
      else return;
      event.accepted = true;
    }
  }

  HyprlandFocusGrab {
    windows: [root.bar]
    active: root.takesKeys && !PopupManager.holding
    onCleared: root.collapse()
  }
}
