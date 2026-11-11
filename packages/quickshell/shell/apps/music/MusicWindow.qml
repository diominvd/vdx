import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.config

// Music as a window of its own (how it opens: Shell Manager › Shell apps).
// `qs -c shell ipc call music <toggle|open|close>`, `music go <tab>` (yandex, files,
// radio; the old pages likes, search, playlist open the Yandex tab; playing keeps the
// tab) or the launcher; Escape closes.
FloatingWindow {
  id: root

  title: "Music"
  visible: false
  implicitWidth: 1000
  implicitHeight: 660
  color: Theme.background0

  // Hyprland closing the window hides it but leaves FloatingWindow's own visible
  // set, so the next `visible = true` would do nothing: reset it.
  onVisibleChanged: if (visible) {
    app.shown();
    Qt.callLater(() => PopupManager.closeModule("music"));
  } else {
    visible = false;
    app.hidden();
  }

  // Keep navigation across opens without keeping the hidden view and its models.
  QtObject {
    id: app

    property var navigation: ({})
    property var requestedPage: null

    function shown() {
      content.active = true;
      for (const key of Object.keys(navigation)) content.item[key] = navigation[key];
      if (requestedPage !== null) {
        content.item.go(requestedPage);
        requestedPage = null;
      }
      content.item.shown();
    }

    function hidden() {
      if (!content.item) return;
      const view = content.item;
      navigation = { tab: view.tab, page: view.page, playlistKind: view.playlistKind,
                     folder: view.folder, radioPage: view.radioPage };
      view.hidden();
      content.active = false;
    }

    function go(page) {
      if (content.item) content.item.go(page);
      else requestedPage = page;
    }

    function cancel() { content.item?.cancel(); }
  }

  Loader {
    id: content
    anchors.fill: parent
    active: false
    sourceComponent: Component {
      Music {
        anchors.fill: parent
        onCloseRequested: root.visible = false
      }
    }
  }

  Shortcut {
    sequences: [StandardKey.Cancel]
    onActivated: app.cancel()
  }

  IpcHandler {
    target: "music"
    function toggle(): void { Hypr.toggleWindow(root); }
    function open(): void { root.visible = true; }
    function close(): void { root.visible = false; }
    function go(page: string): void {
      root.visible = true;
      app.go(page);
    }
  }
}
