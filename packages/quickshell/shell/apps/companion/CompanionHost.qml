import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.bar
import qs.config

// Where Kimmy lives: one window, on the monitor you are working on. When the focus has
// stayed on another monitor with a bar for a few seconds, it moves house there (it
// starts at home on the new one); a quick glance at the other screen changes nothing.
Scope {
  id: root

  property string homeScreen: ""
  property string petScreen: ""         // where it is now (it hops between monitors on its own)
  readonly property string focused: Hyprland.focusedMonitor?.name ?? ""
  readonly property bool enabled: ShellSettings.loaded && ModuleSettings.get("companion", "enabled", true)

  readonly property var barScreens: Quickshell.screens.filter(s => BarLayout.barOn(s.name))

  function pick() {
    const names = barScreens.map(s => s.name);
    if (!names.includes(homeScreen)) homeScreen = names.includes(focused) ? focused : (names[0] ?? "");
  }
  onBarScreensChanged: pick()
  Component.onCompleted: pick()

  onFocusedChanged: {
    if (focused !== "" && focused !== petScreen && barScreens.some(s => s.name === focused)) moveWait.restart();
    else moveWait.stop();
  }
  Timer {
    id: moveWait
    interval: 6000
    onTriggered: if (root.focused !== "" && root.focused !== root.petScreen && root.barScreens.some(s => s.name === root.focused)) root.homeScreen = root.focused
  }

  Variants {
    model: root.enabled ? root.barScreens.filter(s => s.name === root.homeScreen) : []

    CompanionWindow { onScreenNameChanged: root.petScreen = screenName }
  }
}
