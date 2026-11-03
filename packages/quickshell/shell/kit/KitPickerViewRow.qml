import QtQuick

// A picker popup (Themes, Wallpapers): cards or a list; Auto takes cards in the island
// (ModuleSettings `module`, key "view").
KitOptionRow {
  key: "view"
  fallback: "auto"
  label: "View"
  hint: "Auto: cards in the island"
  model: [
    { label: "Auto",  value: "auto" },
    { label: "Cards", value: "cards" },
    { label: "List",  value: "list" }
  ]
}
