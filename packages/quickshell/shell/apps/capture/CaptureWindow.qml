import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.kit

// Capture's window: the library of the saved screenshots and recordings.
// Taking one is the overlay's job (Super+Shift+S). `qs -c shell ipc call
// capture library` toggles it, the toolbar's Library opens it; Escape closes.
FloatingWindow {
  id: root

  title: "Capture"
  visible: false
  implicitWidth: 900
  implicitHeight: 680
  color: Theme.background0

  // Hyprland closing the window hides it but leaves FloatingWindow's own
  // visible set, so the next `visible = true` would do nothing: reset it.
  onVisibleChanged: if (visible) app.shown(); else { visible = false; app.hidden(); }

  QtObject {
    id: app

    property string query: ""
    property string sortKey: "date"
    property bool sortDesc: true
    property string selectedPath: ""
    property bool openPending: false

    function shown() {
      openPending = true;
      library.active = true;
      restore();
    }

    function loaded() { restore(); }

    function restore() {
      if (!openPending || !root.visible || !library.item) return;
      openPending = false;
      library.item.query = query;
      library.item.sortKey = sortKey;
      library.item.sortDesc = sortDesc;
      library.item.selectedPath = selectedPath;
      library.item.refresh();
    }

    function hidden() {
      openPending = false;
      if (library.item) {
        query = library.item.query;
        sortKey = library.item.sortKey;
        sortDesc = library.item.sortDesc;
        selectedPath = library.item.selectedPath;
      }
      library.active = false;
    }
  }

  KitHeader {
    id: header

    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.windowPadding; topMargin: Theme.windowPadding - Theme.headerInset }
    icon: "camera"
    title: "Capture"
    subtitle: CaptureService.recording ? "RECORDING · LIBRARY" : "LIBRARY"
  }

  // the foot: the library's clear, pinned under a separator like the other apps' feet
  Column {
    id: foot

    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.windowPadding; bottomMargin: Theme.windowPadding }
    spacing: Theme.sectionGap
    visible: library.item !== null && library.item.items.length > 0

    KitLine {}

    KitButton {
      width: parent.width
      icon: "trash"
      iconTint: library.item && library.item.confirming ? Theme.red : Theme.foreground0
      text: library.item && library.item.confirming
        ? "Move all " + library.item.items.length + " to trash?" : "Clear library"
      onClicked: if (library.item) library.item.clearAll()
    }
  }

  // fills the room between the header and the foot; only its rows scroll
  Loader {
    id: library

    anchors {
      left: parent.left; right: parent.right
      top: header.bottom; topMargin: Theme.gapGroup
      bottom: foot.visible ? foot.top : parent.bottom
      leftMargin: Theme.windowPadding; rightMargin: Theme.windowPadding
      bottomMargin: foot.visible ? Theme.gapGroup : Theme.windowPadding
    }

    active: false
    onLoaded: app.loaded()
    sourceComponent: Component {
      CaptureLibrary { anchors.fill: parent }
    }
  }

  Shortcut {
    sequences: [StandardKey.Cancel]
    onActivated: root.visible = false
  }

  Connections {
    target: CaptureService
    function onLibraryRequested(toggle) {
      if (toggle) Hypr.toggleWindow(root);
      else root.visible = true;
    }
  }
}
