import QtQuick
import qs.config

// The head of a KitPicker's right pane: the name, its status line, the actions (Apply …) on
// the right, and under them the page's options as a strip of KitPickerOption — one common left
// edge, short captions, no hints. The preview card stands under it and holds only the preview.
Column {
  id: root

  property string title: ""
  // one vocabulary on every page: `phase` — inuse (check, "In use"), preview ("Preview"), missing (download,
  // "Not installed"), busy (a spinner and `busyText`), loading (a spinner, "Loading…")
  property string phase: "preview"
  property string busyText: "Applying…"
  readonly property string status: phase === "inuse" ? "In use" : phase === "missing" ? "Not installed"
    : phase === "busy" ? busyText : phase === "loading" ? "Loading…" : "Preview"
  default property alias options: strip.data
  property alias actions: actionRow.data
  readonly property alias strip: strip
  // the grid every picker page shares: captions from x 0, one column of controls from `controlX`
  // (ten mono characters and a gap), everything ends at the pane's right edge
  readonly property real captionWidth: Math.ceil(captionMetrics.advanceWidth)
  readonly property real controlX: captionWidth + Theme.gapGroup
  TextMetrics { id: captionMetrics; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize; font.weight: Theme.fontWeight; text: "0000000000" }

  width: parent ? parent.width : 0
  spacing: Theme.gapWide

  Item {
    width: parent.width
    height: 44

    Column {
      anchors { left: parent.left; right: actionRow.left; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
      spacing: Theme.gapHair
      KitText { width: parent.width; text: root.title; font.weight: Font.Medium; font.pixelSize: Theme.fontSize + 5; elide: Text.ElideRight }
      Row {
        spacing: Theme.gapSmall
        KitIcon { visible: root.phase === "inuse" || root.phase === "missing"; anchors.verticalCenter: parent.verticalCenter; name: root.phase === "inuse" ? "check" : "download"; tint: root.phase === "inuse" ? Theme.green : Theme.foreground2; size: Theme.iconSmall }
        KitSpinner { visible: root.phase === "busy" || root.phase === "loading"; anchors.verticalCenter: parent.verticalCenter }
        KitText { text: root.status; color: Theme.muted; font.pixelSize: Theme.fontSize - 1 }
      }
    }

    Row {
      id: actionRow
      anchors { right: parent.right; verticalCenter: parent.verticalCenter }
      spacing: Theme.gapSmall
    }
  }

  Column {
    id: strip
    width: parent.width
    spacing: Theme.gapMedium
  }
}
