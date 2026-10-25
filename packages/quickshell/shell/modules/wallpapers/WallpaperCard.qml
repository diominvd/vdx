import QtQuick
import Quickshell.Widgets
import qs.config
import qs.kit

// One picture in the Wallpapers cards: a 16:9 crop. In use: a check in the
// corner; picked (arrows, wheel): a bright frame.
ClippingRectangle {
  id: root

  required property string path
  property bool inUse: false
  property bool picked: false

  signal clicked()

  radius: Theme.radiusCard
  color: Theme.background1
  border.width: area.activeFocus ? Theme.focusRingWidth : picked ? 2 : Theme.frameWidth
  border.color: area.activeFocus ? Theme.focusRing : picked ? Theme.foreground0 : area.containsMouse ? Theme.foreground2 : Theme.background2
  Behavior on border.color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

  Image {
    anchors { fill: parent; margins: root.border.width }
    source: root.path === "" ? "" : "file://" + root.path
    sourceSize: Qt.size(272, 153)
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
  }

  // the check sits on a background square so it reads on any picture
  Rectangle {
    radius: Theme.pill(height)
    visible: root.inUse
    anchors { right: parent.right; top: parent.top; margins: Theme.gapSmall }
    width: 18
    height: 18
    color: Theme.background0

    KitIcon { anchors.centerIn: parent; name: "check"; size: 12; tint: Theme.green }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    activeFocusOnTab: root.picked
    Accessible.role: Accessible.Button
    Accessible.name: root.path.split("/").pop()
    Accessible.description: root.inUse ? "Currently applied wallpaper" : root.picked ? "Selected wallpaper" : "Preview wallpaper"
    cursorShape: Qt.PointingHandCursor
    onClicked: { forceActiveFocus(); root.clicked(); }
    Keys.onPressed: event => {
      if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
      if (!event.isAutoRepeat) root.clicked();
      event.accepted = true;
    }
  }
}
