import QtQuick

// A panel or popup with a search: the keyboard switches to English when it opens
// (ModuleSettings `module`, key "english").
KitToggleRow {
  key: "english"
  fallback: true
  label: "English layout on open"
  hint: "Switches the keyboard when it opens"
}
