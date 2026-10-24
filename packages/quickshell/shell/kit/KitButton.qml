import QtQuick
import qs.config

// Outlined button: an optional icon and a label. `selected` fills it in the
// raised tone with a lighter frame and bold text (one of a group of choices).
// Material: a tonal pill, no frame. Keyboard and assistive-technology support
// lives here so every screen gets the same behavior.
Rectangle {
  id: root

  property string icon: ""               // kit/icons name
  property color iconTint: Theme.foreground0
  property string text: ""
  // Override this for icon-only buttons; it is exposed to accessibility APIs.
  property string accessibleName: text
  readonly property string resolvedAccessibleName: accessibleName !== "" ? accessibleName
    : ({
        "refresh": "Refresh",
        "x": "Close",
        "arrow-left": "Back",
        "arrow-right": "Forward",
        "play": "Play",
        "pause": "Pause",
        "skip-back": "Previous track",
        "skip-forward": "Next track",
        "volume": "Volume",
        "volume-x": "Mute",
        "search": "Search",
        "plus": "Add",
        "trash": "Delete",
        "more": "More options",
        "chevron-down": "Expand",
        "chevron-right": "Open"
      }[icon] ?? icon.replace("-", " "))
  property bool selected: false
  property bool busy: false
  property bool disabled: false

  // Keep Qt's native enabled/accessibility state in sync with the visual state.
  // Busy buttons remain enabled/focusable so their "Please wait" description
  // can still be announced, but activation handlers below ignore input.
  enabled: !disabled

  // Keep keyboard activation visually responsive, just like pointer/touch.
  // Ignore auto-repeat so holding Enter/Space cannot fire an action repeatedly.
  property bool keyboardPressed: false
  readonly property bool hovered: area.containsMouse && !disabled && !busy
  readonly property bool pressed: (area.pressed || keyboardPressed) && !disabled && !busy
  onActiveFocusChanged: if (!activeFocus) keyboardPressed = false
  onDisabledChanged: if (disabled) keyboardPressed = false
  onBusyChanged: if (busy) keyboardPressed = false

  signal clicked()

  activeFocusOnTab: !disabled
  Accessible.role: Accessible.Button
  Accessible.name: resolvedAccessibleName
  Accessible.description: busy ? qsTr("Please wait") : selected ? qsTr("Selected") : ""

  // an icon alone is a square of the control height
  implicitWidth: text !== "" ? content.implicitWidth + (Theme.material ? 32 : 24) : Theme.controlHeight
  implicitHeight: Theme.controlHeight
  radius: Theme.radiusControl
  // set once: whether it sits in a Settings box (a walk up, not a binding)
  property bool boxed: false
  Component.onCompleted: boxed = Theme.boxed(parent)
  color: pressed ? (selected ? Theme.background2 : Theme.background3) : selected ? Theme.background3 : hovered ? Theme.hoverOn(boxed) : Theme.fillOn(boxed)
  border.width: activeFocus ? Math.max(2, Theme.frameWidth) : Theme.frameWidth
  border.color: activeFocus ? Theme.foreground0
    : pressed || selected || hovered ? Theme.foreground2 : Theme.gray
  opacity: disabled ? 0.4 : 1

  Keys.onPressed: event => {
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      if (!event.isAutoRepeat) {
        keyboardPressed = !disabled && !busy;
        if (!disabled && !busy) clicked();
      }
      event.accepted = true;
    }
  }
  Keys.onReleased: event => {
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
      keyboardPressed = false;
      event.accepted = true;
    }
  }

  Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
  Behavior on border.color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Theme.gapMedium

    KitIcon {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.icon !== "" && !root.busy
      name: root.icon
      tint: root.iconTint
      size: Theme.fontSize + 1
    }

    KitSpinner {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.busy
    }

    KitText {
      visible: root.text !== ""
      // Explicitly budget for the icon/spinner and button padding. Long labels
      // elide inside narrow buttons instead of painting beyond the control.
      width: Math.max(0, root.width - (root.busy || root.icon !== "" ? Theme.fontSize + 1 + content.spacing : 0) - (Theme.material ? 32 : 24))
      elide: Text.ElideRight
      text: root.text
      color: root.selected ? Theme.accentFor("choices", Theme.foreground0) : Theme.foreground0
      font.weight: root.selected ? Font.ExtraBold : Font.DemiBold
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.disabled || root.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
    onClicked: {
      if (!root.disabled && !root.busy) {
        root.forceActiveFocus();
        root.clicked();
      }
    }
  }
}
