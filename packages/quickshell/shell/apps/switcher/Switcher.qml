import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.config
import qs.kit
import qs.modules.windows

// The floating mode's window switcher, like Windows' Alt+Tab, on Super+Tab:
// the active workspace's windows (minimized ones too, dim) in a grid, the
// most recently used first, the one before the current picked. Tab again
// (Shift: back), the arrows or the pointer pick; letting Super go, Enter or
// a click switches, Escape or a click on the dimmed screen doesn't. Other
// modes, or with Shell Manager › Windows › Switcher off: Super+Tab does nothing.
ScrimWindow {
  id: root

  readonly property var ws: WindowsService
  readonly property bool enabled: ws.mode === "floating" && ws.opts.switcher

  readonly property int wsId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1
  readonly property var windows: Hyprland.toplevels.values
    .filter(t => t.workspace?.id === wsId || (Hypr.minimized(t) && Hypr.tagsOf(t).includes("min" + wsId)))
    .sort((a, b) => order(a) - order(b))
  property int index: 0
  // Window lists can change while the switcher is open (for example, when an
  // application exits). Keep the selection valid so the next pick is stable.
  onWindowsChanged: {
    if (index >= windows.length) index = Math.max(0, windows.length - 1);
  }

  // the grid: cells of 240 px, at most 5 in a row
  readonly property int spacing: Theme.gapWide
  readonly property int columns: Math.max(1, Math.min(5, windows.length))
  // Keep the grid within the available screen width on smaller displays.
  readonly property int cellWidth: Math.max(80, Math.min(240,
    Math.floor((width - 2 * Theme.popupPadding - (columns - 1) * spacing) / columns)))
  readonly property int thumbHeight: Math.max(60, Math.round(cellWidth * 0.625))

  function order(t) { return t.lastIpcObject?.focusHistoryID ?? 1000; }

  // Super+Tab: open on the window before the current one, or the next one
  function step(d) {
    if (!enabled) return;
    if (!open) {
      Hyprland.refreshToplevels();
      index = 0;
      open = true;
    }
    const n = windows.length;
    if (n > 0) index = (index + d + n) % n;
  }

  function move(d) {
    const n = windows.length;
    if (n > 0) index = Math.max(0, Math.min(n - 1, index + d));
  }

  // the picked window comes to the top of the others, as the selection moves
  function raise() {
    const t = windows[index];
    if (t && !Hypr.minimized(t)) Hypr.call("RaiseWindow(\"" + Hypr.addr(t) + "\")");
  }
  onIndexChanged: raise()

  function pick() {
    const t = windows[index];
    open = false;
    if (!t) return;
    if (Hypr.minimized(t)) ws.restore(Hypr.addr(t));
    else Hypr.call("PickWindow(\"" + Hypr.addr(t) + "\")");
  }

  onOpenChanged: if (open) keys.forceActiveFocus()

  namespace: "switcher"
  onDismissed: open = false

  // `qs -c shell ipc call switcher next` (Super+Tab), `… back` (Super+Shift+Tab)
  IpcHandler {
    target: "switcher"
    function next(): void { root.step(1); }
    function back(): void { root.step(-1); }
  }

  Item {
    id: keys
    anchors.fill: parent
    focus: true
    Keys.onPressed: event => {
      const k = event.key;
      if (k === Qt.Key_Tab || k === Qt.Key_Right) root.move(1);
      else if (k === Qt.Key_Backtab || k === Qt.Key_Left) root.move(-1);
      else if (k === Qt.Key_Down) root.move(root.columns);
      else if (k === Qt.Key_Up) root.move(-root.columns);
      else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.pick();
      else if (k === Qt.Key_Escape) root.open = false;
      else return;
      event.accepted = true;
    }
    // Super let go: switch, as Alt's release does on Windows
    Keys.onReleased: event => {
      if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta) root.pick();
    }
  }

  KitFrame {
    anchors.centerIn: parent
    width: root.columns * root.cellWidth + (root.columns - 1) * root.spacing + 2 * padding

    KitHeader {
      icon: "app-window"
      title: "Windows"
      subtitle: "WORKSPACE " + root.wsId + " · " + root.windows.length + (root.windows.length === 1 ? " WINDOW" : " WINDOWS")
    }

    KitLine {}

    KitText {
      visible: root.windows.length === 0
      color: Theme.muted
      text: "No windows here"
    }

    Grid {
      visible: root.windows.length > 0
      columns: root.columns
      spacing: root.spacing

      Repeater {
        model: root.windows

        // a window: its picture, then its app's icon and title; the picked
        // one filled and bold with a light frame
        Rectangle {
          radius: Theme.radiusCard
          id: cell
          required property var modelData
          required property int index
          readonly property bool current: index === root.index
          readonly property bool down: Hypr.minimized(modelData)
          readonly property var size: modelData.lastIpcObject?.size ?? [16, 9]
          readonly property real fit: Math.min((root.cellWidth - 16) / Math.max(1, size[0]), (root.thumbHeight - 16) / Math.max(1, size[1]))

          width: root.cellWidth
          height: root.thumbHeight + 32
          color: current ? Theme.background3 : area.containsMouse ? Theme.background1 : Theme.clear
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
          border.width: Theme.frameWidth
          border.color: current ? Theme.foreground0 : Theme.gray
          Behavior on border.color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

          Item {
            width: parent.width
            height: root.thumbHeight

            ScreencopyView {
              anchors.centerIn: parent
              width: cell.size[0] * cell.fit
              height: cell.size[1] * cell.fit
              visible: !cell.down
              captureSource: root.open && !cell.down ? cell.modelData.wayland : null
              live: false
            }

            // minimized: nothing to show but its app
            IconImage {
              anchors.centerIn: parent
              visible: cell.down && source != ""
              implicitSize: 48
              opacity: 0.5
              source: cell.down ? Hypr.iconOf(cell.modelData) : ""
            }
          }

          IconImage {
            id: appIcon
            x: 8
            y: root.thumbHeight + 8
            implicitSize: 16
            source: Hypr.iconOf(cell.modelData)
            visible: source != ""
            opacity: cell.down ? 0.5 : 1
          }

          KitIcon {
            x: 8
            y: root.thumbHeight + 8
            visible: !appIcon.visible
            name: "app-window"
            size: 16
            tint: cell.down ? Theme.muted : Theme.foreground0
          }

          KitText {
            x: 32
            y: root.thumbHeight + 8
            width: parent.width - 40
            elide: Text.ElideRight
            text: cell.modelData.title || Hypr.classOf(cell.modelData)
            color: cell.down ? Theme.muted : Theme.foreground0
            font.weight: cell.current ? Font.ExtraBold : Theme.fontWeight
          }

          MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.index = cell.index
            onClicked: { root.index = cell.index; root.pick(); }
          }
        }
      }
    }

    KitLine {}

    KitText {
      width: parent.width
      horizontalAlignment: Text.AlignRight
      color: Theme.muted
      font.pixelSize: Theme.fontSize - 2
      text: "tab next · Shift + Tab back · release Super switch · esc cancel"
    }
  }
}
