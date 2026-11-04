import QtQuick
import QtQuick.Shapes
import qs.config

// A value drawn as a watch complication (Bezel, docs/shell/design.md › Rings).
// The shape follows what the value is, never taste:
//   fill  — a share of a fixed whole: a closed arc from twelve (battery, volume, memory)
//   gauge — a level with zones: an open 270° arc, its gap down holds the icon (cpu, temperature)
//   ticks — a span with an end: the lit ticks are what is left (a timer)
//   dots  — the steps of a whole: the lit dots are done (a backup)
//   disc  — a state, no amount: filled on, outlined quiet (`quiet`), faint off (`on: false`)
// Inside sits the numeral (`text`) or, without one, the icon. A ring is a circle in
// either corner style: it draws a whole, not a box. Nothing moves at rest; a new value
// eases in (Motion.bar, slow).
Item {
  id: root

  property string kind: "fill"
  property real value: 0                     // 0..1: the lit share
  property int steps: 5                      // dots: how many
  property int size: Theme.ringPill
  property real stroke: Theme.ringStroke(size)
  property color tint: Theme.foreground1     // the lit part (a state colour or a kind's ink)
  property color track: Theme.ringTrack
  property string text: ""                   // the numeral inside
  property string icon: ""                   // inside without a numeral; in the gauge's gap with one
  property bool on: true                     // disc: off draws a faint outline only
  property bool quiet: false                 // disc: on but nothing to say (connected, idle): outlined

  implicitWidth: size
  implicitHeight: size

  property real shown: Math.max(0, Math.min(1, value))
  Behavior on shown { enabled: Motion.bar; NumberAnimation { duration: Motion.slow; easing.type: Motion.easing } }

  readonly property real centre: size / 2
  readonly property real radius: (size - stroke) / 2
  readonly property bool arc: kind === "fill" || kind === "gauge"
  readonly property real arcStart: kind === "gauge" ? 135 : -90
  readonly property real arcSweep: kind === "gauge" ? 270 : 360
  // ticks: fewer at small sizes, so each stays a tick and not a blur
  readonly property int tickCount: size <= Theme.ringPill ? 24 : size <= Theme.ringPeek ? 30 : 60

  // ---- arcs: fill, gauge; dots run on a hairline of the same whole ----
  Shape {
    anchors.fill: parent
    visible: root.arc || root.kind === "dots"
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: root.track
      strokeWidth: root.kind === "dots" ? Math.max(1, root.stroke * 0.3) : root.stroke
      fillColor: Theme.clear
      capStyle: root.kind === "gauge" ? ShapePath.RoundCap : ShapePath.FlatCap
      PathAngleArc {
        centerX: root.centre; centerY: root.centre
        radiusX: root.radius; radiusY: root.radius
        startAngle: root.arcStart; sweepAngle: root.arcSweep
      }
    }
    ShapePath {
      // a round cap on an empty arc would still draw a dot
      strokeColor: root.arc && root.shown > 0.005 ? root.tint : Theme.clear
      strokeWidth: root.stroke
      fillColor: Theme.clear
      capStyle: ShapePath.RoundCap
      PathAngleArc {
        centerX: root.centre; centerY: root.centre
        radiusX: root.radius; radiusY: root.radius
        startAngle: root.arcStart; sweepAngle: root.arcSweep * root.shown
      }
    }
  }

  // ---- ticks: a tick steps, it never sweeps ----
  Repeater {
    model: root.kind === "ticks" ? root.tickCount : 0
    Item {
      required property int index
      anchors.fill: parent
      rotation: index * 360 / root.tickCount
      Rectangle {
        x: root.centre - width / 2
        y: 0
        width: root.size <= Theme.ringPill ? 1.2 : 1.5
        height: root.stroke * 1.3
        color: index < Math.round(root.value * root.tickCount) ? root.tint : root.track
      }
    }
  }

  // ---- dots: one per step, the first at twelve ----
  Repeater {
    model: root.kind === "dots" ? root.steps : 0
    Rectangle {
      required property int index
      readonly property real angle: (index / root.steps) * 2 * Math.PI - Math.PI / 2
      width: root.stroke * 1.6
      height: width
      radius: width / 2
      x: root.centre + root.radius * Math.cos(angle) - width / 2
      y: root.centre + root.radius * Math.sin(angle) - height / 2
      color: index < Math.round(root.value * root.steps) ? root.tint : Theme.ringOff
    }
  }

  // ---- disc: a state ----
  Rectangle {
    anchors.fill: parent
    visible: root.kind === "disc"
    radius: width / 2
    color: root.on && !root.quiet ? root.tint : Theme.clear
    border.width: root.on && !root.quiet ? 0 : Math.max(1, root.stroke * 0.6)
    border.color: root.on ? root.tint : root.track
  }

  // ---- inside: the numeral, else the icon ----
  KitText {
    id: numeral
    anchors.centerIn: parent
    // the gauge's numeral sits a little high: the gap below holds the icon
    anchors.verticalCenterOffset: root.kind === "gauge" && root.icon !== "" && root.size > Theme.ringPill ? -root.size * 0.06 : 0
    visible: root.text !== ""
    text: root.text
    color: root.kind === "disc" && root.on && !root.quiet ? Theme.inkOn(root.tint) : Theme.foreground1
    font.weight: Font.Bold
    font.features: { "tnum": 1 }
    // two digits fit the inside at every size; a longer value shrinks to fit
    readonly property real inner: root.size - 2 * root.stroke - 2
    readonly property int px: Math.max(6, Math.min(Math.round(root.size * 0.3) + 2, inner / Math.max(2, root.text.length) / 0.62))
    font.pixelSize: px
    font.letterSpacing: -px * 0.04
  }
  KitIcon {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    // with a numeral, only a gauge keeps its icon: in the gap, under it
    anchors.verticalCenterOffset: root.text !== "" ? root.size * 0.36 : 0
    visible: root.icon !== "" && (root.text === "" || (root.kind === "gauge" && root.size > Theme.ringPill))
    name: root.icon
    size: Math.round(root.size * (root.text === "" ? (root.kind === "disc" ? 0.56 : 0.5) : 0.24))
    tint: root.kind === "disc" && root.on && !root.quiet ? Theme.inkOn(root.tint)
        : root.kind === "disc" ? (root.on ? root.tint : Theme.muted) : Theme.muted
  }
}
