import QtQuick
import qs.config
import qs.kit

// The cleaner's content: a header with Basic / AI, the list scrolling under
// it, and a foot with what the click will free and the button.
//   Basic — categories in two groups, YOUR FILES (emptied at once) and
//   SYSTEM (root: one password, asked by the shell's panel), each with its
//   size and a switch;
//   AI    — Claude's suggestions from a summary of ~ (sizes and ages, never
//   contents), each with why and its size; picked ones go to the Trash.
Rectangle {
  id: root
  // rows already on show: a new one eases in (KitAppear)
  property KitSeen seen: KitSeen {}

  color: Theme.background0

  readonly property var cs: CleanerService
  property string tab: "basic"
  // the foot's button asks once more (option `confirm`)
  property bool armed: false

  function act() {
    if (cs.confirm && !armed) { armed = true; disarm.restart(); return; }
    armed = false;
    if (tab === "ai") cs.trashChosen();
    else cs.clean();
  }

  onTabChanged: armed = false

  Timer { id: disarm; interval: 3000; onTriggered: root.armed = false }

  // ---- header ----
  Column {
    id: head
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.windowPadding; topMargin: Theme.windowPadding - Theme.headerInset }
    spacing: Theme.gapGroup

    KitHeader {
      icon: "brush"
      title: "Cleaner"
      subtitle: (root.cs.categories.length === 0 ? "SCANNING…" : Format.shortSize(root.cs.total).toUpperCase() + " CAN GO")
        + (root.tab === "ai" && root.cs.suggestions.length > 0 ? " · " + root.cs.suggestions.length + " SUGGESTIONS" : "")

      KitChoices {
        visible: root.cs.aiOn
        model: [{ label: "Basic", value: "basic", icon: "list" }, { label: "AI", value: "ai", icon: "bot" }]
        current: root.tab
        onPicked: value => root.tab = value
      }

      KitButton {
        icon: "refresh"
        busy: root.cs.scanning
        onClicked: root.cs.scan()
      }
    }

    KitLine {}
  }

  // ---- list ----
  Flickable {
    id: list
    anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: foot.top; leftMargin: Theme.windowPadding; rightMargin: Theme.windowPadding; topMargin: 14 }
    contentHeight: (root.tab === "ai" ? ai.implicitHeight : basic.implicitHeight) + 14
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    // -- basic
    Column {
      id: basic
      width: list.width
      visible: root.tab === "basic"
      spacing: Theme.gapGroup

      Repeater {
        model: [
          { title: "YOUR FILES", root: false },
          { title: "SYSTEM · ASKS YOUR PASSWORD", root: true }
        ]

        Column {
          id: group

          required property var modelData
          required property int index

          readonly property var items: root.cs.categories.filter(c => c.root === modelData.root)

          width: basic.width
          spacing: Theme.gapGroup

          KitLabel {
            text: group.modelData.title
            value: Format.shortSize(group.items.reduce((s, c) => s + c.size, 0)).toUpperCase()
          }

          Repeater {
            model: group.items

            KitRow {
              required property var modelData

              label: modelData.label
              hint: modelData.hint
              labelColor: modelData.size > 0 ? Theme.foreground0 : Theme.muted

              KitText {
                anchors.verticalCenter: parent.verticalCenter
                width: 80
                horizontalAlignment: Text.AlignRight
                text: modelData.size > 0 ? Format.shortSize(modelData.size) : "empty"
                color: modelData.size > 0 ? Theme.foreground2 : Theme.muted
              }

              KitSwitch {
                accessibleName: modelData.label
                anchors.verticalCenter: parent.verticalCenter
                checked: root.cs.picked[modelData.id] === true
                onToggled: root.cs.pick(modelData.id, !checked)
              }
            }
          }

          KitLine { visible: group.index === 0 }
        }
      }
    }

    // -- ai
    Column {
      id: ai
      width: list.width
      visible: root.tab === "ai"
      spacing: Theme.gapGroup

      KitText {
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.muted
        text: "Claude looks at what takes room in your home folder — sizes and ages, never what is inside — "
            + "and suggests what could go. Nothing is removed until you pick it, and picked items go to the Trash."
      }

      KitRow {
        label: "Analyse"
        hint: "With " + root.cs.model + ", about 15 seconds"

        KitButton {
          width: Theme.buttonWidth
          icon: "bot"
          text: root.cs.suggestions.length > 0 ? "Again" : "Analyse"
          busy: root.cs.analyzing
          onClicked: root.cs.analyze()
        }
      }

      KitLine { visible: root.cs.suggestions.length > 0 }

      KitLabel {
        visible: root.cs.suggestions.length > 0
        text: "SUGGESTIONS"
        value: Format.shortSize(root.cs.suggestions.reduce((s, x) => s + x.size, 0)).toUpperCase()
      }

      Repeater {
        model: root.cs.suggestions

        KitRow {
          id: tip
          required property var modelData

          // the AI's suggestions ease in as they come
          KitAppear { target: tip; seen: root.seen; key: tip.modelData.path }

          label: modelData.path
          hint: modelData.why + " · " + modelData.days + " days old"
          labelColor: modelData.risk === "medium" ? Theme.yellow : Theme.foreground0

          KitText {
            anchors.verticalCenter: parent.verticalCenter
            width: 80
            horizontalAlignment: Text.AlignRight
            text: Format.shortSize(modelData.size)
            color: Theme.foreground2
          }

          KitSwitch {
            accessibleName: modelData.path
            anchors.verticalCenter: parent.verticalCenter
            checked: root.cs.aiPicked[modelData.path] === true
            onToggled: root.cs.aiPick(modelData.path, !checked)
          }
        }
      }

      KitText {
        visible: root.cs.suggestions.length > 0
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 2
        text: "Yellow: Claude is less sure — have a look before picking it."
      }
    }
  }

  // ---- foot ----
  Column {
    id: foot
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.windowPadding; bottomMargin: Theme.windowPadding }
    spacing: Theme.gapWide

    KitLine {}

    Item {
      width: parent.width
      height: action.height

      Column {
        anchors { left: parent.left; right: action.left; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
        spacing: Theme.gapTight

        KitText {
          width: parent.width
          elide: Text.ElideRight
          font.weight: Font.ExtraBold
          text: root.tab === "ai"
            ? (root.cs.aiChosen.length > 0 ? Format.shortSize(root.cs.aiSize) + " picked" : "Nothing picked")
            : (root.cs.pickedSize > 0 ? Format.shortSize(root.cs.pickedSize) + " picked" : "Nothing picked")
        }

        KitText {
          width: parent.width
          elide: Text.ElideRight
          font.pixelSize: Theme.fontSize - 2
          color: root.cs.status === "error" ? Theme.red : root.cs.status === "ok" ? Theme.green : Theme.muted
          text: root.cs.message !== "" ? root.cs.message
              : root.tab === "ai" ? "picked items go to trash"
              : root.cs.pickedRoot.length > 0 ? "the system part asks for your password" : "your files are emptied at once"
        }
      }

      KitButton {
        id: action
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        icon: root.armed ? "check" : root.tab === "ai" ? "trash" : "brush"
        text: root.armed ? "Sure?" : root.tab === "ai" ? "Move to trash" : "Clean"
        selected: root.armed
        busy: root.cs.busy
        disabled: root.tab === "ai" ? root.cs.aiChosen.length === 0 : root.cs.pickedSize <= 0
        onClicked: root.act()
      }
    }
  }
}
