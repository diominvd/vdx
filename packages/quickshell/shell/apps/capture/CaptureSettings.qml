import QtQuick
import qs.apps.files
import qs.config
import qs.kit

// Capture's options in the Shell Manager: what happens to a shot or a recording, where it
// goes, its quality and whether it says so; the rest (the toolbar, frame rate, codec and
// encoder with what they can cost) is behind Advanced. What, as and the sound are the
// overlay's toolbar (kept as last picked); the bar face is the module's (Bar modules › Capture).
Column {
  id: root
  spacing: Theme.sectionGap

  property bool advanced: false

  KitLabel { text: "SAVING" }

  KitOptionRow {
    module: "capture"; key: "shotTarget"; fallback: "folder"
    label: "After a screenshot"; hint: "Also copied to the clipboard"
    model: [{ label: "Save", value: "folder" }, { label: "Ask", value: "ask" }, { label: "Clipboard", value: "clipboard" }]
  }

  KitOptionRow {
    module: "capture"; key: "videoTarget"; fallback: "folder"
    label: "After a recording"; hint: "Ask: Esc saves to folder"
    model: [{ label: "Save", value: "folder" }, { label: "Ask", value: "ask" }]
  }

  Repeater {
    model: [
      { key: "shotDir",  label: "Screenshots folder", value: CaptureService.shotDir },
      { key: "videoDir", label: "Recordings folder",  value: CaptureService.videoDir }
    ]

    KitRow {
      required property var modelData

      label: modelData.label
      hint: modelData.value
      wide: true

      KitButton {
        icon: "folder"
        text: "Choose…"
        onClicked: FilesService.pickFolder(modelData.label, modelData.value,
                                           p => { if (p !== "") ModuleSettings.set("capture", modelData.key, p); })
      }
    }
  }

  KitLine {}

  KitLabel { text: "RECORDING" }

  KitOptionRow {
    module: "capture"; key: "quality"; fallback: "medium"
    label: "Quality"
    hint: "Low tints flat greys"
    model: [{ label: "Low", value: "low" }, { label: "Medium", value: "medium" }, { label: "High", value: "high" }]
  }

  // one switch for both notices; each still has its own key (a saved setting of either stays)
  KitRow {
    id: notify
    readonly property bool on: ModuleSettings.get("capture", "notifyShot", true) || ModuleSettings.get("capture", "notifyRecord", true)
    label: "Notify when saved"
    hint: "Errors still notify"
    KitSwitch {
      checked: notify.on
      onToggled: { ModuleSettings.set("capture", "notifyShot", !checked); ModuleSettings.set("capture", "notifyRecord", !checked); }
    }
  }

  KitLine {}

  KitLabel { text: "ADVANCED" }

  KitRow {
    label: "More options"
    hint: root.advanced ? "Toolbar, frame rate, codec, encoder" : "Toolbar, frame rate, encoder"
    KitButton {
      width: Theme.buttonWidth
      text: root.advanced ? "Hide" : "Show"
      onClicked: root.advanced = !root.advanced
    }
  }

  KitOptionRow {
    visible: root.advanced
    module: "capture"; key: "delay"; fallback: 0
    label: "Delay button"
    hint: "Off: no button in the toolbar"
    model: [{ label: "Off", value: 0 }, { label: "3 s", value: 3 }, { label: "5 s", value: 5 }, { label: "10 s", value: 10 }]
  }

  KitToggleRow {
    visible: root.advanced
    module: "capture"; key: "grid"; fallback: true
    label: "Grid"
    hint: "Thirds in the selection, to compose"
  }

  KitOptionRow {
    visible: root.advanced
    module: "capture"; key: "fps"; fallback: 60
    label: "Frame rate"; hint: "Smoother, bigger files"
    model: [{ label: "30 fps", value: 30 }, { label: "60 fps", value: 60 }]
  }

  KitOptionRow {
    visible: root.advanced
    module: "capture"; key: "codec"; fallback: "auto"
    label: "Codec"
    hint: "Auto: HEVC on the GPU"
    model: [{ label: "Auto", value: "auto" }, { label: "H.264", value: "h264" }, { label: "HEVC", value: "hevc" }]
  }

  KitOptionRow {
    visible: root.advanced
    module: "capture"; key: "encoder"; fallback: "auto"
    label: "Encoder"
    hint: "Auto: iGPU on battery"
    model: [{ label: "Auto", value: "auto" }, { label: "iGPU", value: "igpu" }, { label: "GPU", value: "gpu" }, { label: "CPU", value: "cpu" }]
  }

  // every problem the current codec, encoder and quality can cause
  Repeater {
    model: root.advanced ? CaptureService.codecIssues : []

    Column {
      required property var modelData

      width: parent.width
      spacing: Theme.gapHair

      KitText {
        width: parent.width
        wrapMode: Text.WordWrap
        font.weight: Font.ExtraBold
        color: modelData.warn ? Theme.yellow : Theme.foreground0
        text: modelData.title
      }

      KitText {
        width: parent.width
        wrapMode: Text.WordWrap
        color: modelData.warn ? Theme.yellow : Theme.muted
        text: modelData.text
      }
    }
  }

  KitGrouper {}
}
