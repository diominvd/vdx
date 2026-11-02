pragma Singleton
import QtQuick
import Quickshell
import qs.components
import qs.config

// Accent outside the shell: the focused window's border in Hyprland (Appearance
// › Colours › Window border), now, and ~/.local/state/dotfiles/accent.lua
// for its next start, read by hypr/components/appearance.lua. Off: the frame
// colour again.
Singleton {
  id: root

  // ---- tuning ----
  readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/dotfiles/accent.lua"

  readonly property bool border: Theme.accentOn("window")
  // Hyprland's config: 0xAARRGGBB
  readonly property string colour: !border ? argb(Theme.frame)
    : argb(Theme.accent)
  onColourChanged: apply()

  function argb(c) {
    const part = v => Math.round(v * 255).toString(16).padStart(2, "0");
    return "0xff" + part(c.r) + part(c.g) + part(c.b);
  }

  function apply() {
    const lua = border ? "return { border = " + colour + " }" : "return {}";
    Hypr.writeState(stateFile, lua + "\n");
    Hypr.call("hl.config({general = {col = {active_border = " + colour + "}}})");
  }
}
