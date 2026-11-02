import QtQuick
import qs.config
import qs.kit

// The capture overlay's toolbar, at the bottom of the focused screen: what
// (region / window / screen), as (shot / recording), a recording's sound, the
// pointer, the delay (when set in Shell Manager), the library and cancel. A
// choice changes the selection on the frozen screens at once. The line under
// it names the control under the pointer, else the keys.
Rectangle {
  id: root

  // the control under the pointer: {title, text}; null: the keys
  property var tip: null

  readonly property string keys: "r w s what · tab shot / recording · c pointer · esc cancel"
  readonly property string doing: CaptureService.mode === "region" ? "drag to select"
                                : CaptureService.mode === "window" ? "click a window or a popup" : "click a screen"

  // a choice: an icon (and a label), lit while it is the current one
  component Chip: KitButton {
    id: chip
    compact: true
    property string tipTitle: ""
    property string tipText: ""
    onHoveredChanged: {
      if (hovered) root.tip = { title: tipTitle || text, text: tipText };
      else if (root.tip?.title === (tipTitle || text)) root.tip = null;
    }
  }

  component Rule: Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    width: Theme.frameWidth > 0 ? Theme.frameWidth : 1
    height: Theme.controlHeight - Theme.gapMedium
    color: Theme.gray
  }

  implicitWidth: column.implicitWidth + 2 * Theme.gapWide
  implicitHeight: column.implicitHeight + 2 * Theme.gapWide
  radius: Theme.radiusSurface
  color: Theme.background0
  border.width: Theme.windowFrameWidth
  border.color: Theme.popupFrame

  // the toolbar is no part of the selection: hover and clicks stop here
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.AllButtons
  }

  Column {
    id: column
    x: Theme.gapWide
    y: Theme.gapWide
    spacing: Theme.gapMedium

    Row {
      spacing: Theme.gapSmall

      Repeater {
        model: [
          { label: "Region", value: "region", icon: "crop",       tip: "Drag a rectangle · R" },
          { label: "Window", value: "window", icon: "app-window", tip: "A window, a popup or the island · W" },
          { label: "Screen", value: "screen", icon: "monitor",    tip: "A whole monitor · S" }
        ]

        Chip {
          required property var modelData
          icon: modelData.icon
          text: modelData.label
          tipText: modelData.tip
          selected: CaptureService.mode === modelData.value
          onClicked: CaptureService.setMode(modelData.value)
        }
      }

      Rule {}

      Repeater {
        model: [
          { label: "Screenshot", value: "shot",   icon: "camera", tip: "A picture, also copied · Tab" },
          { label: "Recording",  value: "record", icon: "video",  tip: "A video until you stop it · Tab" }
        ]

        Chip {
          required property var modelData
          icon: modelData.icon
          text: modelData.label
          tipText: modelData.tip
          selected: CaptureService.kind === modelData.value
          onClicked: CaptureService.setKind(modelData.value)
        }
      }

      Rule { visible: CaptureService.kind === "record" }

      Repeater {
        model: CaptureService.kind === "record" ? [
          { value: "off",    icon: "volume-x", title: "No sound",     tip: "The recording is silent" },
          { value: "system", icon: "volume",   title: "System sound", tip: "What the speakers play" },
          { value: "mic",    icon: "mic",      title: "Microphone",   tip: "The default input" }
        ] : []

        Chip {
          required property var modelData
          icon: modelData.icon
          tipTitle: modelData.title
          tipText: modelData.tip
          selected: CaptureService.audio === modelData.value
          onClicked: CaptureService.setAudio(modelData.value)
        }
      }

      Rule {}

      Chip {
        icon: "cursor"
        tipTitle: CaptureService.cursor ? "Pointer shown" : "Pointer hidden"
        tipText: "In the shot or the recording · C"
        selected: CaptureService.cursor
        onClicked: CaptureService.setCursor(!CaptureService.cursor)
      }

      Chip {
        visible: CaptureService.mode === "region"
        icon: "grid"
        readonly property bool on: ModuleSettings.get("capture", "grid", true)
        tipTitle: on ? "Grid shown" : "Grid hidden"
        tipText: "Thirds inside the selection, to compose by"
        selected: on
        onClicked: ModuleSettings.set("capture", "grid", !on)
      }

      Chip {
        visible: CaptureService.delay > 0
        icon: "clock"
        text: CaptureService.delay + " s"
        tipTitle: "Delay"
        tipText: "Lets the screen go, freezes it again in " + CaptureService.delay + " s"
        onClicked: CaptureService.startDelay()
      }

      Rule {}

      Chip {
        icon: "image"
        tipTitle: "Library"
        tipText: "The saved screenshots and recordings"
        onClicked: {
          CaptureService.close();
          CaptureService.openLibrary();
        }
      }

      Chip {
        icon: "x"
        tipTitle: "Cancel"
        tipText: "Esc or a right click"
        onClicked: CaptureService.close()
      }
    }

    // the hovered control, else what to do and the keys; a recording's codec warning in yellow
    KitText {
      width: Math.min(implicitWidth, column.width)
      elide: Text.ElideRight
      font.pixelSize: Theme.fontSize - 2
      readonly property bool warn: !root.tip && CaptureService.kind === "record" && (CaptureService.codecNote?.warn ?? false)
      color: warn ? Theme.yellow : Theme.muted
      text: root.tip ? root.tip.title + (root.tip.text ? " · " + root.tip.text : "")
          : warn ? CaptureService.codecNote.title + " · " + CaptureService.codecNote.text
          : root.doing + " · " + root.keys
    }
  }
}
