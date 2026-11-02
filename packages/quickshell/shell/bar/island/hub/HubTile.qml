import QtQuick
import qs.config
import qs.kit

// One tile of the hub: a round icon (light when on, dark when off), the name, a
// detail line and a chevron. Compact (four to a row): the icon over the name.
// A click on the icon switches the thing; a click on the rest opens its popup.
Rectangle {
  id: root

  property string icon: ""
  property string title: ""
  property string detail: ""
  property bool on: false
  property bool compact: false
  property bool canOpen: true                  // a popup behind the tile: the chevron and the click

  signal toggled()
  signal opened()
  signal context()                             // a right click: the options of what it shows

  implicitHeight: compact ? 84 : 64
  radius: Theme.radiusCard
  color: area.containsMouse && !discArea.containsMouse ? Theme.controlHover : Theme.controlFill
  Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.normal; easing.type: Motion.easing } }
  border.width: Theme.frameWidth
  border.color: Theme.controlLine

  Rectangle {
    id: disc
    x: root.compact ? (parent.width - width) / 2 : Theme.gapMedium
    y: root.compact ? Theme.gapMedium : (parent.height - height) / 2
    width: root.compact ? 34 : 40
    height: width
    radius: Theme.pill(height)
    color: discArea.containsMouse
      ? (root.on ? Theme.accentFor("switches", Theme.foreground0) : Theme.background3)
      : root.on ? Theme.accentFor("switches", Theme.foreground1) : Theme.pickFill
    Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.normal; easing.type: Motion.easing } }
    scale: discArea.pressed ? 0.94 : 1
    Behavior on scale { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }

    KitIcon { anchors.centerIn: parent; name: root.icon; size: root.compact ? 16 : 18; tint: root.on ? Theme.inkOn(disc.color) : Theme.foreground2 }
    MouseArea { id: discArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled() }
  }

  // the tile's own click: the popup behind it, else the same as the icon's
  MouseArea {
    id: area
    z: -1
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.canOpen ? root.opened() : root.toggled()
  }

  TapHandler {
    acceptedButtons: Qt.RightButton
    enabled: ShellSettings.barRightSettings
    onTapped: root.context()
  }

  Column {
    visible: !root.compact
    anchors { left: disc.right; leftMargin: Theme.gapWide; right: chevron.left; rightMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
    spacing: 1
    KitText { width: parent.width; text: root.title; font.weight: Font.Medium; elide: Text.ElideRight }
    KitText { width: parent.width; text: root.detail; color: Theme.muted; font.pixelSize: Theme.fontSize - 2; elide: Text.ElideRight }
  }
  KitIcon {
    id: chevron
    visible: !root.compact && root.canOpen
    anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
    name: "chevron-right"
    size: 12
    tint: Theme.dim
  }

  KitText {
    visible: root.compact
    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.gapMedium }
    width: parent.width - 2 * Theme.gapSmall
    horizontalAlignment: Text.AlignHCenter
    text: root.title
    color: root.on ? Theme.foreground0 : Theme.foreground2
    font.pixelSize: Theme.fontSize - 2
    elide: Text.ElideRight
  }
}
