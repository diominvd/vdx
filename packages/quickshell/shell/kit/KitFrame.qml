import QtQuick
import qs.config

// Popup body: flat dark surface, a thin light frame, sharp corners, a padded
// column. Round corners: Theme.radiusSurface. A bar popup opened inside the
// island (`inIsland`, set by the Island) takes the island as its surface and
// frame and draws neither. Children stack vertically and take
// `width: parent.width`. A window showing the same content sets
// `framed: false` and its own `padding`.
// Material: one soft surface (Theme.radiusPopup) and, when the column has KitLines,
// the runs between them sit in tonal sections (Theme.sectionFill, radiusSection) instead of
// the lines: the lines turn into the gaps between sections. A header (KitHeader), a
// `kitUnboxed` item and a run of buttons alone (`kitFree`: a footer) stand on the surface.
Rectangle {
  id: root

  default property alias content: column.data
  property int padding: Theme.popupPadding
  property bool framed: true
  // a window whose first item is a KitHeader: its top sits this much higher
  property int headerInset: 0
  // the same for a window whose last item is text: its line box ends below the ink
  property int bottomInset: 0
  property bool inIsland: false
  // a menu: as wide as its content, not at least Theme.modulePopupWidth (the island's
  // popup width follows this too). The content sets implicitWidth itself.
  property bool fitWidth: false

  // on a fractional scale (1.2) a 1 px frame and an odd size fall between device pixels
  // and the stroke looks bent: the frame and the size are whole device pixels
  readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1

  implicitWidth: Math.ceil(Theme.modulePopupWidth * dpr) / dpr
  implicitHeight: Math.ceil((column.implicitHeight + footShift + 2 * padding - headerInset - bottomInset) * dpr) / dpr
  radius: framed ? Theme.radiusPopup : 0
  color: inIsland ? Theme.clear : Theme.background0
  border.width: framed && !inIsland ? Math.max(1, Math.round(Theme.windowFrameWidth * dpr)) / dpr : 0
  border.color: Theme.popupFrame

  // ---- material sections ----
  property var sections: []
  property var spacers: []
  property var padded: []          // [{item, orig}]: titled groups moved down to part their sections
  property var footer: []          // buttons at the end, after a section with no line between: shifted down
  property real footShift: 0

  // a run that is only buttons (a footer, a row of actions) is not boxed
  function free(c) {
    if (c.kitFree === true || c.isKitHeader === true || c.kitUnboxed === true) return true;
    if (c.kitFree === false || c.data === undefined) return false;
    const kids = Array.from(c.children).filter(k => k.visible && k.width > 0 && k.height > 0);
    return kids.length > 0 && kids.every(k => k.kitFree === true);
  }

  // a group of its own: a caps title, or a column (a positioner) that starts with one
  function titled(c) {
    if (c.isKitLabel === true) return c.trimTop !== undefined;
    if (c.topPadding === undefined) return false;
    const first = Array.from(c.children).find(k => k.visible && k.height > 0);
    return first !== undefined && first.isKitLabel === true;
  }

  function origOf(c) {
    const p = padded.find(e => e.item === c);
    return p ? p.orig : c.isKitLabel === true ? c.trimTop : c.topPadding;
  }
  function setPad(c, orig, extra) {
    if (c.isKitLabel === true) c.trimTop = orig - extra;
    else c.topPadding = orig + extra;
  }

  // a column of the popup's that holds its lines (an overview the popup wraps): walked into
  function host(c) {
    return c.topPadding !== undefined && c.spacing !== undefined
      && Array.from(c.children).some(k => k.isKitLine === true && k.sectionBreak);
  }
  // the column's items, hosts walked into, in order
  function flat(col, out) {
    for (const c of col.children) {
      if (c.visible && host(c)) flat(c, out);
      else out.push(c);
    }
    return out;
  }
  function topOf(c) { return c.mapToItem(column, 0, 0).y; }

  function layout() {
    const items = flat(column, []);
    const lines = items.filter(c => c.isKitLine === true && c.sectionBreak);
    const material = Theme.material && lines.length > 0;
    for (const l of spacers) if (l && (!material || lines.indexOf(l) < 0)) l.gapHeight = -1;
    const pad = Theme.sectionPad, gap = Theme.gapMedium;
    const sp = c => c.parent ? c.parent.spacing ?? 0 : 0;
    // runs of shown items between the shown lines; a titled group parts a run
    const runs = [[]], marks = [], parts = [];
    if (material) for (const c of items) {
      if (!c.visible) continue;
      if (c.isKitLine === true && c.sectionBreak) { marks.push(c); runs.push([]); continue; }
      if (c.isKitLine === true || c.height <= 0 || c.width <= 0) continue;
      const run = runs[runs.length - 1];
      if (run.length > 0 && titled(c) && !run.every(k => root.free(k))) {
        parts.push(c);
        runs.push([]);
        marks.push(null);
      }
      runs[runs.length - 1].push(c);
    }
    // the groups no longer parted get their own top back
    const keep = [];
    for (const e of padded) {
      if (parts.indexOf(e.item) >= 0) keep.push(e);
      else if (e.item) setPad(e.item, e.orig, 0);
    }
    const extraOf = c => Math.max(0, gap + 2 * pad - sp(c));
    for (const c of parts) {
      const orig = origOf(c);
      if (!keep.find(e => e.item === c)) keep.push({ item: c, orig: orig });
      setPad(c, orig, extraOf(c));
    }
    padded = keep;
    // the last run's trailing buttons (an Open settings under the rows) leave its section
    const last = runs[runs.length - 1], foot = [];
    while (material && foot.length < last.length - 1 && root.free(last[last.length - 1 - foot.length])
           && last[last.length - 1 - foot.length].kitShift !== undefined)
      foot.unshift(last[last.length - 1 - foot.length]);
    if (foot.length > 0 && last.slice(0, last.length - foot.length).every(c => root.free(c))) foot.length = 0;
    const shift = foot.length > 0 ? Math.max(0, gap + pad - sp(foot[0])) : 0;
    for (const c of footer) if (c && foot.indexOf(c) < 0) c.kitShift = 0;
    for (const c of foot) c.kitShift = shift;
    footer = foot;
    footShift = shift;
    if (foot.length > 0) last.length = last.length - foot.length;
    if (!material) { sections = []; spacers = []; return; }

    const boxed = runs.map(r => r.length > 0 && !r.every(c => root.free(c)));
    const out = [];
    runs.forEach((r, i) => {
      if (!boxed[i]) return;
      const top = topOf(r[0]) + (parts.indexOf(r[0]) >= 0 ? extraOf(r[0]) : 0), last = r[r.length - 1];
      out.push({ y: top - pad, h: topOf(last) + last.height - top + 2 * pad });
    });
    // a line becomes the gap: a standard one between two surfaces, a box's own pad added
    marks.forEach((l, i) => {
      if (!l) return;
      const above = runs[i].length > 0, below = runs[i + 1].length > 0;
      l.gapHeight = !above || !below ? 0
        : Math.max(0, gap + (boxed[i] ? pad : 0) + (boxed[i + 1] ? pad : 0) - 2 * sp(l));
    });
    spacers = lines;
    sections = out;
  }

  Timer { id: soon; interval: 0; onTriggered: root.layout() }
  // Strict draws no sections: nothing to measure once its lines are lines again
  Connections {
    target: column
    enabled: Theme.material || root.spacers.length > 0 || root.padded.length > 0 || root.footer.length > 0
    function onPositioningComplete() { soon.restart(); }
  }
  onVisibleChanged: if (Theme.material) soon.restart()
  Connections {
    target: Theme
    function onMaterialChanged() { soon.restart(); }
  }

  Repeater {
    model: root.sections

    Rectangle {
      required property var modelData
      x: column.x - Theme.sectionPad
      y: column.y + modelData.y
      width: column.width + 2 * Theme.sectionPad
      height: modelData.h
      radius: Theme.radiusSection
      color: Theme.sectionFill
    }
  }

  KitColumn {
    id: column
    x: root.padding
    y: root.padding - root.headerInset
    width: root.width - 2 * root.padding
    spacing: Theme.sectionGap
  }
}
