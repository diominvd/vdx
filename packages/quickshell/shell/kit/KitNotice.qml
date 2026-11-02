import QtQuick
import qs.config

// A page's banner: what this page waits for, one line, and the button that fixes it
// ("The hub belongs to the Island style"; "Use Island"). The first thing on the page;
// it is not a row (the group boxes leave it standing). The page-wide kind of
// KitRow's `needs`.
Rectangle {
  id: root

  property string title: ""
  property string text: ""
  property string action: ""
  property string icon: "info"
  property color tone: Theme.clear
  property bool shown: true
  property bool kitUnboxed: true               // KitGrouper: stands on the page

  signal acted()

  visible: shown || opacity > 0
  width: parent ? parent.width : 0
  implicitHeight: body.implicitHeight + 2 * Theme.gapLoose
  height: shown ? implicitHeight : 0
  opacity: shown ? 1 : 0
  clip: true
  radius: Theme.radiusCard
  color: root.tone === Theme.clear ? Theme.clear : Theme.mix(Theme.background0, root.tone, 0.06)
  border.width: Theme.frameWidth
  border.color: root.tone === Theme.clear ? Theme.controlLineHover : Theme.mix(Theme.background0, root.tone, 0.34)

  Behavior on height { enabled: Motion.controls; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
  Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }

  KitIcon {
    id: mark
    anchors { left: parent.left; leftMargin: Theme.gapLoose; top: parent.top; topMargin: Theme.gapLoose + 1 }
    name: root.icon
    size: 16
    tint: root.tone === Theme.clear ? Theme.foreground2 : root.tone
  }

  Column {
    id: body
    anchors { left: mark.right; leftMargin: Theme.gapMedium; right: button.visible ? button.left : parent.right; rightMargin: Theme.gapLoose; top: parent.top; topMargin: Theme.gapLoose }
    spacing: Theme.gapTight
    KitText { width: parent.width; text: root.title; font.weight: Font.Medium; wrapMode: Text.WordWrap }
    KitText { width: parent.width; visible: root.text !== ""; text: root.text; color: Theme.muted; font.pixelSize: Theme.fontSize - 1; wrapMode: Text.WordWrap }
  }

  KitButton {
    id: button
    visible: root.action !== ""
    anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
    text: root.action
    onClicked: root.acted()
  }
}
