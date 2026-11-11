import QtQuick
import qs.config

// Compact explanation for an empty pane, with a next step instead of a blank box.
Item {
  id: root
  property string icon: "search"
  property string title: "Nothing here"
  property string hint: ""
  property bool centered: false
  readonly property bool kitUnboxed: true
  width: parent ? parent.width : 0
  implicitHeight: Math.max(56, copy.implicitHeight + 2 * Theme.gapWide)
  KitIcon {
    id: glyph
    anchors { left: parent.left; leftMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
    visible: root.icon !== "" && !root.centered
    name: root.icon
    size: 20
    tint: Theme.muted
  }
  Column {
    id: copy
    x: root.centered ? (parent.width - width) / 2 : glyph.x + glyph.width + Theme.gapWide
    width: root.centered ? parent.width - 2 * Theme.gapWide : parent.width - glyph.width - 3 * Theme.gapWide
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.gapHair
    KitText { width: parent.width; text: root.title; font.weight: Font.Medium; horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft; wrapMode: Text.WordWrap }
    KitText { width: parent.width; visible: text !== ""; text: root.hint; color: Theme.hint; font.pixelSize: Theme.fontSize - 1; horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft; wrapMode: Text.WordWrap }
  }
}
