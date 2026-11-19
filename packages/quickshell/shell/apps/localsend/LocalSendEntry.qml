import QtQuick
import qs.apps.files
import qs.config
import qs.kit

// Shared file, device and transfer row; actions stay in the trailing slot.
Item {
  id: root
  property string title: ""
  property string detail: ""
  property string icon: "file"
  property color tone: Theme.foreground2
  property bool selectable: false
  property bool selected: false
  property bool checkable: false
  property bool available: true
  property color detailColor: Theme.muted
  default property alias actions: trailing.data
  signal clicked()

  width: parent ? parent.width : 0
  implicitHeight: Math.max(Theme.rowHeight, copy.implicitHeight + 2 * Theme.gapMedium, trailing.implicitHeight + 2 * Theme.gapHair)
  activeFocusOnTab: selectable && available
  Accessible.role: checkable ? Accessible.CheckBox : selectable ? Accessible.Button : Accessible.ListItem
  Accessible.name: title
  Accessible.description: detail
  Accessible.checked: selected
  Accessible.onPressAction: if (selectable && available) clicked()
  Keys.onReturnPressed: if (selectable && available) clicked()
  Keys.onSpacePressed: if (selectable && available) clicked()

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusControl
    color: root.selected && !root.checkable ? Theme.pickFill : area.containsMouse && root.selectable ? Theme.controlHover : Theme.clear
    border.width: root.activeFocus ? Theme.focusWidth : 0
    border.color: Theme.focusRing
    Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick; easing.type: Motion.tint } }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    enabled: root.selectable && root.available
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }

  Item {
    id: leading
    anchors { left: parent.left; leftMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
    width: Theme.controlHeight
    height: Theme.controlHeight
    opacity: root.available ? 1 : 0.45
    KitIconTile {
      anchors.centerIn: parent
      visible: !root.checkable
      name: root.icon
      active: root.selected
      hovered: area.containsMouse
      tint: root.selected ? Theme.selectedText : root.tone
    }
    FilesCheck {
      anchors.centerIn: parent
      visible: root.checkable
      checked: root.selected
      onToggled: root.clicked()
    }
  }

  Column {
    id: copy
    anchors { left: leading.right; leftMargin: Theme.gapMedium; right: trailing.left; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
    spacing: Theme.gapTight
    opacity: root.available ? 1 : 0.45
    KitText {
      width: parent.width
      text: root.title
      elide: Text.ElideMiddle
      font.weight: root.selected ? Theme.pickWeight : Font.Normal
      color: root.selected && !root.checkable ? Theme.selectedText : Theme.foreground0
    }
    KitText {
      width: parent.width
      visible: root.detail !== ""
      text: root.detail
      elide: Text.ElideRight
      font.pixelSize: Theme.fontSize - 2
      color: root.selected && !root.checkable ? Theme.selectedText : root.detailColor
    }
  }

  Row {
    id: trailing
    anchors { right: parent.right; rightMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
    spacing: Theme.gapSmall
  }
}
