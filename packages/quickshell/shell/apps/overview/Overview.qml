import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.kit
import Quickshell.Widgets

// Niri's overview as one canvas: every workspace of the focused
// monitor is a row, and each window sits where it really is, so a scrolling
// workspace runs on sideways past the screen. The canvas has no end: the rows
// go on below the last workspace, always one empty past it. The wheel pans
// it (shift: sideways), Super + left drag pans from anywhere, up / down and
// page keys move a row. A click on a window focuses it, on a workspace goes
// there; a window dragged onto another workspace moves there. Enter goes to
// the workspace in the middle, Escape or a click on the dimmed screen closes.
ScrimWindow {
  id: root

  readonly property var monitor: Hyprland.focusedMonitor
  readonly property real mw: (monitor?.width ?? 1920) / (monitor?.scale ?? 1)
  readonly property real mh: (monitor?.height ?? 1080) / (monitor?.scale ?? 1)

  // canvas units are logical pixels; a row is one monitor and the gap is 80 of them
  readonly property real gap: 80
  readonly property real pitch: mh + gap
  readonly property real zoom: Math.max(0.01, height * 0.33 / Math.max(1, mh))

  // the monitor's own workspaces; the rows start at the lowest one
  readonly property var taken: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === root.monitor).map(w => w.id)
  readonly property int first: taken.length > 0 ? taken.reduce((m, i) => Math.min(m, i)) : (monitor?.activeWorkspace?.id ?? 1)
  readonly property int lastRow: Math.max(0, taken.reduce((m, i) => Math.max(m, i), first) - first)
  readonly property int bottomRow: Math.max(0, Math.floor((camY + height / (2 * zoom)) / pitch))
  readonly property int rowCount: Math.max(lastRow, bottomRow) + 2

  // the view: the canvas point in the middle of the screen
  property real camX: 0
  property real camY: 0
  readonly property int centreId: first + Math.max(0, Math.round((camY - mh / 2) / pitch))

  function rowTop(i) { return i * pitch; }
  function pan(dx, dy) { camX += dx; camY = Math.max(-gap, camY + dy); }
  function goTo(id) { open = false; Hypr.call("hl.dispatch(hl.dsp.focus({ workspace = " + id + " }))"); }
  function focus(t) { open = false; Hypr.call("hl.dispatch(hl.dsp.focus({ window = \"" + Hypr.target(t) + "\" }))"); }
  function moveTo(t, id) { Hypr.call("hl.dispatch(hl.dsp.window.move({ workspace = " + id + ", window = \"" + Hypr.target(t) + "\", follow = false }))"); }

  onOpenChanged: if (open) {
    const active = monitor?.activeWorkspace?.id ?? first;
    camX = mw / 2;
    camY = mh / 2 + (active - first) * pitch;
    Hyprland.refreshToplevels();
    canvas.forceActiveFocus();
  }

  namespace: "overview"
  onDismissed: open = false

  IpcHandler {
    target: "overview"
    function toggle(): void { root.open = !root.open; }
  }

  Item {
    id: canvas
    anchors.fill: parent
    focus: true
    Keys.onUpPressed: root.pan(0, -root.pitch)
    Keys.onDownPressed: root.pan(0, root.pitch)
    Keys.onLeftPressed: root.pan(-root.mw / 2, 0)
    Keys.onRightPressed: root.pan(root.mw / 2, 0)
    Keys.onPressed: event => {
      if (event.key === Qt.Key_PageUp) root.pan(0, -root.pitch);
      else if (event.key === Qt.Key_PageDown) root.pan(0, root.pitch);
      else return;
      event.accepted = true;
    }
    Keys.onReturnPressed: root.goTo(root.centreId)
    Keys.onEscapePressed: root.open = false

    WheelHandler {
      onWheel: event => {
        const d = event.angleDelta.y / root.zoom;
        if (event.modifiers & Qt.ShiftModifier) root.pan(-d, 0);
        else root.pan(0, -d);
      }
    }

    // the dimmed screen: a click closes, Super + drag pans
    MouseArea {
      id: bg
      anchors.fill: parent
      property real lastX: 0
      property real lastY: 0
      property bool pan: false

      onPressed: mouse => {
        lastX = mouse.x;
        lastY = mouse.y;
        pan = (mouse.modifiers & Qt.MetaModifier) !== 0;
      }
      onPositionChanged: mouse => {
        if (!pan || !pressed) return;
        root.pan(-(mouse.x - lastX) / root.zoom, -(mouse.y - lastY) / root.zoom);
        lastX = mouse.x;
        lastY = mouse.y;
      }
      onClicked: if (!pan) root.dismissed()
    }

    // the canvas: rows of workspaces and the windows on them, panned and zoomed
    Item {
      id: world
      transformOrigin: Item.TopLeft
      scale: root.zoom
      x: canvas.width / 2 - root.camX * root.zoom
      y: canvas.height / 2 - root.camY * root.zoom

      Repeater {
        model: root.rowCount

        Item {
          id: space
          required property int index
          readonly property int wsId: root.first + index
          readonly property bool active: root.monitor?.activeWorkspace?.id === wsId

          y: root.rowTop(index)
          width: root.mw
          height: root.mh

          // the workspace's own area: a click goes there, a drop moves a window
          Rectangle {
            radius: Theme.radiusCard / root.zoom
            anchors.fill: parent
            color: drop.containsDrag ? Theme.background2 : Theme.background1
            border.width: Theme.windowFrameWidth / root.zoom
            border.color: space.active ? Theme.frame : Theme.gray
          }

          KitText {
            x: 24
            y: 16
            text: String(space.wsId)
            color: Theme.muted
            font.pixelSize: 44
          }

          MouseArea {
            anchors.fill: parent
            propagateComposedEvents: true
            onPressed: mouse => mouse.accepted = (mouse.modifiers & Qt.MetaModifier) === 0
            onClicked: root.goTo(space.wsId)
          }

          DropArea {
            id: drop
            anchors.fill: parent
            onDropped: drag => root.moveTo(drag.source.toplevel, space.wsId)
          }

          // windows at their real place: a scrolling column may run past the edge
          Repeater {
            model: Hyprland.toplevels.values.filter(t => t.workspace?.id === space.wsId)

            ClippingRectangle {
              radius: Theme.radiusControl
              id: win
              required property var modelData
              readonly property var toplevel: modelData
              readonly property var ipc: modelData.lastIpcObject ?? {}
              readonly property real wx: (ipc.at?.[0] ?? 0) - (root.monitor?.x ?? 0)
              readonly property real wy: (ipc.at?.[1] ?? 0) - (root.monitor?.y ?? 0)

              x: wx
              y: wy
              width: ipc.size?.[0] ?? 0
              height: ipc.size?.[1] ?? 0
              color: Theme.background2
              border.width: Theme.frameWidth / root.zoom
              border.color: hover.containsMouse ? Theme.foreground0 : Theme.gray
              Behavior on border.color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
              Drag.active: hover.drag.active
              Drag.source: win
              Drag.hotSpot.x: width / 2
              Drag.hotSpot.y: height / 2

              ScreencopyView {
                anchors.fill: parent
                anchors.margins: 1
                captureSource: root.open ? win.modelData.wayland : null
                live: false
              }

              MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                propagateComposedEvents: true
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                drag.target: win
                onPressed: mouse => mouse.accepted = (mouse.modifiers & Qt.MetaModifier) === 0
                onClicked: root.focus(win.toplevel)
                onReleased: {
                  if (!drag.active) return;
                  win.Drag.drop();
                  win.x = Qt.binding(() => win.wx);
                  win.y = Qt.binding(() => win.wy);
                }
              }
            }
          }
        }
      }
    }
  }
}
