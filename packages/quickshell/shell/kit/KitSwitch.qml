import QtQuick
import qs.config

// Rectangular switch with a square knob (round corners: a pill and a disc):
// dim on the left when off, bright on the right when on. With the accent on
// Switches (Appearance › Accent), an on switch fills with the accent,
// a gradient from its first colour to its second.
// Material (Appearance › Controls): the Material 3 switch — off, an outlined
// track with a small grey handle; on, a filled track with a large handle and a
// check in it; the handle grows under the pointer and while pressed.
Rectangle {
  id: root

  property bool checked: false
  property bool disabled: false
  property string accessibleName: ""

  // Mirror the custom disabled state into Qt so focus and accessibility clients
  // treat an unavailable switch as disabled, not merely visually dimmed.
  enabled: !disabled
  property color trackColor: Theme.background3   // darker on a filled (selected) row
  readonly property bool accented: checked && Theme.accentOn("switches")
  readonly property bool m3: Theme.material
  // Match pointer feedback for keyboard input and ignore held-key auto-repeat.
  property bool keyboardPressed: false
  readonly property bool hovered: area.containsMouse && !disabled
  readonly property bool pressed: (area.pressed || keyboardPressed) && !disabled
  onActiveFocusChanged: if (!activeFocus) keyboardPressed = false
  onDisabledChanged: if (disabled) keyboardPressed = false

  signal toggled()

  activeFocusOnTab: !disabled
  Accessible.role: Accessible.CheckBox
  Accessible.name: accessibleName !== "" ? accessibleName : qsTr("Switch")
  Accessible.checked: checked

  Keys.onPressed: event => {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (!event.isAutoRepeat) {
        keyboardPressed = !disabled;
        if (!disabled) toggled();
      }
      event.accepted = true;
    }
  }
  Keys.onReleased: event => {
    if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      keyboardPressed = false;
      event.accepted = true;
    }
  }

  implicitWidth: m3 ? 44 : 36
  implicitHeight: m3 ? 24 : 20
  radius: Theme.pill(height)
  border.width: activeFocus ? Theme.focusRingWidth : m3 ? (checked ? 0 : 2) : hovered ? Theme.frameWidth : 0
  border.color: activeFocus ? Theme.focusRing : m3 ? Theme.gray : hovered ? Theme.foreground2 : Theme.gray
  opacity: disabled ? 0.4 : 1

  gradient: Gradient {
    orientation: Gradient.Horizontal
    GradientStop {
      position: 0
      color: root.accented ? Theme.accent : root.m3 && root.checked ? Theme.foreground0 : root.trackColor
      Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
    }
    GradientStop {
      position: 1
      color: root.accented ? Theme.accentEnd : root.m3 && root.checked ? Theme.foreground0 : root.trackColor
      Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
    }
  }

  // material: the hover halo round the handle
  Rectangle {
    visible: root.m3
    anchors.centerIn: knob
    width: root.height + 8
    height: width
    radius: Theme.pill(height)
    color: root.checked ? Theme.foreground0 : Theme.gray
    opacity: root.hovered ? 0.16 : 0
    Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
  }

  Rectangle {
    id: knob

    property int size: !root.m3 ? (root.pressed ? 16 : 14)
                              : root.pressed ? root.height - 2
                              : root.checked || root.hovered ? root.height - 6 : root.height - 10
    readonly property int edge: root.m3 ? (root.height - size) / 2 : 3

    width: size
    height: size
    radius: Theme.pill(height)
    anchors.verticalCenter: parent.verticalCenter
    x: root.m3 ? (root.checked ? root.width - root.height / 2 : root.height / 2) - size / 2
               : root.checked ? root.width - width - edge : edge
    color: root.accented ? Theme.background0
         : root.m3 ? (root.checked ? Theme.background0 : root.hovered ? Theme.foreground2 : Theme.gray)
         : root.checked ? Theme.foreground0 : Theme.gray

    Behavior on x { enabled: Motion.controls; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
    Behavior on size { enabled: Motion.controls; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
    Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

    KitIcon {
      anchors.centerIn: parent
      visible: root.m3 && root.checked
      name: "check"
      tint: root.accented ? Theme.accent : Theme.foreground0
      size: 12
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
    onClicked: {
      if (!root.disabled) {
        root.forceActiveFocus();
        root.toggled();
      }
    }
  }
}
