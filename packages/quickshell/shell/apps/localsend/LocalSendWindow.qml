import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.config

FloatingWindow {
  id: root

  title: "LocalSend"
  visible: false
  implicitWidth: 900
  implicitHeight: 680
  color: Theme.background0

  onVisibleChanged: {
    LocalSendService.setWindowOpen(visible);
    if (visible) {
      LocalSendService.getStatus();
      LocalSendService.discover();
      Qt.callLater(() => PopupManager.closeModule("localsend"));
    }
  }

  Loader {
    anchors.fill: parent
    active: root.visible
    sourceComponent: Component { LocalSend { anchors.fill: parent; focus: true } }
  }

  Shortcut {
    sequences: [StandardKey.Cancel]
    onActivated: root.visible = false
  }

  IpcHandler {
    target: "localsend"
    function toggle(): void { Hypr.toggleWindow(root); }
    function open(): void { root.visible = true; }
    function close(): void { root.visible = false; }
  }
}
