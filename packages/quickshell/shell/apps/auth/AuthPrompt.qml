import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.components
import qs.config
import qs.kit

// The shell's root panel and the session's polkit agent. It slides down from
// under the bar on the focused monitor, like a popup, in one of three looks:
//   confirm  — a root action of the shell (RootService): what it is, each step
//              in words with its command; Run / Cancel (Enter / Escape);
//   password — polkit asks (our Run the first time, or any program's pkexec,
//              systemctl…): the password, masked with squares, Unlock /
//              Cancel; a wrong one says so and asks again;
//   running  — our action is on.
// It holds the keyboard while shown.
Scope {
  id: root

  PolkitAgent {
    id: agent
  }

  readonly property var flow: agent.flow
  readonly property bool asking: agent.isActive && flow !== null && !flow.isCompleted
  readonly property bool ours: RootService.pending
  readonly property bool shown: asking || ours

  function submit() {
    if (!flow || !flow.isResponseRequired) return;
    flow.submit(password.text);
    password.text = "";
  }

  function cancel() {
    password.text = "";
    if (asking) flow.cancelAuthenticationRequest();
    else RootService.cancel();
  }

  PanelWindow {
    id: panel

    visible: root.shown || slide.running
    screen: Hypr.focusedScreen
    anchors.top: true
    margins.top: Theme.popupGap
    exclusionMode: ExclusionMode.Normal     // under the bar, not over it
    exclusiveZone: 0
    implicitWidth: Theme.popupWidth + 80
    implicitHeight: frame.implicitHeight + 8
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-auth"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // slides down from above the panel's top edge
    Item {
      anchors.fill: parent
      clip: true

      KitFrame {
        id: frame
        x: 20
        width: Theme.popupWidth + 40
        y: root.shown ? 0 : -600           // from above the window's top (it clips); not its own height: a loop
        focus: true

        Behavior on y { enabled: Motion.panels; NumberAnimation { id: slide; duration: Motion.ms(220); easing.type: Motion.easing } }

        // the confirm look: Enter runs, Escape cancels (the password field has its own)
        Keys.onPressed: event => {
          if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) return;
          if (!event.isAutoRepeat && root.ours && !root.asking && !RootService.running) RootService.run();
          event.accepted = true;
        }
        Keys.onEscapePressed: root.cancel()

        KitHeader {
          icon: "lock"
          title: root.ours ? RootService.title : "Authentication"
          subtitle: root.ours ? RootService.source.toUpperCase() + " · AS ROOT · " + RootService.steps.length
                                + (RootService.steps.length === 1 ? " STEP" : " STEPS")
                              : "PASSWORD FOR " + (Quickshell.env("USER") ?? "YOU").toUpperCase()
        }

        KitLine {}

        // ---- what happens (ours) ----
        Column {
          visible: root.ours
          width: parent.width
          spacing: Theme.gapWide

          Repeater {
            model: RootService.steps

            Column {
              required property var modelData
              required property int index

              width: parent.width
              spacing: 3

              KitText {
                width: parent.width
                text: (index + 1) + ". " + modelData.label
                font.weight: Font.ExtraBold
              }

              KitText {
                width: parent.width
                text: modelData.what
                wrapMode: Text.WordWrap
                color: Theme.foreground2
                font.pixelSize: Theme.fontSize - 1
              }

              KitText {
                width: parent.width
                text: "# " + modelData.command
                elide: Text.ElideRight
                color: Theme.muted
                font.pixelSize: Theme.fontSize - 2
              }
            }
          }
        }

        // ---- what a program asks (not ours) ----
        KitText {
          visible: root.asking && !root.ours
          width: parent.width
          wrapMode: Text.WordWrap
          text: root.flow?.message ?? ""
        }

        // ---- the password ----
        KitLine { visible: root.asking && root.ours }

        KitInput {
          id: password
          visible: root.asking
          width: parent.width
          accessibleName: root.ours ? "Authentication password" : (root.flow?.inputPrompt ?? "Authentication response").replace(/:\s*$/, "")
          placeholder: root.ours ? "your password, to run it" : (root.flow?.inputPrompt ?? "Password").replace(/:\s*$/, "").toLowerCase()
          echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
          centerMasked: false
          onAccepted: root.submit()
          Keys.onEscapePressed: root.cancel()
        }

        KitText {
          width: parent.width
          visible: root.asking && text !== ""
          wrapMode: Text.WordWrap
          text: root.flow?.supplementaryMessage ?? ""
          color: root.flow?.supplementaryIsError ? Theme.red : Theme.muted
          font.pixelSize: Theme.fontSize - 1
        }

        // ---- foot ----
        Item {
          width: parent.width
          height: buttons.height

          KitText {
            anchors { left: parent.left; right: buttons.left; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
            visible: root.ours && !root.asking
            wrapMode: Text.WordWrap
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 2
            text: RootService.running ? "running…" : "first time with your password, then for 5 min just this"
          }

          Row {
            id: buttons
            anchors.right: parent.right
            spacing: Theme.gapSmall

            KitButton {
              icon: "x"
              text: "Cancel"
              disabled: RootService.running && !root.asking
              onClicked: root.cancel()
            }

            KitButton {
              visible: root.asking
              icon: "check"
              text: "Unlock"
              disabled: !(root.flow?.isResponseRequired ?? false)
              onClicked: root.submit()
            }

            KitButton {
              visible: root.ours && !root.asking
              icon: "lock"
              text: "Run"
              busy: RootService.running
              onClicked: RootService.run()
            }
          }
        }
      }
    }
  }

  // the panel takes the keys as it comes; a password request focuses the
  // field, empty (a retry after a wrong password too)
  onShownChanged: if (shown) focusLater.restart()
  onAskingChanged: focusLater.restart()
  Connections {
    target: root.flow
    ignoreUnknownSignals: true
    function onIsResponseRequiredChanged() { if (root.flow.isResponseRequired) focusLater.restart(); }
  }
  Timer {
    id: focusLater
    interval: 30
    onTriggered: {
      if (root.asking) { password.text = ""; password.input.forceActiveFocus(); }
      else frame.forceActiveFocus();
    }
  }
}
