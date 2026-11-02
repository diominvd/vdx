import QtQuick
import qs.config
import qs.kit

// A small monitor with the window as it will open: its size and spot at
// scale, the bar along the top; at the cursor — a pointer the window is
// centred on; tiled — the window takes its half of the screen. `pickable`:
// the screen is nine zones to click, the window goes to the one picked.
Rectangle {
  radius: Theme.radiusCard
  id: root

  property var app: null
  property var settings: ({})
  property bool pickable: false

  readonly property var zones: ["top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right"]
  signal picked(string spot)

  readonly property real k: width / ShellAppsService.screenW
  readonly property bool tiled: settings.mode === "tiled"
  readonly property var size: app ? ShellAppsService.sizeOf(app, settings) : [0, 0]
  readonly property real winW: Math.min(ShellAppsService.screenW, size[0]) * k
  readonly property real winH: Math.min(ShellAppsService.screenH, size[1]) * k
  // the pointer for "at the cursor": somewhere left of the middle
  readonly property real pointerX: width * 0.38
  readonly property real pointerY: height * 0.42

  height: width * ShellAppsService.screenH / ShellAppsService.screenW
  color: Theme.background1
  border.width: Theme.frameWidth
  border.color: Theme.gray
  clip: true

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
    y: root.tiled ? 3 : Math.max(0, Math.min(root.height - root.winH, wantY))
    width: root.tiled ? root.width / 2 - 5 : root.winW
    height: root.tiled ? root.height - 6 : root.winH
    color: Theme.background0
    border.width: Theme.frameWidth
    border.color: Theme.frame

    Behavior on x { enabled: Motion.pages; NumberAnimation { duration: Motion.ms(160); easing.type: Motion.easing } }
    Behavior on y { enabled: Motion.pages; NumberAnimation { duration: Motion.ms(160); easing.type: Motion.easing } }
    Behavior on width { enabled: Motion.pages; NumberAnimation { duration: Motion.ms(160); easing.type: Motion.easing } }
    Behavior on height { enabled: Motion.pages; NumberAnimation { duration: Motion.ms(160); easing.type: Motion.easing } }

    // a skeleton of its content: title, a sidebar, lines of text
    Rectangle {
      x: 4; y: 4
      width: Math.max(0, parent.width * 0.35)
      height: 3
      radius: 1
      color: Theme.foreground2
    }
    Rectangle {
      visible: parent.width > 40 && parent.height > 28
      x: 4; y: 11
      width: Math.max(0, parent.width * 0.22)
      height: Math.max(0, parent.height - 15)
      radius: 2
      color: Theme.background2
    }
    Column {
      visible: parent.width > 40 && parent.height > 28
      x: parent.width * 0.22 + 9
      y: 11
      width: Math.max(0, parent.width * 0.78 - 13)
      spacing: 3
      clip: true
      height: Math.max(0, parent.height - 15)

      Repeater {
        model: [1, 0.7, 0.85, 0.5, 0.9, 0.6]
        Rectangle {
          required property real modelData
          width: parent.width * modelData
          height: 3
          radius: 1
          color: Theme.background3
        }
      }
    }
  }

  // the other tiled window
  Rectangle {
    radius: Theme.radiusControl
    visible: root.tiled
    x: 3
    y: win.y
    width: root.width / 2 - 5
    height: win.height
    color: Theme.clear
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

  // the nine zones, under the bar; the hovered one is lit, the window's own is not
  Grid {
    id: zoneGrid
    visible: root.pickable && !root.tiled
    x: Theme.frameWidth
    y: Theme.frameWidth
    width: root.width - 2 * Theme.frameWidth
    height: root.height - 2 * Theme.frameWidth
    columns: 3

    Repeater {
      model: root.zones

      Item {
        id: zone
        required property string modelData
        width: zoneGrid.width / 3
        height: zoneGrid.height / 3

        // flush with its neighbours; only the screen's own corners are round
        Rectangle {
          anchors.fill: parent
          readonly property int r: Math.max(0, root.radius - Theme.frameWidth)
          readonly property int col: root.zones.indexOf(zone.modelData) % 3
          readonly property int row: Math.floor(root.zones.indexOf(zone.modelData) / 3)
          topLeftRadius: row === 0 && col === 0 ? r : 0
          topRightRadius: row === 0 && col === 2 ? r : 0
          bottomLeftRadius: row === 2 && col === 0 ? r : 0
          bottomRightRadius: row === 2 && col === 2 ? r : 0
          color: area.containsMouse && root.settings.position !== zone.modelData ? Qt.alpha(Theme.foreground0, 0.07) : Theme.clear
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick; easing.type: Motion.tint } }
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: root.settings.position === zone.modelData ? Qt.ArrowCursor : Qt.PointingHandCursor
          Accessible.role: Accessible.Button
          Accessible.name: "Place window " + zone.modelData.replace("-", " ")
          Accessible.onPressAction: root.picked(zone.modelData)
          onClicked: if (root.settings.position !== zone.modelData) root.picked(zone.modelData)
        }
      }
    }
  }
}
