import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.config

// The task manager as a window of its own (its window rule comes from scripts/shellapps.py (Shell Manager › Shell apps)). Ctrl+Shift+Esc or
// `qs -c shell ipc call taskmanager toggle`; Escape clears the search,
// then closes. Processes are polled only while it is open.
FloatingWindow {
  id: root

  title: "Task Manager"
  visible: false
  implicitWidth: 980
  implicitHeight: 640
  color: Theme.background0

  // Hyprland closing the window (Super+C) hides it but leaves FloatingWindow's
  // own visible set, so the next `visible = true` would do nothing: reset it.
  onVisibleChanged: {
    TaskManagerService.open = visible;
    if (visible) Qt.callLater(() => PopupManager.closeModule("taskmanager"));
    if (!visible) {
      TaskManagerService.query = "";
      visible = false;
    }
  }

  Loader {
    anchors.fill: parent
    active: root.visible
    sourceComponent: Component {
      TaskManager { anchors.fill: parent; focus: true }
    }
  }

  Shortcut {
    sequences: [StandardKey.Cancel]
    onActivated: {
      if (TaskManagerService.query !== "") TaskManagerService.query = "";
      else root.visible = false;
    }
  }

  IpcHandler {
    target: "taskmanager"
    function toggle(): void { Hypr.toggleWindow(root); }
    function open(): void { root.visible = true; }
    function close(): void { root.visible = false; }
  }
}
