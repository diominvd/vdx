import QtQuick
import qs.config
import qs.kit

// The restore guide, folded under the snapshots: the same text `backup guide`
// prints. Numbered headings stand out, indented lines are commands and sit in
// the foreground.
Column {
  id: root

  readonly property var bs: BackupService
  property bool open: false
  spacing: Theme.gapTight

  KitLabel { text: "IF THE COMPUTER IS GONE"; value: "ALSO: backup guide" }

  KitRow {
    label: "Getting everything back"
    hint: "Step by step, for an empty computer"

    KitButton {
      width: Theme.buttonWidth
      anchors.verticalCenter: parent.verticalCenter
      icon: root.open ? "chevron-up" : "chevron-down"
      text: root.open ? "Hide" : "Show"
      onClicked: root.open = !root.open
    }
  }

  Column {
    id: lines
    property bool kitUnboxed: true
    width: root.width
    spacing: Theme.gapTight

  Repeater {
    model: root.open ? root.bs.guideLines : []

    KitText {
      required property string modelData
      required property int index

      width: lines.width
      wrapMode: Text.WordWrap
      text: modelData === "" ? " " : modelData
      font.pixelSize: Theme.fontSize - 1
      font.weight: /^\d\./.test(modelData) ? Font.ExtraBold : Font.Normal
      color: /^\d\./.test(modelData) ? Theme.foreground0 : modelData.startsWith("   ") ? Theme.foreground1 : Theme.muted
      topPadding: /^\d\./.test(modelData) && index > 0 ? Theme.gapSmall : 0
    }
  }
  }

  KitGrouper {}
}
