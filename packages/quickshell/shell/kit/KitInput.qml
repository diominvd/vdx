import QtQuick
import qs.config

// Outlined text field as a prompt: "❯", the text, a blinking block cursor. The
// frame brightens on hover and while focused. The inner TextInput is exposed
// as `input` for focus handling; `passKeys` go to keyPassed (list arrows).
Rectangle {
  id: root

  property string placeholder: ""
  // Prefer a semantic label when the placeholder is a long hint or changes with state.
  property string accessibleName: ""
  property string accessibleDescription: ""
  property alias text: textInput.text
  property alias input: textInput
  property alias echoMode: textInput.echoMode
  // a masked field stands in the middle by default (lock screen, Wi-Fi); a prompt that
  // reads like a line (polkit) turns it off and the squares start after the prompt
  property bool centerMasked: true

  // keys the field hands on instead of using (a list's arrows): keyPassed(key)
  property var passKeys: []

  signal textEdited()
  signal accepted()
  signal keyPassed(int key)

  width: parent ? parent.width : 0
  implicitHeight: Theme.controlHeight
  radius: Theme.radiusControl
  // set once: whether it sits in a Settings box (a walk up, not a binding)
  property bool boxed: false
  Component.onCompleted: boxed = Theme.boxed(parent)
  color: Theme.material ? (textInput.activeFocus || hover.hovered ? Theme.hoverOn(boxed) : Theme.fillOn(boxed)) : Theme.clear
  Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
  // Keep keyboard focus visible in both control styles, including Material's
  // normally frameless fields.
  border.width: textInput.activeFocus ? Math.max(Theme.focusRingWidth, Theme.frameWidth) : Theme.frameWidth
  border.color: textInput.activeFocus ? Theme.focusRing : hover.hovered ? Theme.foreground2 : Theme.gray
  Behavior on border.color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

  KitFieldLine { active: textInput.activeFocus }

  HoverHandler { id: hover; cursorShape: Qt.IBeamCursor }

  KitText {
    id: prompt
    anchors { left: parent.left; leftMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
    visible: !Theme.material
    text: "❯"
    color: textInput.activeFocus ? Theme.yellow : Theme.gray
  }

  TextInput {
    id: textInput
    // a password stands in the middle of the field: the right margin matches the prompt's side
    readonly property bool masked: echoMode === TextInput.Password
    readonly property bool centred: masked && root.centerMasked
    anchors { left: Theme.material ? parent.left : prompt.right; leftMargin: Theme.material ? Theme.gapWide : Theme.gapMedium; right: parent.right; rightMargin: centred ? prompt.width + 18 : 10; top: parent.top; bottom: parent.bottom }
    verticalAlignment: TextInput.AlignVCenter
    horizontalAlignment: centred ? TextInput.AlignHCenter : TextInput.AlignLeft
    leftPadding: centred ? font.letterSpacing : 0   // the spacing trails every square, the last one too
    color: Theme.foreground0
    clip: true
    selectByMouse: true
    activeFocusOnTab: true
    // TextInput has its own accessible node; expose the field's visible purpose
    // even when a screen reader does not announce the placeholder automatically.
    Accessible.name: root.accessibleName !== "" ? root.accessibleName
      : root.placeholder !== "" ? root.placeholder : qsTr("Text input")
    Accessible.description: masked ? qsTr("Password field") : root.accessibleDescription
    selectionColor: Theme.background3
    selectedTextColor: Theme.foreground0
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.weight: Font.DemiBold
    // a password: squares (or dots, Appearance) with air between them (lock screen, root prompt)
    passwordCharacter: ShellSettings.passwordDots ? "•" : "■"
    font.letterSpacing: masked ? 4 : 0
    onTextEdited: root.textEdited()
    onAccepted: root.accepted()
    Keys.onPressed: event => {
      if (!root.passKeys.includes(event.key)) return;
      event.accepted = true;
      root.keyPassed(event.key);
    }

    cursorDelegate: Rectangle {
      // the terminal's block, or a thin bar in front of the placeholder (material)
      width: Theme.material ? 2 : Math.round(Theme.fontSize * 0.6)
      color: Theme.foreground0
      visible: textInput.activeFocus

      SequentialAnimation on opacity {
        running: textInput.activeFocus
        loops: Animation.Infinite
        NumberAnimation { to: 0.8; duration: 0 }
        PauseAnimation { duration: 530 }
        NumberAnimation { to: 0; duration: 0 }
        PauseAnimation { duration: 530 }
      }
    }

    KitText {
      anchors.fill: parent
      visible: textInput.text === "" && (Theme.material || !textInput.activeFocus)
      text: root.placeholder
      elide: Text.ElideRight
      color: Theme.muted
    }
  }
}
