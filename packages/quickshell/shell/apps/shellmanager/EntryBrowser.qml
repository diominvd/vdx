import QtQuick
import QtQuick.Controls as Controls
import qs.config
import qs.kit

// The page of Apps and Bar modules, in two views over the whole pane.
// Index: a search, then a grid of EntryCards per section (the section's name and count
// above). Typing filters, Enter opens the first match.
// Entry: its heading (icon, name, about, state; `trailing` on the right: keys, Reset),
// then its options (the children, a Column's content that ends with its own KitGrouper).
// The way back is the crumb in the window's header (ShellManager reads the page's
// `backLabel`, `here` and `back()`).
// Entries: {id, label, icon, about, state (a card's few words), note (the heading's, if it
// says it otherwise: "" for none), ok (the state is good news), off (not installed: muted),
// section (a key of `sections`)}. `selected` "" is the index; picked(id)
// asks the page to open one ("" goes back). Each view scrolls on its own.
Item {
  id: root

  property var model: []
  property var sections: []          // [{key, label}] in their order
  property string selected: ""
  property string searchHint: "Search…"
  default property alias content: body.data
  property alias trailing: trailingRow.data
  signal picked(string id)

  property string query: ""
  readonly property string needle: query.trim().toLowerCase()
  readonly property var entry: model.find(e => e.id === selected) ?? null

  // the entries in the order the index shows them: section by section, then by name
  readonly property var ordered: {
    const out = [];
    for (const s of sections)
      for (const e of model.filter(e => e.section === s.key).sort((a, b) => a.label.localeCompare(b.label)))
        out.push(e);
    return out;
  }
  readonly property var matches: ordered.filter(e => e.label.toLowerCase().includes(needle))

  // ---- index ----
  Flickable {
    id: index
    visible: root.entry === null
    anchors.fill: parent
    Controls.ScrollBar.vertical: KitScrollBar {}
    contentHeight: grid.implicitHeight
    bottomMargin: Theme.windowPadding  // the window's edge clips, not a line above it
    interactive: contentHeight + bottomMargin > height   // the margin scrolls too
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: grid
      // the pane reaches the window's edge (the scrollbar sits there); its content ends at the header's line
      width: index.width - Theme.windowPadding
      spacing: Theme.gapGroup

      // the cards per row: as many as fit at their least width, sharing the row
      readonly property int columns: Math.max(1, Math.floor((width + Theme.gapMedium) / (Theme.sideWidth + Theme.gapMedium)))
      readonly property real cardWidth: (width - (columns - 1) * Theme.gapMedium) / columns

      KitInput {
        id: search
        width: parent.width
        placeholder: root.searchHint
        icon: "search"
        text: root.query
        onTextEdited: root.query = text
        onAccepted: if (root.matches.length > 0) root.picked(root.matches[0].id)
      }

      Repeater {
        model: root.sections

        Column {
          id: section
          required property var modelData
          readonly property var entries: root.matches.filter(e => e.section === modelData.key)
          visible: entries.length > 0
          width: grid.width
          spacing: Theme.gapMedium

          KitLabel {
            text: section.modelData.label
            value: String(section.entries.length)
          }

          Flow {
            width: parent.width
            spacing: Theme.gapMedium

            Repeater {
              model: section.entries

              EntryCard {
                required property var modelData
                entry: modelData
                width: grid.cardWidth
                onClicked: root.picked(modelData.id)
              }
            }
          }
        }
      }

      KitEmptyState {
        visible: root.matches.length === 0
        width: parent.width
        icon: "search"
        title: "No matches"
        hint: "Try a shorter search"
      }
    }
  }

  // ---- one entry ----
  Flickable {
    id: pane
    visible: root.entry !== null
    anchors.fill: parent
    Controls.ScrollBar.vertical: KitScrollBar {}
    contentHeight: details.implicitHeight
    bottomMargin: Theme.windowPadding
    interactive: contentHeight + bottomMargin > height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: details
      width: pane.width - Theme.windowPadding
      spacing: Theme.sectionGap
      opacity: paneIn.shown

      // heading: icon, name, about and state; `trailing` (keys, Reset) on the right
      Item {
        readonly property Item kitCaption: heading
        readonly property bool kitUnboxed: true
        width: parent.width
        height: Math.max(heading.implicitHeight, trailingRow.height)

        Row {
          id: heading
          anchors { left: parent.left; right: trailingRow.left; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
          spacing: Theme.gapWide

          KitIconPlate {
            id: plate
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.rowHeight + Theme.gapMedium
            name: root.entry?.icon ?? ""
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: heading.width - plate.width - heading.spacing
            spacing: Theme.gapTight

            KitText {
              width: parent.width
              elide: Text.ElideRight
              text: root.entry?.label ?? ""
              font.pixelSize: Theme.fontSize + 2
              font.weight: Font.Medium
            }

            KitText {
              width: parent.width
              visible: text !== ""
              text: root.entry?.about ?? ""
              elide: Text.ElideRight
              color: Theme.muted
              font.pixelSize: Theme.fontSize - 1
            }

            KitText {
              width: parent.width
              visible: text !== ""
              text: root.entry ? root.entry.note ?? root.entry.state ?? "" : ""
              elide: Text.ElideRight
              color: root.entry?.ok ? Theme.green : Theme.muted
              font.pixelSize: Theme.fontSize - 1
            }
          }
        }

        Row {
          id: trailingRow
          anchors { right: parent.right; verticalCenter: parent.verticalCenter }
          spacing: Theme.gapSmall
        }
      }

      KitLine { sectionBreak: false }

      Column {
        id: body
        width: parent.width
        spacing: Theme.sectionGap
      }

      KitGrouper {}
    }
  }

  // an entry fades in like a page does (ShellManager's pageIn)
  QtObject { id: paneIn; property real shown: 1 }
  NumberAnimation { id: paneAnim; target: paneIn; property: "shown"; from: 0; to: 1; duration: Motion.ms(240); easing.type: Motion.easing }

  onSelectedChanged: {
    pane.contentY = 0;
    if (selected === "") Qt.callLater(() => search.input.forceActiveFocus());
    if (Motion.pages) paneAnim.restart();
  }
}
