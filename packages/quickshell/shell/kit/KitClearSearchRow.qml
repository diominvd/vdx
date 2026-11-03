import QtQuick

// A panel with a search: what was typed is cleared when it closes
// (ModuleSettings `module`, key "clear").
KitToggleRow {
  key: "clear"
  fallback: true
  label: "Clear search on close"
  hint: "Off: the search stays as it was"
}
