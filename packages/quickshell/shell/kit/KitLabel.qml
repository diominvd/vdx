import QtQuick
import qs.config

// Section caption in small caps with an optional value on the right and, beside it,
// `about`: what the block does, in the tooltip of an info mark beside the caption.
Item {
  id: root

  readonly property bool isKitLabel: true   // KitGrouper: starts a group
  property string text: ""
  property string value: ""
  property color valueColor: Theme.muted
  property string about: ""
  // KitGrouper: what the caption gives back to a neighbour that is not boxed, so the gap to
  // the surface above and below it is the same as beside a box (whose edge lies padY out)
  property int trimTop: 0
  property int trimBottom: 0

  width: parent ? parent.width : 0
  implicitHeight: caption.implicitHeight - trimTop - trimBottom

  KitText {
    id: caption
    y: -root.trimTop
    text: root.text
    color: Theme.muted
    font.family: Theme.fontFamily
    font.pixelSize: Theme.sectionCaptionSize
    font.weight: Theme.fontWeight
    font.letterSpacing: Theme.sectionCaptionTracking
  }

  // what the block does: an info mark after the caption, the text in its tooltip
  KitTip {
    visible: root.about !== "" && root.value === ""
    anchors { left: caption.right; leftMargin: Theme.gapMedium; verticalCenter: caption.verticalCenter }
    size: Theme.fontSize - 1
    text: root.about
  }

  // a long value ends in … rather than running into the caption
  KitText {
    anchors { left: caption.right; leftMargin: Theme.gapWide; right: parent.right; verticalCenter: caption.verticalCenter }
    horizontalAlignment: Text.AlignRight
    elide: Text.ElideRight
    text: root.value
    color: root.valueColor
    font.family: Theme.fontFamily
    font.pixelSize: Theme.sectionCaptionSize
    font.weight: Theme.fontWeight
    font.letterSpacing: Theme.sectionCaptionTracking
  }
}
