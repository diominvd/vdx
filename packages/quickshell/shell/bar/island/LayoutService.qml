pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../kit/reply.js" as Reply

// The active keyboard layout (the island's layout flash). The first value
// comes from `hyprctl devices` (Hyprland doesn't replay activelayout on
// connect), changes from the activelayout event.
Singleton {
  id: root

  // ---- state ----
  property string layout: ""                   // Hyprland's layout name ("English (US)")

  // ---- events ----
  Connections {
    target: Hyprland
    // data: "<keyboard>,<layout name>"
    function onRawEvent(event) {
      if (event.name === "activelayout" && event.data)
        root.layout = event.data.slice(event.data.indexOf(",") + 1);
    }
  }

  // ---- processes ----
  Process {
    command: ["hyprctl", "devices", "-j"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        // Pseudo-keyboards (power buttons, WMI hotkeys) report a stale keymap:
        // prefer the main keyboard.
        const keyboards = Reply.parse(text, "hyprctl", null)?.keyboards ?? [];
        const kb = keyboards.find(k => k.main && k.active_keymap) ?? keyboards.find(k => k.active_keymap);
        if (kb) root.layout = kb.active_keymap;
      }
    }
  }
}
