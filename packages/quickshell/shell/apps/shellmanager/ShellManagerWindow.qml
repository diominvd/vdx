import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The Shell Manager as a window of its own (its window rule comes from scripts/shellapps.py (Shell Manager › Shell apps)). Opened
// from the bar's Shell button, Super+S, `qs -c shell ipc call shell toggle` or
// `… shell open <page>[:<group or app>]` (appearance, animations, bar, modules,
// windows, lockscreen, notifications, network, bluetooth, displays, apps, about; launcher and
// keybinds open their app in apps, lock the lock screen, media the audio in
// modules); Escape closes it.
FloatingWindow {
  id: root

  title: "Shell Manager"
  visible: ShellSettings.managerOpen
  implicitWidth: 1240
  implicitHeight: 720
  color: Theme.background0

  onVisibleChanged: {
    if (visible) ThemeService.refresh();     // themes added since start show up
    else ShellSettings.managerOpen = false;
  }

  Loader {
    id: manager
    anchors.fill: parent
    active: root.visible
    asynchronous: false
    source: Qt.resolvedUrl("ShellManager.qml")
  }

  Shortcut {
    sequences: [StandardKey.Cancel]
    enabled: !manager.item?.dialogOpen && !manager.item?.searching && !(manager.item?.currentPage?.arranging ?? false)   // Escape closes the inline editor or the search first
    onActivated: ShellSettings.managerOpen = false
  }

  IpcHandler {
    target: "shell"
    function toggle(): void { ShellSettings.managerOpen = !ShellSettings.managerOpen; }
    // `open <page>`, or `open <page>:<group or app>` (apps:taskmanager,
    // bar:layout); the old page names still work
    function open(page: string): void {
      const [p, target] = page.split(":");
      ShellSettings.managerOpen = true;
      Qt.callLater(() => manager.item?.navigate(({ layout: "bar" })[p] ?? p, target ?? ""));
    }
    // the sidebar's search, `search <words>` typed in
    function search(words: string): void {
      ShellSettings.managerOpen = true;
      Qt.callLater(() => manager.item?.search(words));
    }
  }
}
