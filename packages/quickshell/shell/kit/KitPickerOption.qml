import QtQuick
import qs.config

// One option of a KitPickerHead: a short caption, right-aligned in a column shared by all the
// options, and its control (the child) on the same line, from one left edge. A hint is not
// written: the caption says it.
Item {
  id: root

  property string label: ""
  property bool dimmed: false
  // from the head: captions start at the pane's left edge, controls at one common x
  readonly property real captionWidth: parent && parent.parent && parent.parent.captionWidth ? parent.parent.captionWidth : 80
  readonly property real controlX: captionWidth + Theme.gapGroup
  default property alias control: slot.data

  width: parent ? parent.width : 0
  height: Math.max(Theme.controlHeight, slot.childrenRect.height)

  KitText {
    width: root.captionWidth
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: Theme.foreground2
    elide: Text.ElideRight
    opacity: root.dimmed ? 0.5 : 1
  }

  Item {
    id: slot
    x: root.controlX
    width: root.width - x
    height: parent.height
    // a control that is shorter than the line (a switch) stands in its middle
    function centre() { for (let i = 0; i < children.length; i++) { const c = children[i]; if (c.height < height) c.y = (height - c.height) / 2; } }
    onChildrenChanged: centre()
    onHeightChanged: centre()
    Component.onCompleted: centre()
  }
}
