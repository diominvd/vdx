import QtQuick
import qs.config
import qs.kit

// A row of an app's sidebar (Files, Music): an icon, a name and a hint at the
// right; the current place is filled. A left click opens it, a right click
// reports where it was (scene coordinates) so the app can open its menu. With
// `draggable`, a left drag reports the pointer (dragged while it moves, dropped
// on release) so the sidebar can reorder its rows. `action`: an icon button at the end of the row
// (Files: a device's mount or unmount); its click is `actioned`, not `clicked`.
Rectangle {
  id: root

  property string icon: ""
  property string text: ""
  property string hint: ""
  property bool current: false
  property bool draggable: false
  property bool moved: false           // the press became a drag: no click
  property real pressY: 0
  property string action: ""

  signal clicked()
  signal rightClicked(point at)
  signal dragged(real sceneY)
  signal dropped(real sceneY)
  signal actioned()

  width: parent ? parent.width : 0
  height: Theme.navigationHeight
  radius: Theme.radiusControl
  color: current ? Theme.selectedFill : area.containsMouse ? Theme.controlHover : Theme.clear
  Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

  // the icon is the Shell Manager's (NavRow): bare or framed by Appearance › Icons, or off
  KitIconTile {
    id: glyph
    visible: ShellSettings.menuIcons
    anchors { left: parent.left; leftMargin: ShellSettings.iconTiles ? Theme.gapSmall : Theme.gapLoose; verticalCenter: parent.verticalCenter }
    name: root.icon
    active: root.current
    hovered: area.containsMouse
    tint: root.current ? Theme.selectedText : Theme.foreground2
    glyph: 16
  }

  KitText {
    anchors { left: ShellSettings.menuIcons ? glyph.right : parent.left; leftMargin: Theme.gapLoose; right: hintText.left; rightMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
    text: root.text
    elide: Text.ElideRight
    color: root.current ? Theme.selectedText : Theme.foreground2
    font.weight: root.current ? Theme.pickWeight : Font.Normal
  }

  KitText {
    id: hintText
    anchors { right: parent.right; rightMargin: Theme.gapLoose + actionButton.width * (root.action !== "" ? 1 : 0); verticalCenter: parent.verticalCenter }
    visible: root.hint !== ""
    text: root.hint
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 2
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onPressed: mouse => { root.moved = false; root.pressY = mouse.y; }
    onPositionChanged: mouse => {
      if (!pressed || !root.draggable || mouse.buttons !== Qt.LeftButton) return;
      if (!root.moved && Math.abs(mouse.y - root.pressY) > 6) root.moved = true;
      if (root.moved) root.dragged(root.mapToItem(null, mouse.x, mouse.y).y);
    }
    onReleased: mouse => { if (root.moved) root.dropped(root.mapToItem(null, mouse.x, mouse.y).y); }
    onClicked: mouse => {
      if (root.moved) return;
      if (mouse.button === Qt.RightButton) root.rightClicked(root.mapToItem(null, mouse.x, mouse.y));
      else root.clicked();
    }
  }

  MouseArea {
    id: actionButton
    visible: root.action !== ""
    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
    width: height
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.actioned()

    KitIcon {
      anchors.centerIn: parent
      name: root.action
      size: Theme.iconSmall
      tint: actionButton.containsMouse ? Theme.foreground0 : Theme.foreground2
    }
  }
}
