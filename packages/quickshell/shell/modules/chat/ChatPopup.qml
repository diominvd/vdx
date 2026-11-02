import QtQuick
import qs.config
import qs.kit

// The chat: who said what, newest at the bottom (answers in Markdown), and
// the field — Enter sends. New chat forgets the conversation.
KitFrame {
  id: root

  readonly property var cs: ChatService
  readonly property string modelName: cs.nameOf(cs.model)

  // the popup's window takes the keys once it is up: focus a moment later
  function focusInput() { focusLater.restart(); }
  Timer { id: focusLater; interval: 60; onTriggered: field.input.forceActiveFocus() }

  implicitWidth: 400
  focus: true
  onVisibleChanged: if (visible) focusInput()

  KitHeader {
    icon: "message"
    title: "Chat"
    subtitle: root.modelName.toUpperCase() + " · OPENCODE · FREE"

    KitButton {
      icon: "refresh"
      text: "New"
      disabled: root.cs.busy || root.cs.messages.length === 0
      onClicked: root.cs.reset()
    }
  }

  KitLine {}

  Flickable {
    id: log
    width: parent.width
    height: 360
    contentHeight: lines.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    // the newest stays in sight
    onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

    Column {
      id: lines
      width: log.width
      spacing: Theme.gapGroup

      KitText {
        visible: root.cs.messages.length === 0
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.muted
        text: "Ask anything. The model is free and runs at opencode; it can't touch your files or run commands."
      }

      Repeater {
        model: root.cs.messages

        Column {
          required property var modelData

          width: lines.width
          spacing: Theme.gapHair

          KitText {
            text: modelData.role === "user" ? "YOU" : modelData.role === "error" ? "ERROR" : root.modelName.toUpperCase()
            color: modelData.role === "error" ? Theme.red : modelData.role === "user" ? Theme.muted : Theme.foreground2
            font.pixelSize: Theme.fontSize - 2
            font.letterSpacing: 1
          }

          MessageBody {
            width: parent.width
            text: modelData.text
            markdown: modelData.role === "assistant"
            color: modelData.role === "error" ? Theme.red : Theme.foreground0
          }
        }
      }

      Row {
        visible: root.cs.busy
        spacing: Theme.gapMedium
        KitSpinner {}
        KitText { text: "thinking…"; color: Theme.muted }
      }
    }
  }

  KitLine {}

  KitInput {
    id: field
    width: parent.width
    placeholder: root.cs.busy ? "waiting for the answer…" : "message, Enter to send"
    onAccepted: {
      if (root.cs.busy) return;
      root.cs.send(text);
      text = "";
    }
  }
}
