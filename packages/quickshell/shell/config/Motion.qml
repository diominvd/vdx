pragma Singleton

import QtQuick
import Quickshell

// The shell's animations in one place (Shell Manager › Animations): whether
// each part moves and how long a move takes. A Behavior takes
// `enabled: Motion.<part>` and a duration from here; everything off (or a
// part off) snaps in place.
//   popups   — a bar popup coming in: fade, slide down from the bar, grow
//   panels   — the launcher, keybinds, switcher, overview: dim and zoom in
//   controls — hover fades, switch knobs, select chevrons, level bars, rows
//              easing in and gliding (kit/KitColumn: popups, option pages)
//   bar      — workspaces changing, the popup underline
//   pages    — the Shell Manager's pages and sidebar
//   tabs     — the sections of a page (a fade when one is picked)
//   lock     — the lock screen coming in, a shake on a wrong password
//   island   — the island (Bar › Look › Shape island) morphing between its views
Singleton {
  readonly property bool on: ShellSettings.motion
  // slow stretches every duration, fast shortens it
  readonly property real factor: ({ slow: 1.6, normal: 1, fast: 0.6 })[ShellSettings.motionSpeed] ?? 1

  readonly property string popupStyle: on ? ShellSettings.motionPopups : "none"
  readonly property bool popups: popupStyle !== "none"
  readonly property bool panels: on && ShellSettings.motionPanels
  readonly property bool controls: on && ShellSettings.motionControls
  readonly property bool bar: on && ShellSettings.motionBar
  readonly property bool pages: on && ShellSettings.motionPages
  readonly property bool tabs: on && ShellSettings.motionTabs
  readonly property bool lock: on && ShellSettings.motionLock
  readonly property bool island: on && ShellSettings.motionIsland

  function ms(base) { return Math.round(base * factor); }

  // three steps: a hover or a knob, something opening, something settling
  readonly property int quick: ms(120)
  readonly property int normal: ms(200)
  readonly property int slow: ms(380)

  // default moves decelerate; Lively opts into a small overshoot below
  readonly property int easing: Easing.OutCubic
  // a shape that resizes (the island): a longer tail; a colour that changes: a gentle one
  readonly property int morph: Easing.OutQuint
  // optional overshoot (Motion › Lively): popups, the island, switches, the segments'
  // pill, things appearing; `overshoot` is how far
  readonly property bool lively: ShellSettings.motionLively
  readonly property int spring: lively ? Easing.OutBack : Easing.OutCubic
  readonly property real overshoot: lively ? 1.0 : 0
  readonly property int tint: Easing.OutSine
}
