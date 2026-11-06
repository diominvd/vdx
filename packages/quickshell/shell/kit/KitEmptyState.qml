import QtQuick
import qs.config

// Compact explanation for an empty pane, with a next step instead of a blank box.
Item {
  id: root
  property string icon: "search"
  property string title: "Nothing here"
  property string hint: ""
  readonly property bool kitUnboxed: true
  width: parent ? parent.width : 0
  implicitHeight: Math.max(56, copy.implicitHeight + 2 * Theme.gapWide)
  KitIcon {
    id: glyph
    anchors { left: parent.left; leftMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
    name: root.icon
    size: 20
    tint: Theme.muted
  }
  Column {
    id: copy
    anchors { left: glyph.right; leftMargin: Theme.gapWide; right: parent.right; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
    spacing: Theme.gapHair
    KitText { width: parent.width; text: root.title; font.weight: Font.Medium; wrapMode: Text.WordWrap }
    KitText { width: parent.width; visible: text !== ""; text: root.hint; color: Theme.hint; font.pixelSize: Theme.fontSize - 1; wrapMode: Text.WordWrap }
  }
}
