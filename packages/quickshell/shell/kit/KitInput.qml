import QtQuick
import qs.config

// Outlined text field: an optional icon (`icon`: search), the text, a thin
// blinking cursor. The frame brightens on hover and while focused. The inner TextInput is exposed
// as `input` for focus handling; `passKeys` go to keyPassed (list arrows).
Rectangle {
  id: root

  property string placeholder: ""
  property string icon: ""             // kit/icons name, before the text
  property alias text: textInput.text
  property alias input: textInput
  property alias validator: textInput.validator
  // the field's own mode; a password has an eye at its right end that shows the text as typed
  // (the layout stays that of a password while it shows)
  property int echoMode: TextInput.Normal
  property bool revealable: true
  property bool revealed: false
  readonly property bool eyed: echoMode === TextInput.Password && revealable
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
  color: textInput.activeFocus || hover.hovered ? Theme.hoverOn(boxed) : Theme.fillOn(boxed)
  Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
  border.width: textInput.activeFocus && !Theme.material ? Theme.focusWidth : Theme.frameWidth
  border.color: textInput.activeFocus ? Theme.focusRing : hover.hovered ? Theme.controlLineHover : Theme.controlLineRest
  Behavior on border.color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

  KitFieldLine { active: textInput.activeFocus }

  HoverHandler { id: hover; cursorShape: Qt.IBeamCursor }

  KitIcon {
    id: lead
    anchors { left: parent.left; leftMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
    visible: root.icon !== ""
    name: root.icon
    size: Theme.iconSmall
    tint: textInput.activeFocus ? Theme.foreground0 : Theme.muted
  }

  // the eye: the same text, shown or hidden
  Item {
    id: eye
    visible: root.eyed
    anchors { right: parent.right; rightMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
    width: 24
    height: 24
    Accessible.role: Accessible.Button
    Accessible.name: root.revealed ? "Hide the text" : "Show the text"
    Accessible.onPressAction: root.revealed = !root.revealed

    KitIcon {
      anchors.centerIn: parent
      name: root.revealed ? "eye-off" : "eye"
      size: Theme.iconSmall
      tint: eyeArea.containsMouse || root.revealed ? Theme.foreground0 : Theme.muted
      Behavior on tint { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
    }
    MouseArea {
      id: eyeArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: { root.revealed = !root.revealed; textInput.forceActiveFocus(); }
    }
  }

  TextInput {
    id: textInput
    // centred (Text › Input text; a password by default): the right margin matches the icon's side
    readonly property bool masked: root.echoMode === TextInput.Password
    readonly property bool centred: root.centerMasked && (ShellSettings.inputAlign === "center" || ShellSettings.inputAlign === "auto" && masked)
    anchors { left: lead.visible ? lead.right : parent.left; leftMargin: lead.visible ? Theme.gapMedium : Theme.gapWide; right: eye.visible ? eye.left : parent.right; rightMargin: eye.visible ? 4 : centred ? (lead.visible ? lead.width + 18 : Theme.gapWide) : 10; top: parent.top; bottom: parent.bottom }
    echoMode: root.eyed && root.revealed ? TextInput.Normal : root.echoMode
    verticalAlignment: TextInput.AlignVCenter
    horizontalAlignment: centred ? TextInput.AlignHCenter : TextInput.AlignLeft
    leftPadding: centred ? font.letterSpacing : 0   // the spacing trails every square, the last one too
    color: Theme.foreground0
    clip: true
    selectByMouse: true
    activeFocusOnTab: true
    Accessible.name: root.placeholder || "Text input"
    selectionColor: Theme.background3
    selectedTextColor: Theme.foreground0
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.weight: Font.Normal
    // a password: squares (or dots, Appearance) with air between them (lock screen, root prompt)
    passwordCharacter: "•"
    font.letterSpacing: masked ? 4 : 0
    onTextEdited: root.textEdited()
    onAccepted: root.accepted()
    Keys.onPressed: event => {
      if (!root.passKeys.includes(event.key)) return;
      event.accepted = true;
      root.keyPassed(event.key);
    }

    cursorDelegate: Rectangle {
      // a thin bar, in front of the placeholder
      width: 2
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
      visible: textInput.text === ""
      text: root.placeholder
      elide: Text.ElideRight
      horizontalAlignment: textInput.centred ? Text.AlignHCenter : Text.AlignLeft
      color: Theme.muted
    }
  }
}
