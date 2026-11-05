import QtQuick
import qs.config
import qs.kit

// A slider bound to one of Kimmy's numbers (ModuleSettings "companion"): `key`, `fallback`
// (the default), `from` … `to` in `step`s, `unit` after the reading, `zeroText` for the
// lowest stop ("None"). It writes only when the snapped number changes, so a drag
// stays live in the preview without a write per pixel.
KitSliderRow {
  id: root

  property string key
  property real fallback: 0
  property real from: 0
  property real to: 100
  property real step: 1
  property string unit: ""
  property string zeroText: ""

  readonly property real current: {
    const v = Number(ModuleSettings.get("companion", key, fallback));
    return isNaN(v) ? fallback : Math.max(from, Math.min(to, v));
  }
  readonly property int stopCount: Math.max(1, Math.round((to - from) / step))
  function numberAt(pos) { return from + Math.round(pos * stopCount) * step; }
  function reading(n) { return n === from && zeroText !== "" ? zeroText : Math.round(n) + unit; }

  snaps: {
    const out = [];
    for (let i = 0; i <= stopCount; i++) out.push(i / stopCount);
    return out;
  }
  value: (current - from) / (to - from)
  text: reading(pressed ? numberAt(dragValue) : current)
  onMoved: pos => {
    const n = numberAt(pos);
    if (n !== current) ModuleSettings.set("companion", key, n);
  }
}
