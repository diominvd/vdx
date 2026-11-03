import QtQuick
import qs.config

// A list of KitFoldRow the user reorders by their handles: the dragged row follows the
// pointer, the others glide aside, and it settles into its slot on release. `keys` is the
// order (a row's `key`); `ordered(keys)` says the new one; `delegate` makes a row (a
// KitFoldRow). One option unfolds at a time (`open` is its key). The rows are boxed and
// parted by hairlines like any rows of a Settings page (KitGrouper sees this as one item).
Item {
  id: root

  readonly property bool isReorderList: true

  property var keys: []
  property Component delegate: null
  property int rowHeight: 52                   // Theme.rowHeight for a list of plain rows; 52 holds a 40 px preview
  property int bodyGap: 0                      // between a row and its unfolded options (a list of plain rows needs its inset)
  readonly property int gap: 2 * Theme.settingsRowInset    // between two rows: a hairline in the middle
  property string open: ""
  property bool settling: false                // a row is gliding to its slot: its y is animated

  signal ordered(var keys)

  // the rows keep their items while one is dragged: a ListModel moves them, a new array would
  // rebuild them and drop the handle's press
  readonly property ListModel order: ListModel {}
  function sync() {
    if (order.count === keys.length && keys.every((k, i) => order.get(i).key === k)) return;
    order.clear();
    for (const k of keys) order.append({ key: k });
    relayout();
  }
  onKeysChanged: sync()
  Component.onCompleted: sync()

  width: parent ? parent.width : 0
  height: 0

  // the slots, top to bottom: each row's y from the heights of those above (they unfold)
  function relayout() {
    let y = 0;
    for (let i = 0; i < order.count; i++) {
      const r = rows.itemAt(i);
      if (!r) continue;
      r.slotY = y;
      y += r.height + gap;
    }
    root.height = Math.max(0, y - gap);
  }
  Connections { target: rows; function onItemAdded() { root.relayout(); } function onItemRemoved() { root.relayout(); } }

  // the dragged row asks for the slot under its middle
  function dragTo(key, top) {
    let from = -1;
    for (let i = 0; i < order.count; i++) if (order.get(i).key === key) from = i;
    const at = Math.max(0, Math.min(order.count - 1, Math.round(top / (rowHeight + gap))));
    if (from < 0 || from === at) return;
    settling = true;
    order.move(from, at, 1);
    relayout();
    // the new order is told once, at the drop: saving it (and a hub redrawn from it) at every
    // slot the row passes made the drag stutter
    const list = [];
    for (let i = 0; i < order.count; i++) list.push(order.get(i).key);
    pending = list;
  }
  property var pending: null

  // let the rows glide into their slots, then stop animating them (unfolding must not lag)
  function settle() {
    settling = true;
    relayout();
    settleOff.restart();
    if (pending) { const list = pending; pending = null; ordered(list); }
  }
  Timer { id: settleOff; interval: Motion.normal + 50; onTriggered: root.settling = false }

  Repeater {
    id: rows
    model: root.order
    delegate: root.delegate
  }
}
