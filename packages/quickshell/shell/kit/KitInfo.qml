import QtQuick
import qs.config

// "Label            value" line: the label dim on the left, the value on the
// right; the value elides before it reaches the label.
Item {
  id: root

  property string label: ""
  property string value: ""
  property color valueColor: Theme.foreground0

  width: parent ? parent.width : 0
  implicitHeight: valueText.implicitHeight

  KitText {
    id: labelText
    width: Math.min(implicitWidth, Math.max(0, root.width - valueText.width - 16))
    text: root.label
    color: Theme.foreground2
    elide: Text.ElideRight
    font.pixelSize: Theme.fontSize - 1
  }

  TextMetrics { id: metrics; font: valueText.font; text: root.value }

  KitText {
    id: valueText
    anchors.right: parent.right
    width: Math.min(Math.ceil(metrics.advanceWidth) + 1, Math.max(0, (root.width - 16) / 2))
    horizontalAlignment: Text.AlignRight
    text: root.value
    color: root.valueColor
    elide: Text.ElideRight
    font.pixelSize: Theme.fontSize - 1
  }
}
