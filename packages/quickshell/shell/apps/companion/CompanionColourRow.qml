import QtQuick
import qs.config
import qs.kit

// A colour of one of Kimmy's parts (ModuleSettings "companion", `key`): white and black
// first (it is a pet, not part of the theme), then the theme's colours, then the user's
// own. Stored as the name or #rrggbb; `fallback` is what an unset key shows as picked
// ("" rings none: the part's own default, CompanionStyle).
KitColourRow {
  id: root

  property string key
  property string fallback: ""

  names: ["white", "black"].concat(Theme.colourSet.filter(n => n !== "theme"))
  always: true
  framed: true
  picked: String(ModuleSettings.get("companion", key, fallback))
  colours: n => n === "white" ? "#f4f4f6" : n === "black" ? "#16161a" : Theme.accentColour(n)
  onChosen: value => ModuleSettings.set("companion", root.key, value)}
