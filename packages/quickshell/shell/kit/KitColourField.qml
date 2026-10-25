import QtQuick
import qs.config

// A colour in one box: a chip (click it for the picker), the hex (typed), and a
// chevron that opens the picker too. Typed text is handed over as `edited`; a
// valid hex is `accepted` at once when `live`, or on Enter. Left invalid, the
// field goes back to its last valid colour. The field follows `value` while it
// is not typed in.
Rectangle {
  id: root

  property string value: ""
  property string placeholder: "#32302f"
  property string accessibleName: "Hex colour"
  property bool live: false
  property bool open: false
  readonly property bool valid: /^#?[0-9a-fA-F]{6}$/.test(value.trim())
  readonly property string colour: valid ? "#" + value.trim().replace(/^#/, "").toLowerCase() : ""
  property string saved: colour      // the last valid colour

  signal edited(string text)
  signal accepted(string colour)
  signal chipClicked()

  implicitHeight: Theme.controlHeight
  radius: Theme.radiusControl
  // set once: whether it sits in a Settings box (a walk up, not a binding)
  property bool boxed: false
  color: input.activeFocus || hover.hovered ? Theme.hoverOn(boxed) : Theme.fillOn(boxed)
  // Keep keyboard focus visible on the entire colour field, not only its chip.
  border.width: input.activeFocus ? Math.max(Theme.focusRingWidth, Theme.frameWidth) : Theme.frameWidth
  border.color: input.activeFocus ? Theme.focusRing : hover.hovered ? Theme.foreground2 : Theme.gray
  Behavior on border.color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

  KitFieldLine { active: input.activeFocus }

  HoverHandler { id: hover; cursorShape: Qt.IBeamCursor }

  onValueChanged: {
    if (!input.activeFocus) input.text = value;
    if (valid) saved = colour;
  }
  Component.onCompleted: { boxed = Theme.boxed(parent); input.text = value; }

  Rectangle {
    id: chip
    anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
    width: 18
    height: 18
    radius: Theme.radiusControl
    color: root.valid ? root.colour : "transparent"
    scale: chipArea.pressed || chipArea.keyboardPressed ? 0.92 : 1
    Behavior on scale { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
    border.width: chipArea.activeFocus ? Theme.focusRingWidth : Theme.frameWidth
    border.color: chipArea.activeFocus ? Theme.focusRing : Theme.gray

    MouseArea {
      id: chipArea
      anchors.fill: parent
      enabled: root.enabled
      activeFocusOnTab: enabled
      property bool keyboardPressed: false
      onActiveFocusChanged: if (!activeFocus) keyboardPressed = false
      Accessible.role: Accessible.Button
      Accessible.name: "Open colour picker"
      Accessible.description: root.valid ? "Current colour " + root.colour : "Current colour is invalid"
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: { forceActiveFocus(); root.chipClicked(); }
      Keys.onPressed: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
        if (!event.isAutoRepeat) {
          keyboardPressed = true;
          root.chipClicked();
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
  }

  TextInput {
    id: input
    anchors { left: chip.right; leftMargin: Theme.gapMedium; right: chevron.left; rightMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
    color: Theme.foreground0
    clip: true
    selectByMouse: true
    selectionColor: Theme.background3
    selectedTextColor: Theme.foreground0
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.weight: Theme.fontWeight
    Accessible.name: root.accessibleName
    Accessible.description: root.valid ? qsTr("Current colour: %1").arg(root.colour)
      : qsTr("Enter a six-digit hexadecimal colour")

    Text {
      visible: input.text === "" && !input.activeFocus
      text: root.placeholder
      color: Theme.muted
      font: input.font
    }

    onTextEdited: {
      root.edited(text);
      const t = text.trim();
      if (root.live && /^#?[0-9a-fA-F]{6}$/.test(t)) {
        root.saved = "#" + t.replace(/^#/, "").toLowerCase();
        root.accepted(root.saved);
      }
    }
    onAccepted: if (root.valid) { root.saved = root.colour; root.accepted(root.colour); }
    onActiveFocusChanged: {
      if (activeFocus || root.valid || root.saved === "") return;
      input.text = root.saved;
      root.edited(root.saved);
    }
  }

  KitIcon {
    id: chevron
    anchors { right: parent.right; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
    name: "chevron-down"
    tint: Theme.foreground2
    size: Theme.iconSmall
    rotation: root.open ? 180 : 0

    Behavior on rotation { enabled: Motion.controls; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }

    Rectangle {
      anchors.fill: parent
      anchors.margins: -Theme.gapSmall
      visible: chevronArea.activeFocus
      radius: Theme.radiusControl
      color: Theme.clear
      border.width: Theme.focusRingWidth
      border.color: Theme.focusRing
    }

    MouseArea {
      id: chevronArea
      anchors.fill: parent
      anchors.margins: -Theme.gapMedium
      enabled: root.enabled
      activeFocusOnTab: enabled
      Accessible.role: Accessible.Button
      Accessible.name: "Open colour picker"
      Accessible.description: root.open ? "Colour picker is open" : "Open the colour picker"
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: { forceActiveFocus(); root.chipClicked(); }
      Keys.onPressed: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
        if (!event.isAutoRepeat) root.chipClicked();
        event.accepted = true;
      }
    }
  }
}
