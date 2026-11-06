import QtQuick
import qs.apps.files
import qs.config
import qs.kit

// Capture's options in the Shell Manager: the toolbar's delay, where
// screenshots and recordings go, the codec and what it can cost. What, as and
// the sound are the overlay's toolbar (kept as last picked); the bar face is
// the module's (Bar modules › Capture).
Column {
  spacing: Theme.sectionGap

  KitLabel { text: "TOOLBAR" }

  KitOptionRow {
    module: "capture"; key: "delay"; fallback: 0
    label: "Delay button"
    hint: "Off: no button in the toolbar"
    model: [{ label: "Off", value: 0 }, { label: "3 s", value: 3 }, { label: "5 s", value: 5 }, { label: "10 s", value: 10 }]
  }

  KitToggleRow {
    module: "capture"; key: "grid"; fallback: true
    label: "Grid"
    hint: "Thirds in the selection, to compose"
  }

  KitLine {}

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

  KitLine {}

  KitLabel { text: "FOLDERS" }

  Repeater {
    model: [
      { key: "shotDir",  label: "Screenshots", value: CaptureService.shotDir },
      { key: "videoDir", label: "Recordings",  value: CaptureService.videoDir }
    ]

    KitRow {
      required property var modelData

      label: modelData.label
      hint: modelData.value
      wide: true

      KitButton {
        icon: "folder"
        text: "Choose…"
        onClicked: FilesService.pickFolder(modelData.label + " folder", modelData.value,
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

  KitOptionRow {
    module: "capture"; key: "fps"; fallback: 60
    label: "Frame rate"; hint: "Smoother, bigger files"
    model: [{ label: "30 fps", value: 30 }, { label: "60 fps", value: 60 }]
  }

  KitOptionRow {
    module: "capture"; key: "codec"; fallback: "auto"
    label: "Codec"
    hint: "Auto: HEVC on the GPU"
    model: [{ label: "Auto", value: "auto" }, { label: "H.264", value: "h264" }, { label: "HEVC", value: "hevc" }]
  }

  KitOptionRow {
    module: "capture"; key: "encoder"; fallback: "auto"
    label: "Encoder"
    hint: "Auto: iGPU on battery"
    model: [{ label: "Auto", value: "auto" }, { label: "iGPU", value: "igpu" }, { label: "GPU", value: "gpu" }, { label: "CPU", value: "cpu" }]
  }

  // every problem the current codec, encoder and quality can cause
  KitLabel { text: "PROBLEMS"; value: CaptureService.codecIssues.length === 0 ? "NONE" : "" }

  Repeater {
    model: CaptureService.codecIssues

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

  KitLine {}

  KitLabel { text: "NOTIFICATIONS" }

  KitToggleRow { module: "capture"; key: "notifyShot"; fallback: true; label: "Notify after a screenshot"; hint: "Errors still notify" }
  KitToggleRow { module: "capture"; key: "notifyRecord"; fallback: true; label: "Notify after a recording"; hint: "Errors still notify" }

  KitGrouper {}
}
