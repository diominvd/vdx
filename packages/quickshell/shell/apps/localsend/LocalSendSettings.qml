import QtQuick
import qs.config
import qs.kit

// LocalSend options in the Shell Manager (Apps › LocalSend, ModuleSettings
// "localsend"): whether the helper also runs with the window closed. Where
// the received files go is fixed: Downloads/LocalSend.
KitColumn {
  spacing: Theme.sectionGap

  KitLabel { text: "RECEIVING" }

  KitToggleRow {
    module: "localsend"
    key: "background"
    fallback: false
    label: "Run in background"
    hint: "Receive files with the window closed"
  }

  KitRow {
    label: "Save files to"
    hint: "Downloads/LocalSend"
  }

  KitGrouper {}
}
