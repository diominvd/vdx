import QtQuick
import qs.config
import qs.kit

// Power off, reboot, lock, hibernate, suspend as tiles. Lock and suspend act
// at once; the rest ask once — the tile turns to "Confirm?" for 3 s.
// Keys: Left / Right, Enter.
Item {
  id: root

  property int current: 2                      // lock: the harmless one
  property string armed: ""

  signal done()

  function reset() { current = 2; armed = ""; }

  function press(i) {
    const a = IslandService.powerActions[i];
    current = i;
    if (a.confirm && armed !== a.id) { armed = a.id; disarm.restart(); return; }
    armed = "";
    root.done();
    IslandService.power(a.id);
  }

  function key(k) {
    const n = IslandService.powerActions.length;
    if (k === Qt.Key_Left) current = (current + n - 1) % n;
    else if (k === Qt.Key_Right || k === Qt.Key_Tab) current = (current + 1) % n;
    else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) press(current);
    if (IslandService.powerActions[current].id !== armed && k !== Qt.Key_Return && k !== Qt.Key_Enter) armed = "";
  }

  Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }

  Row {
    anchors.centerIn: parent
    spacing: Theme.gapSmall

    Repeater {
      model: IslandService.powerActions

      Rectangle {
        id: tile
        required property var modelData
        required property int index

        readonly property bool armed: root.armed === modelData.id
        readonly property bool lit: armed || area.containsMouse || root.current === index

        width: 78
        height: 64
        radius: Theme.radiusCard
        color: armed ? Theme.background3 : lit ? Theme.background2 : Theme.background1
        border.width: tile.activeFocus ? Math.max(Theme.focusRingWidth, Theme.frameWidth) : root.current === index ? Theme.frameWidth : 0
        border.color: tile.activeFocus ? Theme.focusRing : Theme.gray

        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: tile.armed ? "Confirm " + tile.modelData.label : tile.modelData.label
        Accessible.description: tile.modelData.confirm
          ? (tile.armed ? "Press again within three seconds to confirm" : "Requires a second activation to confirm")
          : "Activate " + tile.modelData.label
        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

        Column {
          anchors.centerIn: parent
          spacing: Theme.gapSmall

          KitIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: tile.modelData.icon
            size: 20
            solid: tile.armed
            tint: tile.armed && tile.modelData.id !== "lock" ? Theme.red : Theme.foreground0
          }
          KitText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.armed ? "Confirm?" : tile.modelData.label
            font.pixelSize: Theme.fontSize - 2
            font.weight: tile.armed ? Font.ExtraBold : Theme.fontWeight
            color: tile.lit ? Theme.foreground0 : Theme.foreground2
          }
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { tile.forceActiveFocus(); root.press(tile.index); }
        }

        Keys.onPressed: event => {
          if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
          if (!event.isAutoRepeat) {
            root.current = tile.index;
            root.press(tile.index);
          }
          event.accepted = true;
        }
      }
    }
  }
}
