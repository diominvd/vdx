import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.kit

// Lock screen options, the Lock screen page (ModuleSettings "lock"), the most used
// first: when it locks by itself (SESSION); what the lock (Super+Z) shows — the
// background, the blur, the clock, the date, the user (LOOK); the controls on it: the
// keyboard layout, the power buttons and the cursor that hides after a few still
// seconds (ON SCREEN); the monitors it shows on (WHERE). apps/lock reads them.
KitColumn {
  id: root

  function opt(key, fallback) { return ModuleSettings.get("lock", key, fallback); }

  spacing: Theme.sectionGap

  // ---- session ----
  KitLabel { text: "SESSION" }

  KitSelect {
    width: parent.width
    label: "Lock after"; hint: "Minutes without input"
    model: [{ label: "Never", value: 0 }].concat([1, 5, 10, 15, 30].map(v => ({ label: v + " min", value: v })))
    current: root.opt("autoLock", 0)
    onPicked: value => ModuleSettings.set("lock", "autoLock", value)
  }

  KitLine {}

  // ---- look ----
  KitLabel { text: "LOOK" }

  KitOptionRow {
    wide: false
    module: "lock"; key: "background"; fallback: "solid"
    label: "Background"; hint: "Blurred: the desktop as it was"
    model: [{ label: "Solid", value: "solid" }, { label: "Wallpaper", value: "wallpaper" }, { label: "Blurred", value: "blur" }]
  }

  KitSliderRow {
    id: blur
    visible: root.opt("background", "solid") === "blur"
    label: "Blur"
    // the reading follows the knob while it is dragged; saved on release
    value: root.opt("blur", 60) / 100
    text: Math.round((blur.pressed ? blur.dragValue : value) * 100) + "%"
    onReleased: v => ModuleSettings.set("lock", "blur", Math.round(v * 100))
  }

  KitOptionRow {
    module: "lock"; key: "clock"; fallback: "24h"
    label: "Clock format"; hint: ""
    model: [{ label: "24h", value: "24h" }, { label: "12h", value: "12h" }]
  }

  KitToggleRow { module: "lock"; key: "date"; fallback: true; label: "Show date"; hint: "Under the clock" }

  KitToggleRow { module: "lock"; key: "user"; fallback: true; label: "Show user name"; hint: "Above the password" }

  KitLine {}

  // ---- on screen ----
  KitLabel { text: "ON SCREEN" }

  KitToggleRow { module: "lock"; key: "layout"; fallback: true; label: "Keyboard layout"; hint: "Beside the field, a click switches it" }

  KitToggleRow { module: "lock"; key: "power"; fallback: true; label: "Power buttons"; hint: "Suspend, reboot, shut down" }

  KitToggleRow { module: "lock"; key: "hideCursor"; fallback: true; label: "Hide cursor when idle"; hint: "Shows again when the mouse moves" }

  KitOptionRow {
    visible: root.opt("hideCursor", true)
    module: "lock"; key: "cursorDelay"; fallback: 3
    label: "Hide after"; hint: "Seconds without a mouse move"
    model: [1, 3, 5, 10].map(v => ({ label: v + " s", value: v }))
  }

  KitLine {}

  // ---- where ----
  KitLabel { text: "WHERE" }

  // other monitors stay dark; typing there still goes into the password
  KitSelect {
    width: parent.width
    label: "Monitors"; hint: "Focused: the one in use"
    model: [{ label: "All", value: "all" }, { label: "Focused", value: "focused" }]
           .concat(Quickshell.screens.map(s => ({ label: s.name, value: s.name })))
    current: root.opt("screen", "all")
    onPicked: value => ModuleSettings.set("lock", "screen", value)
  }

  KitGrouper {}
}
