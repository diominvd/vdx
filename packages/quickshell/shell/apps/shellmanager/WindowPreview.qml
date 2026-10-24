import QtQuick
import qs.config
import qs.kit

// A small monitor with the window as it will open: its size and spot at
// scale, the bar along the top; at the cursor — a pointer the window is
// centred on; tiled — the window takes its half of the screen.
Rectangle {
  radius: Theme.radiusCard
  id: root

  property var app: null
  property var settings: ({})

  readonly property real k: width / Math.max(1, ShellAppsService.screenW)
  readonly property bool tiled: settings.mode === "tiled"
  readonly property var size: app ? ShellAppsService.sizeOf(app, settings) : [0, 0]
  readonly property real winW: Math.min(ShellAppsService.screenW, size[0]) * k
  readonly property real winH: Math.min(ShellAppsService.screenH, size[1]) * k
  // the pointer for "at the cursor": somewhere left of the middle
  readonly property real pointerX: width * 0.38
  readonly property real pointerY: height * 0.42

  height: width * Math.max(1, ShellAppsService.screenH) / Math.max(1, ShellAppsService.screenW)
  color: Theme.background1
  border.width: Theme.frameWidth
  border.color: Theme.gray
  clip: true

  // the bar
  Rectangle {
    x: Theme.frameWidth
    y: Theme.frameWidth
    width: parent.width - 2 * Theme.frameWidth
    height: Math.max(3, Theme.barHeight * root.k)
    color: Theme.background0
  }

  // the window
  Rectangle {
    radius: Theme.radiusControl
    id: win

    readonly property real barBottom: Theme.barHeight * root.k
    // a spot: its share along x and y, from the gap to the far gap (top: under the bar)
    readonly property var spot: ShellAppsService.spots[root.settings.position] ?? null
    function along(f, room, size, start) {
      return f === 0 ? start : f === 1 ? room - size - ShellAppsService.gap * root.k : (room - size) / 2;
    }
    readonly property real wantX: root.settings.position === "cursor" ? root.pointerX - root.winW / 2
                                : root.settings.position === "custom" ? root.settings.x * root.k
                                : spot ? along(spot[0], root.width, root.winW, ShellAppsService.gap * root.k)
                                : (root.width - root.winW) / 2
    readonly property real wantY: root.settings.position === "cursor" ? root.pointerY - root.winH / 2
                                : root.settings.position === "custom" ? root.settings.y * root.k
                                : spot && root.settings.position !== "center" ? along(spot[1], root.height, root.winH, ShellAppsService.top * root.k)
                                : (root.height - root.winH) / 2

    x: root.tiled ? root.width / 2 + 2 : Math.max(0, Math.min(root.width - root.winW, wantX))
    y: root.tiled ? barBottom + 3 : Math.max(0, Math.min(root.height - root.winH, wantY))
    width: root.tiled ? Math.max(0, root.width / 2 - 5) : root.winW
    height: root.tiled ? Math.max(0, root.height - barBottom - 6) : root.winH
    color: Theme.background0
    border.width: Theme.frameWidth
    border.color: Theme.frame

    Behavior on x { enabled: Motion.pages; NumberAnimation { duration: Motion.ms(160); easing.type: Motion.easing } }
    Behavior on y { enabled: Motion.pages; NumberAnimation { duration: Motion.ms(160); easing.type: Motion.easing } }
    Behavior on width { enabled: Motion.pages; NumberAnimation { duration: Motion.ms(160); easing.type: Motion.easing } }
    Behavior on height { enabled: Motion.pages; NumberAnimation { duration: Motion.ms(160); easing.type: Motion.easing } }

    // its title strip
    Rectangle {
      x: 4; y: 4
      width: Math.max(0, parent.width * 0.4)
      height: 3
      color: Theme.foreground2
    }
  }

  // the other tiled window
  Rectangle {
    radius: Theme.radiusControl
    visible: root.tiled
    x: 3
    y: win.y
    width: Math.max(0, root.width / 2 - 5)
    height: win.height
    color: "transparent"
    border.width: Theme.frameWidth
    border.color: Theme.background3
  }

  KitIcon {
    visible: !root.tiled && root.settings.position === "cursor"
    x: root.pointerX - 2
    y: root.pointerY - 2
    name: "cursor"
    size: Theme.iconSmall
  }
}
