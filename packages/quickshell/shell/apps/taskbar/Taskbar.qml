import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.config
import qs.kit
import qs.modules.windows

// The floating mode's taskbar along the bottom of the focused monitor, like
// Windows: every window of the active workspace — open ones and those
// minimized from it (Super+J, or a click here; they wait on special:minimized,
// tagged min<workspace> by windowmode.lua). A click minimizes an open window
// and brings a minimized one back; the pointer stays where it is. Shell
// Manager › Windows › Floating › Taskbar turns it off. Shape: a strip, or (Island)
// a pill centred above the screen's bottom edge, framed and rounded like the
// island. The pill reserves the island's space (the windows stay clear of it, as
// they do of the top island), and only the pill takes the pointer.
PanelWindow {
  id: root

  readonly property var ws: WindowsService
  readonly property int wsId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1
  readonly property var active: Hyprland.activeToplevel
  readonly property bool pill: ws.opts.taskbarShape === "island"
  // the pill's windows row: set in from the rounded ends and from the top and
  // bottom, so an active window's fill stays inside the curve
  readonly property int pillEnd: Math.round(Theme.islandHeight / 2)
  readonly property int pillInset: Theme.gapSmall
  // the strip always shows, the pill only with windows (counted on the array:
  // a ScriptModel has no count)
  readonly property bool shapeShown: !pill || windows.length > 0

  // what each window's workspace was, kept by address: a minimized window's
  // tag comes with the IPC refresh, a moment late, and while it lacks the tag
  // the window dropped out of the row and came back at its end. seq keeps the
  // order the windows came in. A plain object: writing it notifies nothing.
  readonly property var cache: ({ origin: {}, seq: {}, count: 0 })

  readonly property var windows: {
    const origin = {}, seq = {};
    const out = [];
    for (const t of Hyprland.toplevels.values) {
      const a = Hypr.addr(t);
      const tag = Hypr.tagsOf(t).find(s => /^min\d+$/.test(s));
      const from = Hypr.minimized(t) ? (root.cache.origin[a] ?? (tag ? +tag.slice(3) : undefined)) : t.workspace?.id;
      origin[a] = from;
      seq[a] = root.cache.seq[a] ?? ++root.cache.count;
      if (from === root.wsId) out.push(t);
    }
    root.cache.origin = origin;
    root.cache.seq = seq;
    return out.sort((x, y) => seq[Hypr.addr(x)] - seq[Hypr.addr(y)]);
  }

  function clicked(t) {
    if (Hypr.minimized(t)) ws.restore(Hypr.addr(t));
    else ws.minimize(Hypr.addr(t));
  }

  screen: Hypr.focusedScreen
  visible: ws.opts.taskbar && ws.mode === "floating"
  anchors { bottom: true; left: true; right: true }
  // the island's offset from the edge is inside the window, as the top island's is
  implicitHeight: pill ? Theme.islandTop + Theme.islandHeight : Theme.barHeight
  exclusiveZone: implicitHeight
  color: pill ? Theme.clear : Theme.background0
  WlrLayershell.namespace: "taskbar"
  WlrLayershell.layer: WlrLayer.Top

  // the pill (or the strip) takes the pointer; the rest of the window lets clicks through
  mask: Region { item: root.shapeShown ? shape : null }

  // the strip is the whole window; the pill is as wide as its windows, sits in the
  // middle and clears the screen's edge by islandTop
  Rectangle {
    id: shape
    x: root.pill ? (root.width - width) / 2 : 0
    y: root.pill ? root.height - height - Theme.islandTop : 0
    width: root.pill ? row.width + 2 * root.pillEnd : root.width
    height: root.pill ? Theme.islandHeight : root.height
    visible: root.shapeShown
    // the bar's own look: its fill, and its frame only in the island style
    radius: root.pill ? Math.min(height / 2, Theme.islandRadius) : 0
    color: Theme.background0
    border.width: root.pill && Theme.island ? Theme.islandFrameWidth : 0
    border.color: Theme.background2
  }

  // the class and the tags come with the toplevels' IPC objects: refreshed
  // after Hyprland's events, at most every 150 ms
  Connections {
    target: Hyprland
    function onRawEvent() { if (root.visible && !refresh.running) refresh.start(); }
  }
  Timer { id: refresh; interval: 150; onTriggered: Hyprland.refreshToplevels() }

  // keyed by address: a refresh keeps each window's item instead of rebuilding
  // the row (a new array rebuilt them all, and they flickered)
  ScriptModel {
    id: windowModel
    values: root.windows
    objectProp: "address"
  }

  Row {
    id: row
    x: root.pill ? shape.x + root.pillEnd : 8
    y: root.pill ? shape.y + root.pillInset : 0
    height: root.pill ? shape.height - 2 * root.pillInset : root.height
    spacing: Theme.gapHair

    Repeater {
      model: windowModel

      // a window: its app's icon and title; the active one filled and bold,
      // a minimized one dim
      Rectangle {
        radius: Theme.radiusControl
        id: item
        required property var modelData
        readonly property bool current: modelData === root.active && !Hypr.minimized(modelData)
        readonly property bool down: Hypr.minimized(modelData)

        width: Math.max(40, Math.min(220, 40 + label.implicitWidth))
        height: parent.height
        // only the active window is lit: the pointer passing over the windows lights nothing
        color: current ? Theme.background3 : Theme.clear
        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

        IconImage {
          id: appIcon
          x: 8
          anchors.verticalCenter: parent.verticalCenter
          implicitSize: 18
          source: Hypr.iconOf(item.modelData)
          visible: source != ""
          opacity: item.down ? 0.5 : 1
        }

        KitIcon {
          x: 8
          anchors.verticalCenter: parent.verticalCenter
          visible: !appIcon.visible
          name: "app-window"
          size: 18
          tint: item.down ? Theme.muted : Theme.foreground0
        }

        KitText {
          id: label
          x: 32
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(0, Math.min(implicitWidth, item.width - 40))
          elide: Text.ElideRight
          text: item.modelData.title || Hypr.classOf(item.modelData)
          color: item.down ? Theme.muted : Theme.foreground0
          font.weight: item.current ? Font.ExtraBold : Theme.fontWeight
        }

        MouseArea {
          id: area
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.MiddleButton
          // middle click closes, as in a browser's tabs
          onClicked: mouse => mouse.button === Qt.MiddleButton ? root.ws.close(Hypr.addr(item.modelData)) : root.clicked(item.modelData)
        }
      }
    }
  }
}
