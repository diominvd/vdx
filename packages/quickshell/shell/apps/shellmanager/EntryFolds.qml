import QtQuick
import QtQuick.Controls as Controls
import qs.config
import qs.kit

// The page of Apps and Bar modules: one entry, one dropdown, like Bar › Live. A search, then
// one box of KitFoldRow by name — an icon, the name, its state under it, an arrow. Unfolded, a
// row shows the entry's options in place (`options`, built on the first unfold): no page inside
// a page. One row is open at a time.
// Entries: {id, label, icon, state, off (not installed: muted),
// switchable + on: a switch on the row (`switched(id, on)`); a row that is off stays where it
// is, dimmed and folded}.
// `options` is a Component whose root declares `property string entryId`.
// `selected` is the open entry ("" none); `open(id)` shows it from elsewhere.
Item {
  id: root

  property var model: []
  property string selected: ""
  property string searchHint: "Search…"
  property Component options: null
  property real viewportRightInset: Theme.windowPadding

  signal switched(string id, bool on)

  property string query: ""
  readonly property string needle: query.trim().toLowerCase()

  // by name, the switched-off ones in place
  readonly property var ordered: model.slice().sort((a, b) => a.label.localeCompare(b.label))
  readonly property var matches: ordered.filter(e => e.label.toLowerCase().includes(needle))

  // from another page: clear the search, unfold the entry, bring it into view
  function open(id) {
    if (!model.some(e => e.id === id)) return;
    query = "";
    selected = id;
    Qt.callLater(() => {
      const at = matches.findIndex(e => e.id === id);
      if (at >= 0) pane.contentY = Math.max(0, Math.min(block.y + list.y + 52 * at + list.gap * at - Theme.gapGroup, pane.contentHeight - pane.height));
    });
  }

  Flickable {
    id: pane
    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: -root.viewportRightInset }
    Controls.ScrollBar.vertical: KitScrollBar {}
    contentHeight: page.implicitHeight
    bottomMargin: Theme.windowPadding
    interactive: contentHeight + bottomMargin > height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: page
      width: root.width

      // the page's own rhythm (KitGrouper) spaces the search and the list, as on every page
      Item {
        readonly property bool kitUnboxed: true
        width: parent.width
        // the grouper leaves a row inset between this and the box: topped up to the same
        // gap the header has above it (Theme.settingsGap)
        height: search.height + Theme.settingsGap - Theme.settingsRowInset

        KitInput {
          id: search
          width: parent.width
          placeholder: root.searchHint
          icon: "search"
          text: root.query
          onTextEdited: root.query = text
          onAccepted: if (root.matches.length > 0) root.selected = root.matches[0].id
        }
      }

      Column {
        id: block
        readonly property var entries: root.matches
        visible: entries.length > 0
        width: page.width

        KitReorderList {
          id: list
          width: block.width
          keys: block.entries.map(e => e.id)
          // one row open: the selection follows it (a Binding: a row's
          // click assigns `open` and would end a plain one)
          Binding { target: list; property: "open"; value: root.selected }
          onOpenChanged: if (open !== root.selected) root.selected = open

          delegate: KitFoldRow {
            id: row
            readonly property var entry: block.entries.find(e => e.id === key) ?? ({})

            label: entry.label ?? key
            hint: entry.state ?? ""
            // off: it stays where it is, dimmed, and does not unfold
            checked: entry.switchable ? !!entry.on : true
            hasSwitch: !!entry.switchable
            onToggled: root.switched(key, !checked)

            draggable: false
            flush: true
            foldable: true
            sunken: true
            leading: Component {
              KitIconPlate {
                size: Theme.controlHeight
                name: row.entry.icon ?? ""
                tint: row.entry.off || (row.entry.switchable && !row.entry.on) ? Theme.muted : Theme.foreground0
              }
            }

            // built on the first unfold: most rows are never opened
            Item {
              id: body
              // an independent pane: its own sections box themselves, not into this list's
              readonly property bool kitUnboxed: true
              // ... and flat: hairlines between the rows, as in Live activities, no boxes
              readonly property bool kitFlat: true
              property bool built: false
              width: parent.width
              // the options' own grouper keeps a row inset below the last row, and the fold a gap of its own
              implicitHeight: loader.item ? Math.max(0, loader.item.implicitHeight - Theme.settingsRowInset) : 0
              height: implicitHeight
              Connections { target: row; function onUnfoldedChanged() { if (row.unfolded) body.built = true; } }

              Loader {
                id: loader
                width: parent.width
                active: body.built
                sourceComponent: root.options
                onLoaded: item.entryId = Qt.binding(() => row.key)
              }
            }
          }
        }

        KitGrouper {}
      }

      Item {
        readonly property bool kitUnboxed: true
        visible: root.matches.length === 0
        width: parent.width
        height: empty.height

        KitEmptyState {
          id: empty
          width: parent.width
          icon: "search"
          title: "No matches"
          hint: "Try a shorter search"
        }
      }

      KitGrouper {}
    }
  }
}
