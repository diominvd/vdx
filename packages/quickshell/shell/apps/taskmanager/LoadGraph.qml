import QtQuick
import qs.config

// A sparkline of the last `slots` samples, newest on the right: a 2px line
// over a faint fill, a recessive baseline, no grid. `values2` adds a second,
// thinner line (network up next to down). Hovering puts a crosshair on a
// sample and sets `hoverIndex` (into `values`; -1 when away) — the owner shows
// that sample's value in its label.
Item {
  id: root

  property var values: []
  property var values2: []
  property real ceiling: 100                // the top of the scale; 0: the largest value (at least `floor`)
  property real floor: 1
  property int slots: 60
  property color tint: Theme.foreground0
  property color tint2: Theme.muted

  property int hoverIndex: -1

  readonly property real scaleTop: ceiling > 0 ? ceiling
    : Math.max(floor, values.reduce((m, v) => Math.max(m, v), 0), values2.reduce((m, v) => Math.max(m, v), 0))

  function xOf(i, count) { return width - (count - 1 - i) * width / (slots - 1); }
  function yOf(v) { return height - 1 - Math.min(1, v / scaleTop) * (height - 3); }

  onValuesChanged: canvas.requestPaint()
  onValues2Changed: canvas.requestPaint()
  onHoverIndexChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onTintChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent

    onPaint: {
      const ctx = getContext("2d");
      ctx.reset();
      const w = width, h = height;
      const line = (list, color, lineWidth, fill) => {
        if (list.length < 2) return;
        ctx.beginPath();
        list.forEach((v, i) => {
          const x = root.xOf(i, list.length), y = root.yOf(v);
          if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        });
        if (fill) {
          ctx.save();
          ctx.lineTo(root.xOf(list.length - 1, list.length), h);
          ctx.lineTo(root.xOf(0, list.length), h);
          ctx.closePath();
          ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.14);
          ctx.fill();
          ctx.restore();
          ctx.beginPath();
          list.forEach((v, i) => {
            const x = root.xOf(i, list.length), y = root.yOf(v);
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
          });
        }
        ctx.strokeStyle = color;
        ctx.lineWidth = lineWidth;
        ctx.lineJoin = "round";
        ctx.stroke();
      };

      // the baseline
      ctx.fillStyle = Theme.background3;
      ctx.fillRect(0, h - 1, w, 1);

      line(root.values2, root.tint2, 1.5, false);
      line(root.values, root.tint, 2, true);

      // the crosshair on the hovered sample
      if (root.hoverIndex >= 0 && root.hoverIndex < root.values.length) {
        const x = Math.round(root.xOf(root.hoverIndex, root.values.length));
        ctx.fillStyle = Theme.foreground2;
        ctx.fillRect(x, 0, 1, h);
        ctx.beginPath();
        ctx.arc(x, root.yOf(root.values[root.hoverIndex]), 3, 0, 2 * Math.PI);
        ctx.fillStyle = root.tint;
        ctx.fill();
      }
    }
  }

  // a wide hit area: the nearest sample to the pointer
  MouseArea {
    anchors.fill: parent
    anchors.margins: -4
    hoverEnabled: true
    onPositionChanged: mouse => {
      const n = root.values.length;
      if (n === 0) { root.hoverIndex = -1; return; }
      const i = Math.round(n - 1 - (root.width - (mouse.x - 4)) * (root.slots - 1) / root.width);
      root.hoverIndex = i >= 0 && i < n ? i : -1;
    }
    onExited: root.hoverIndex = -1
  }
}
