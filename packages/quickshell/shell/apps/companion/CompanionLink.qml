pragma Singleton

import QtQuick
import Quickshell

// The live Kimmy, for Shell Manager › Kimmy: its window puts its brain here while it
// lives (null when it is hidden), so the page shows how it is and can call it or send it
// home without a state of its own.
Singleton {
  property var brain: null
}
