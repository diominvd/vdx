import QtQuick
import qs.config
import qs.kit

// A caption over a group of an app's sidebar rows (Files, Music), as Shell Manager's: small, muted, in caps.
Item {
  id: root

  property string text: ""
  property int lead: 0              // the room above it: a group after the first

  width: parent ? parent.width : 0
  height: lead + caption.implicitHeight + Theme.gapHair

  KitText {
    id: caption
    anchors { left: parent.left; leftMargin: Theme.gapLoose; top: parent.top; topMargin: root.lead }
    text: root.text
    color: Theme.muted
    font.family: Theme.fontFamily
    font.pixelSize: Theme.sectionCaptionSize
    font.letterSpacing: Theme.sectionCaptionTracking
    font.weight: Font.DemiBold
  }
}
