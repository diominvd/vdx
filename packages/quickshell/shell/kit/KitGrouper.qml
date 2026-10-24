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
// row layout (`rowStyle`).
// Put it last: it is 1×1 (a Column hides a zero-size child, and its drawing
// with it), placed at the end and taken back with a negative bottom padding;
// it draws behind the rows in the column's coordinates.
Item {
  id: root

  readonly property bool isKitGrouper: true
  readonly property int padX: Theme.gapWide
  readonly property int padY: Theme.gapWide
  readonly property Item column: parent

  property Item outer: null                 // the grouper of an enclosing settings column
  property var boxes: []
  property var lines: []

  width: 1
  height: 1
  z: -1

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

  function findOuter() {
    for (let p = column ? column.parent : null; p; p = p.parent) {
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
    if (root.outer) { root.boxes = []; root.lines = []; root.outer.relayout(); return; }
    prepare(col);
    // the outermost column keeps room for its last box's lower padding (a pane's scroll reaches it)
    col.bottomPadding = -(col.spacing + root.height) + root.padY;
    if (!col.visible) return;   // hidden, every child reads invisible: done when it shows
    const out = [], hair = [];
    let run = null;
    const close = () => { if (run) out.push({ y: run.top - root.padY, h: run.bottom - run.top + 2 * root.padY }); run = null; };

    // `data`, not `children`: a page may shadow `children`; non-visual objects have no `visible`
    const walk = (parent, dy) => {
      // (a layer's ShaderEffectSource, such as a KitLine's, is not a row)
      const items = Array.from(parent.data).filter(c => c.visible !== undefined && c.height !== undefined && !c.isKitGrouper && c.sourceItem === undefined);
      items.forEach((c, i) => {
        // a line ends the group; before a title it goes (the title parts the boxes),
        // before rows it stays, unseen, as the gap between two boxes
        if (c.isKitLine) {
          const next = items.slice(i + 1).find(n => !n.isKitLine && n.visible && n.height > 0);
          c.opacity = 0;
          c.visible = next !== undefined && !next.isKitLabel && !(sectionOf(next) && startsTitled(sectionOf(next)));
          close();
          return;
        }
        if (!c.visible || c.height <= 0 || c.width <= 0 && !c.isKitLabel) return;
        if (c.isKitLabel) { close(); c.x = root.padX; c.width = Math.max(0, parent.width - 2 * root.padX); return; }
        const inner = sectionOf(c);
        if (inner) { c.x = 0; c.width = parent.width; walk(inner, dy + c.y + (inner === c ? 0 : inner.y)); return; }
        if (c.kitUnboxed) { close(); c.x = 0; c.width = parent.width; return; }
        c.x = root.padX;
        c.width = Math.max(0, parent.width - 2 * root.padX);
        if (c.rowStyle !== undefined) c.rowStyle = true;
        const top = dy + c.y, bottom = top + c.height;
        if (run) { hair.push(top - root.padY); run.bottom = bottom; }
        else run = { top: top, bottom: bottom };
      });
    };
    walk(col, 0);
    close();
    root.boxes = out;
    root.lines = hair;
  }

  function relayout() { soon.restart(); settle.restart(); }

  Connections {
    target: root.column
    // and again once a KitColumn's rows have glided to their place
    function onPositioningComplete() { root.layout(); settle.restart(); }
    function onWidthChanged() { soon.restart(); }
    function onVisibleChanged() { soon.restart(); }
  }
  Timer { id: soon; interval: 0; onTriggered: root.layout() }
  Timer { id: settle; interval: Motion.normal + 40; onTriggered: root.layout() }
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
      color: Theme.background1
      border.width: Theme.frameWidth
      border.color: Theme.background2
    }
  }

  Repeater {
    model: root.lines

    Rectangle {
      required property real modelData
      x: root.padX - root.x
      y: Math.round(modelData - root.y)    // on a whole pixel: a sharp hairline
      width: root.column ? Math.max(0, root.column.width - 2 * root.padX) : 0
      height: 1
      color: Theme.background2
    }
  }
}
