import QtQuick
import qs.config
import qs.kit

// The hub's blocks, in the order they have on the hub: the clock and day stand first and
// stay; each other block is a KitFoldRow in a KitReorderList (drag its handle; the switch
// shows or hides it; the arrow unfolds its options, as in Live activities). Stored by HubBlocks.
Column {
  id: root

  function jump(key) { list.open = key; }

  signal arrange()                              // the Hub row of Layout

  KitLabel { text: "BLOCKS"; about: "Drag a row to move it on the hub; the switch shows or hides it" }

  // the clock and the day: always the first
  KitFoldRow {
    key: "clock"
    index: 0
    draggable: false
    label: "Clock and day"
    hint: "Date, clock, settings and power buttons"
    checked: true
    tag: "ALWAYS ON"
  }

  KitReorderList {
    id: list
    width: root.width
    keys: HubBlocks.order
    onOrdered: list => HubBlocks.setOrder(list)

    delegate: KitFoldRow {
      id: row
      label: HubBlocks.names[key]
      hint: HubBlocks.notes[key]
      checked: HubBlocks.shown(key)
      foldable: options.any
      onToggled: HubBlocks.setShown(key, !checked)

      HubBlockOptions { id: options; block: row.key; onArrange: root.arrange() }
    }
  }

  KitGrouper {}
}
