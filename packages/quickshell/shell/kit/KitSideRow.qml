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
  height: 28
  radius: Theme.radiusControl
  color: current || area.pressed || area.keyboardPressed ? Theme.background3 : area.containsMouse ? Theme.background2 : Theme.clear
  border.width: area.activeFocus ? 2 : 0
  border.color: Theme.foreground0
  Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

  KitIcon {
    id: glyph
    anchors { left: parent.left; leftMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
    name: root.icon
    size: Theme.iconSmall
    tint: root.current ? Theme.foreground0 : Theme.foreground2
  }

  KitText {
    anchors { left: glyph.right; leftMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
    width: Math.max(0, parent.width - glyph.x - glyph.width - Theme.gapMedium - hintText.width - Theme.gapSmall - hintText.anchors.rightMargin)
    text: root.text
    elide: Text.ElideRight
    color: root.current ? Theme.foreground0 : Theme.foreground2
    font.weight: root.current ? Font.ExtraBold : Font.DemiBold
  }

  KitText {
    id: hintText
    anchors { right: parent.right; rightMargin: Theme.gapLoose + actionButton.width * (root.action !== "" ? 1 : 0); verticalCenter: parent.verticalCenter }
    width: visible ? Math.min(implicitWidth, Math.max(0, (parent.width - glyph.x - glyph.width - Theme.gapMedium - anchors.rightMargin) * 0.35)) : 0
    visible: root.hint !== ""
    text: root.hint
    elide: Text.ElideRight
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 2
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    activeFocusOnTab: true
    property bool keyboardPressed: false
    onActiveFocusChanged: if (!activeFocus) keyboardPressed = false
    Accessible.role: Accessible.Button
    Accessible.name: root.text
    Accessible.description: root.hint
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
      else { forceActiveFocus(); root.clicked(); }
    }
    Keys.onPressed: event => {
      if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
      if (!event.isAutoRepeat) {
        keyboardPressed = true;
        root.clicked();
      }
      event.accepted = true;
    }
    Keys.onReleased: event => {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        keyboardPressed = false;
        event.accepted = true;
      }
    }
  }

  MouseArea {
    id: actionButton
    visible: root.action !== ""
    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
    width: height
    hoverEnabled: true
    activeFocusOnTab: visible
    property bool keyboardPressed: false
    onActiveFocusChanged: if (!activeFocus) keyboardPressed = false
    Accessible.role: Accessible.Button
    Accessible.name: "Action for " + root.text
    Accessible.description: root.action
    cursorShape: visible ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: { forceActiveFocus(); root.actioned(); }
    Keys.onPressed: event => {
      if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
      if (!event.isAutoRepeat) {
        keyboardPressed = true;
        root.actioned();
      }
      event.accepted = true;
    }
    Keys.onReleased: event => {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        keyboardPressed = false;
        event.accepted = true;
      }
    }

    Rectangle {
      anchors.fill: parent
      visible: actionButton.activeFocus || actionButton.containsMouse || actionButton.pressed || actionButton.keyboardPressed
      radius: Theme.radiusControl
      color: actionButton.keyboardPressed || actionButton.pressed ? Theme.background3 : actionButton.containsMouse ? Theme.background2 : Theme.clear
      border.width: actionButton.activeFocus ? 2 : 0
      border.color: Theme.foreground0
    }

    KitIcon {
      anchors.centerIn: parent
      name: root.action
      size: Theme.iconSmall
      tint: actionButton.containsMouse ? Theme.foreground0 : Theme.foreground2
    }
  }
}
