import QtQuick
import QtQuick.Shapes
import qs.config

// The bezel (Bezel, the act distance): what is left of a span runs along the island's
// own outline, from twelve, clockwise — readable from the corner of the eye while the
// expanded activity is open. Drawn over the shape's frame; nothing at rest.
Shape {
  id: root

  property real value: 0                       // 0..1: the lit share
  property color tint: Theme.orange
  property real radius: 0                      // the island's corner
  property real stroke: 2

  // the outline, a stroke's half inside the shape
  readonly property real h: stroke / 2
  readonly property real r: Math.max(0, Math.min(radius, width / 2, height / 2) - h)
  readonly property real length: 2 * (width - 2 * h) + 2 * (height - 2 * h) - (8 - 2 * Math.PI) * r

  // a value change steps: a tick, never a sweep
  readonly property real shown: Math.max(0, Math.min(1, value))

  ShapePath {
    strokeColor: root.tint
    strokeWidth: root.stroke
    fillColor: Theme.clear
    capStyle: ShapePath.FlatCap
    joinStyle: ShapePath.RoundJoin
    // the lit length as one dash, the rest a gap longer than the path (units: stroke widths)
    strokeStyle: ShapePath.DashLine
    dashPattern: [Math.max(0.001, root.length * root.shown / root.stroke), (root.length + 1) / root.stroke]

    PathSvg {
      path: {
        const w = root.width, ht = root.height, h = root.h, r = root.r;
        return "M " + (w / 2) + " " + h
          + " L " + (w - h - r) + " " + h
          + " A " + r + " " + r + " 0 0 1 " + (w - h) + " " + (h + r)
          + " L " + (w - h) + " " + (ht - h - r)
          + " A " + r + " " + r + " 0 0 1 " + (w - h - r) + " " + (ht - h)
          + " L " + (h + r) + " " + (ht - h)
          + " A " + r + " " + r + " 0 0 1 " + h + " " + (ht - h - r)
          + " L " + h + " " + (h + r)
          + " A " + r + " " + r + " 0 0 1 " + (h + r) + " " + h
          + " Z";
      }
    }
  }
}
