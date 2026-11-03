import QtQuick
import qs.apps.display
import qs.config
import qs.kit
import qs.modules.brightness

// Displays: the arrangement of the monitors (drag or arrow keys), then the
// picked monitor's scale (a slider whose stops are the scales it offers),
// refresh rate and position. Choices apply at once; a failure shows at the end.
// The GTK apps' text size is in Fonts.
KitColumn {
  id: root

  readonly property var ds: DisplayService
  // the monitor the arrangement and the MONITOR group are about
  property string selected: ""
  readonly property var current: ds.monitors.find(m => m.name === selected) ?? ds.monitors[0] ?? null

  property real scaleTo: 0
  Timer { id: scaleLater; interval: Motion.quick + 80; onTriggered: if (root.current) root.ds.setScale(root.current.name, root.scaleTo) }

  function pct(f) { return Math.round(f * 100) + "%"; }

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "monitor"
  readonly property string title: "Displays"
  readonly property string description: "Monitors, their modes and the night light."
  readonly property var jumps: [
    { key: "arrange", label: "Arrange", y: arrangeLabel.y },
    { key: "monitor", label: "Monitor", y: monitorLabel.y }
  ]

  // shown: the monitors as they are now
  // the Loader makes the page already visible: the first show is not a change
  Component.onCompleted: visibleChanged()
  onVisibleChanged: if (visible) ds.refresh()

  KitLabel { id: arrangeLabel; text: "ARRANGE"; value: "DRAG OR ARROWS" }

  KitEmptyState {
    visible: root.ds.monitors.length === 0
    icon: "monitor"
    title: "No displays detected"
    hint: "Connect a display to arrange it here"
  }

  MonitorLayout {
    visible: root.ds.monitors.length > 0
    property bool kitUnboxed: true          // KitGrouper: the board stands on the page
    width: parent.width
    height: Math.max(150, Math.min(210, width * 0.28))
    selected: root.current ? root.current.name : ""
    onPicked: name => root.selected = name
  }

  KitLabel { id: monitorLabel; text: "MONITOR"; value: root.current ? root.current.name : "" }

  KitSliderRow {
    id: scaleSlider
    visible: root.current !== null
    enabled: !root.ds.busy
    label: "Scale"
    snaps: root.current ? root.ds.stops(root.current) : []
    value: root.current ? root.ds.scalePos(root.current) : 0
    text: root.current ? root.pct(root.ds.stopAt(root.current, scaleSlider.pressed ? scaleSlider.dragValue : scaleSlider.value)) : ""
    // the monitor rescales a moment later: the handle reaches the stop first (a
    // rescale mid-move left it standing where it was)
    onReleased: value => { root.scaleTo = root.ds.stopAt(root.current, value); scaleLater.restart(); }
  }

  KitSelect {
    visible: root.current !== null
    disabled: root.ds.busy
    label: "Refresh rate"
    hint: root.current ? root.current.width + "x" + root.current.height : ""
    model: root.current ? root.current.refreshes.map(r => ({ label: r + " Hz", value: r })) : []
    current: root.current ? root.current.refresh : null
    busy: root.current !== null && root.ds.working === "rate:" + root.current.name
    onPicked: value => root.ds.setRate(root.current.name, value)
  }

  KitRow {
    visible: root.current !== null
    label: "Position"
    hint: "Logical pixels, from the top left"

    KitText {
      text: root.current ? root.current.x + ", " + root.current.y : ""
      color: Theme.muted
    }
  }

  // ---- night light ----
  KitLine {}

  KitLabel { text: "NIGHT LIGHT"; about: "Warms the colours of every screen; the bar's Brightness module has the same switch" }

  KitRow {
    label: "Night light"
    hint: BrightnessService.nightActive ? "On: the screens are warmer" : "Off"
    KitSwitch { checked: BrightnessService.nightActive; onToggled: BrightnessService.setNight(!checked) }
  }

  KitSliderRow {
    visible: BrightnessService.nightActive
    label: "Warmth"
    snaps: [0, 0.2, 0.4, 0.6, 0.8, 1]
    value: (BrightnessService.temperature - BrightnessService.temperatureMin) / (BrightnessService.temperatureMax - BrightnessService.temperatureMin)
    text: Math.round(pressed ? BrightnessService.temperatureMin + dragValue * (BrightnessService.temperatureMax - BrightnessService.temperatureMin) : BrightnessService.temperature) + " K"
    onMoved: value => BrightnessService.setTemperature(BrightnessService.temperatureMin + value * (BrightnessService.temperatureMax - BrightnessService.temperatureMin))
  }

  KitText {
    visible: root.ds.error !== ""
    width: parent.width
    text: root.ds.error
    color: Theme.red
    wrapMode: Text.WordWrap
  }

  KitGrouper {}
}
