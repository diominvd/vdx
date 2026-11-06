import QtQuick
import qs.config

// Turns a Settings Column into groups (as in macOS System Settings). A KitLabel
// starts a group (its caps title), a KitLine ends one (and is hidden); the rows
// between sit inset in one raised box with a hairline between rows. A child
// Column with its own KitGrouper (a section) is walked into: its rows join the
// page's groups, so sections under one title make one box. The outermost
// grouper draws; a nested one only keeps its column's spacing and asks the
// outer one to look again. A child with `property bool kitUnboxed: true` (a
// preview, a board of chips) stands on the page; a title that is not a
// KitLabel says `readonly property bool isKitLabel: true`. Sliders take the
// row layout (`rowStyle`). Strict: a raised card in a faint line, hairlines between rows;
// Material: a tonal section, no lines.
// Inside an item with `kitFlat: true` (a dropdown's options, Apps / Bar modules) it draws no
// boxes: the rows stand on the dropdown's own plate, hairlines between them and between groups,
// the titles hidden.
// Put it last: it is 1×1 (a Column hides a zero-size child, and its drawing
// with it), placed at the end and taken back with a negative bottom padding;
// it draws behind the rows in the column's coordinates.
Item {
  id: root

  readonly property bool isKitGrouper: true
  readonly property int padX: Theme.groupInset
  property int padY: Theme.settingsRowInset
  readonly property Item column: parent

  property bool flat: false                 // an ancestor says kitFlat: hairlines only, no boxes
  property Item outer: null                 // the grouper of an enclosing settings column
  property var boxes: []
  property var lines: []

  width: 1
  height: 1
  z: -1

  FontMetrics { id: inkMetrics }

  // A header caption exposes its rendered edge independently of taller
  // trailing buttons. Font line boxes include descender space with no ink.
  function captionBottom(item, host) {
    if (item.text !== undefined && item.font !== undefined && item.baselineOffset !== undefined) {
      inkMetrics.font = item.font;
      const rect = inkMetrics.tightBoundingRect(item.text);
      return item.mapToItem(host, 0, item.baselineOffset + rect.y + rect.height).y;
    }
    const children = Array.from(item.children).filter(c => c.visible && c.width > 0 && c.height > 0);
    return children.length ? Math.max(...children.map(c => captionBottom(c, host)))
      : item.mapToItem(host, 0, item.height).y;
  }

  function grouperOf(c) {
    for (const k of c?.data ?? []) if (k.isKitGrouper) return k;
    return null;
  }

  // a child that is a section: a Column with its own grouper, or a Loader of one
  function sectionOf(c) {
    if (grouperOf(c)) return c;
    if (c?.item && grouperOf(c.item)) return c.item;
    return null;
  }

  // a section whose first shown item is a title
  function startsTitled(s) {
    const first = Array.from(s.data).find(n => n.visible !== undefined && n.height !== undefined && !n.isKitGrouper && n.visible && n.height > 0);
    return first !== undefined && first.isKitLabel === true;
  }

  function findFlat() {
    for (let p = column ? column.parent : null; p; p = p.parent) if (p.kitFlat) return true;
    return false;
  }

  function findOuter() {
    for (let p = column ? column.parent : null; p; p = p.parent) {
      if (p.kitUnboxed) return null; // independent panes own their groups
      const g = grouperOf(p);
      if (g) return g;
    }
    return null;
  }

  // spacing first, shown or not: the page's height is right before anyone scrolls in it
  function prepare(col) {
    col.spacing = 2 * root.padY;
    if (col !== root.column) col.bottomPadding = -(col.spacing + root.height);
    for (const c of col.data) {
      const inner = sectionOf(c);
      if (inner && inner !== col) prepare(inner);
    }
  }

  function layout() {
    const col = root.column;
    if (!col) return;
    // looked up here, not once at creation: a Loader's item completes before it is placed in the
    // page, and a grouper that took itself for the outermost would draw its own boxes over the page's
    root.outer = root.findOuter();
    root.flat = root.findFlat();
    if (root.outer) { root.boxes = []; root.lines = []; root.outer.relayout(); return; }
    prepare(col);
    // the outermost column keeps room for its last box's lower padding (a pane's scroll reaches it)
    col.bottomPadding = -(col.spacing + root.height) + root.padY;
    if (!col.visible) return;   // hidden, every child reads invisible: done when it shows
    const out = [], hair = [], surfaces = [], dividers = [];
    let run = null;
    let last = "";          // what came before: "label", "box" (a boxed row), "free" (an unboxed item), "line"
    let title = null;       // the label just seen, until the next item
    const close = () => { if (run) out.push({ y: run.top - root.padY, h: run.bottom - run.top + 2 * root.padY }); run = null; };

    // `data`, not `children`: a page may shadow `children`; non-visual objects have no `visible`
    const walk = (parent, dy) => {
      // (a layer's ShaderEffectSource, such as a KitLine's, is not a row)
      const items = Array.from(parent.data).filter(c => c.visible !== undefined && c.height !== undefined && !c.isKitGrouper && c.sourceItem === undefined);
      items.forEach((c, i) => {
        // flat: a title only parts the groups, unseen
        if (root.flat && c.isKitLabel) { c.visible = false; close(); last = "label"; return; }
        // a line ends the group; before a title it goes (the title parts the boxes),
        // before rows it stays, unseen, as the gap between two boxes
        if (c.isKitLine && c.sectionBreak) {
          const next = items.slice(i + 1).find(n => n.visible && !n.isKitLine && n.height > 0);
          c.groupManaged = true;
          // No leading/trailing gap, nor an extra interval before a heading.
          c.groupCollapsed = root.flat || !run || !next || next.isKitLabel === true
            || (sectionOf(next) !== null && startsTitled(sectionOf(next)));
          if (c.visible) close();
          return;
        }
        if (!c.visible || c.height <= 0 || c.width <= 0 && !c.isKitLabel) return;
        if (c.isKitLabel) {
          // a box's edge lies padY beyond its rows; beside an unboxed item the caption gives the
          // same back, so the gap above and below a title is one standard whatever is next to it
          c.trimTop = last === "free" ? root.padY : 0;
          c.trimBottom = 0;
          surfaces.push({ top: dy + c.y - c.trimTop, bottom: dy + c.y + c.height + c.trimBottom });
          close();
          c.x = root.padX;
          c.width = parent.width - 2 * root.padX;
          last = "label"; title = c;
          return;
        }
        const inner = sectionOf(c);
        if (inner) { c.x = 0; c.width = parent.width; walk(inner, dy + c.y + (inner === c ? 0 : inner.y)); return; }
        if (c.kitUnboxed) {
          close(); c.x = 0; c.width = parent.width;
          if (c.isKitLine) { dividers.push({ item: c, y: dy + c.y }); last = "line"; }
          else if (last === "label" && title) { title.trimBottom = root.padY; last = "free"; }
          else last = "free";
          if (!c.isKitLine) surfaces.push({ top: dy + c.y, bottom: c.kitCaption ? captionBottom(c.kitCaption, col) : dy + c.y + c.height });
          return;
        }
        c.x = root.padX;
        c.width = parent.width - 2 * root.padX;
        if (c.rowStyle !== undefined) c.rowStyle = true;
        last = "box";
        const top = dy + c.y, bottom = top + c.height;
        if (run) { hair.push(top - root.padY); run.bottom = bottom; }
        else run = { top: top, bottom: bottom };
      });
    };
    walk(col, 0);
    close();
    // A card extends padY beyond its rows. Centre physical dividers in the
    // remaining space so header→stroke and stroke→card are exactly equal.
    const edges = surfaces.concat(out.map(b => ({ top: b.y, bottom: b.y + b.h })));
    for (const d of dividers) {
      const above = edges.filter(b => b.bottom <= d.y).map(b => b.bottom);
      const below = edges.filter(b => b.top >= d.y + d.item.height).map(b => b.top);
      d.item.strokeOffset = above.length && below.length
        ? (Math.max(...above) + Math.min(...below) - d.item.height) / 2 - d.y : 0;
    }
    root.boxes = root.flat ? [] : out;
    // flat: a hairline also between two groups (the box's top edge), across the full width
    root.lines = root.flat ? hair.concat(out.slice(1).map(b => b.y)) : hair;
  }

  function relayout() { soon.restart(); }

  Connections {
    target: root.column
    // Measure after the positioner has settled, not during its layout pass.
    function onPositioningComplete() { soon.restart(); }
    function onWidthChanged() { soon.restart(); }
    function onVisibleChanged() { soon.restart(); }
  }
  // the style moves the rows in or out of their boxes
  Connections {
    target: Theme
    function onMaterialChanged() { root.relayout(); }
  }
  Timer { id: soon; interval: 0; onTriggered: root.layout() }
  Component.onCompleted: soon.restart()

  Repeater {
    model: root.boxes

    Rectangle {
      required property var modelData
      // the column's coordinates (a positioner may have moved this item)
      x: -root.x
      y: modelData.y - root.y
      width: root.column ? root.column.width : 0
      height: modelData.h
      radius: Theme.radiusCard
      color: Theme.groupFill
      border.width: Theme.material ? 0 : Theme.hairline
      border.color: Theme.controlLineRest
    }
  }

  // Material: a tonal section's rows need no hairlines between them (Strict keeps them)
  Repeater {
    model: Theme.material && !root.flat ? [] : root.lines

    Rectangle {
      required property real modelData
      x: (root.flat ? 0 : root.padX) - root.x
      y: Math.round(modelData - root.y)    // on a whole pixel: a sharp hairline
      width: root.column ? root.column.width - (root.flat ? 0 : 2 * root.padX) : 0
      height: Theme.dividerThickness
      color: Theme.dividerColor
    }
  }
}
