import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.apps.display
import qs.config

// Wallpaper through awww: the active theme's picture (image mode, one per theme,
// and one per monitor where set: WallpaperService), else a solid colour — the
// theme's background1 (a step above the bar) or the user's own from the Shell
// Manager. Re-applied when any of it changes; at login it waits for awww-daemon.
Scope {
  id: root

  readonly property color target: ShellSettings.wallpaperMode === "custom"
    ? ShellSettings.wallpaperColor : Theme.background1
  readonly property string hex: String(target).slice(1, 7)
  readonly property string image: ShellSettings.wallpaperMode === "image"
    ? WallpaperService.imageFor(ThemeService.current) : ""
  // monitor -> picture, the ones that differ from the theme's (image mode only)
  readonly property var outputs: image !== "" ? WallpaperService.outputsFor(ThemeService.current) : ({})
  readonly property string key: image !== "" ? image + JSON.stringify(outputs) : hex

  // the picker's pick (WallpaperService.previewRel) is drawn over the wallpaper, under the windows, by apps/themepicker

  function apply() {
    // $1 is the picture ("" for the colour), $2 the colour; a picture that is gone
    // falls back to it. Then pairs of monitor and its own picture. A file name
    // never reaches the shell as code.
    const script = 'set_bg() { if [ -n "$1" ]; then awww img --transition-type fade --transition-duration 0.6 "$1" 2>/dev/null || awww clear "$2"; else awww clear "$2"; fi; }; '
      + 'each() { while [ $# -gt 1 ]; do awww img -o "$1" --transition-type fade --transition-duration 0.6 "$2" 2>/dev/null; shift 2; done; }; '
      + 'for i in $(seq 1 25); do awww query >/dev/null 2>&1 && { set_bg "$1" "$2"; shift 2; each "$@"; exit 0; }; sleep 0.4; done; exit 1';
    const pairs = [];
    for (const name in outputs) pairs.push(name, WallpaperService.pathOf(outputs[name]));
    proc.running = false;
    proc.command = ["bash", "-c", script, "bash", image === "" ? "" : WallpaperService.pathOf(image), hex].concat(pairs);
    proc.running = true;
  }

  onKeyChanged: apply()
  Component.onCompleted: apply()

  // a monitor's scale, rate or place changed: awww redraws its last picture at the
  // new size, which can be another one (the cache), so the chosen one goes on again
  Connections {
    target: DisplayService
    function onApplied() { root.apply(); }
  }

  // a monitor plugged in later has no picture yet (awww sets only the outputs
  // it knows of): apply again once it is up, else it shows Hyprland's default
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name.startsWith("monitoradded")) addedTimer.restart();
    }
  }
  Timer { id: addedTimer; interval: 500; onTriggered: root.apply() }

  Process { id: proc }
}
