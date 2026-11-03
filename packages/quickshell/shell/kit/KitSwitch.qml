import QtQuick
import qs.config

// Rectangular switch with a square knob (round corners: a pill and a disc):
// off, an outlined dark track with a grey knob on the left; on, a light track
// with a dark knob on the right. With the accent on
// Switches (Appearance › Colours), an on switch fills with the accent,
// a gradient from its first colour to its second.
// Material (Appearance › Controls): the Material 3 switch — off, an outlined
// track with a small grey handle; on, a filled track with a large handle and a
// check in it; the handle grows under the pointer and while pressed.
Rectangle {
  id: root

  property bool checked: false
  property bool disabled: false
  property color trackColor: Theme.background3   // darker on a filled (selected) row
  readonly property bool accented: checked && Theme.accentOn("switches")
  readonly property bool m3: Theme.material
  readonly property bool hovered: area.containsMouse && !disabled
  property string accessibleName: {
    for (let p = parent; p; p = p.parent) if (typeof p.label === "string" && p.label) return p.label;
    return "Toggle";
  }
  activeFocusOnTab: true
  enabled: !disabled
  Accessible.role: Accessible.CheckBox
  Accessible.name: accessibleName
  Accessible.checkable: true
  Accessible.checked: checked
  Accessible.onToggleAction: if (!disabled) toggled()
  Keys.onSpacePressed: event => { if (!disabled && !event.isAutoRepeat) toggled(); }
  Keys.onReturnPressed: event => { if (!disabled && !event.isAutoRepeat) toggled(); }

  signal toggled()
  property bool boxed: false
  Component.onCompleted: boxed = Theme.boxed(parent)

  implicitWidth: m3 ? 44 : 38
  implicitHeight: m3 ? 26 : 20
  radius: Theme.pill(height)
  border.width: m3 ? (checked ? 0 : 2) : checked ? 0 : Theme.frameWidth
  border.color: m3 ? Theme.gray : hovered ? Theme.controlLineHover : Theme.controlLine
  opacity: disabled ? 0.4 : 1

  gradient: Gradient {
    orientation: Gradient.Horizontal
    GradientStop {
      position: 0
      color: root.accented ? Theme.accent : root.checked ? Theme.foreground0 : root.m3 ? root.trackColor : Theme.fillOn(root.boxed)
      Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
    }
    GradientStop {
      position: 1
      color: root.accented ? Theme.accent : root.checked ? Theme.foreground0 : root.m3 ? root.trackColor : Theme.fillOn(root.boxed)
      Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
    }
  }

  KitGlow {
    z: -1
    anchors.fill: parent
    target: "switches"
    lit: root.checked && !root.disabled
    tint: root.accented ? Theme.accent : Theme.foreground0
    radius: root.radius
  }

  Rectangle {
    anchors { fill: parent; margins: -4 }
    radius: Theme.radiusFor(height)
    color: Theme.clear
    border.width: Theme.focusWidth
    border.color: Theme.focusRing
    visible: root.activeFocus
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

    property int size: !root.m3 ? 14
                              : area.pressed && !root.disabled ? root.height - 2
                              : root.checked || root.hovered ? root.height - 6 : root.height - 10
    readonly property int edge: root.m3 ? (root.height - size) / 2 : 3

    width: size
    height: size
    radius: Theme.pill(height)
    anchors.verticalCenter: parent.verticalCenter
    x: root.m3 ? (root.checked ? root.width - root.height / 2 : root.height / 2) - size / 2
               : root.checked ? root.width - width - edge : edge
    color: root.accented ? Theme.inkOn(Theme.accent)
         : root.m3 ? (root.checked ? Theme.background0 : root.hovered ? Theme.foreground2 : Theme.gray)
         : root.checked ? Theme.background0 : root.hovered ? Theme.foreground2 : Theme.gray

    Behavior on x { enabled: Motion.controls; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
    Behavior on size { enabled: Motion.controls; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
    Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

    KitIcon {
      anchors.centerIn: parent
      visible: root.m3 && root.checked
      name: "check"
      tint: root.accented ? Theme.inkOn(knob.color) : Theme.foreground0
      size: 12
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
    onClicked: if (!root.disabled) root.toggled()
  }
}
