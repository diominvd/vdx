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
  onVisibleChanged: if (visible) library.refresh(); else visible = false;

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
    visible: library.items.length > 0

    KitLine {}

    KitButton {
      width: parent.width
      icon: "trash"
      iconTint: library.confirming ? Theme.red : Theme.foreground0
      text: library.confirming ? "Move all " + library.items.length + " to trash?" : "Clear library"
      onClicked: library.clearAll()
    }
  }

  // fills the room between the header and the foot; only its rows scroll
  CaptureLibrary {
    id: library

    anchors {
      left: parent.left; right: parent.right
      top: header.bottom; topMargin: Theme.gapGroup
      bottom: foot.visible ? foot.top : parent.bottom
      leftMargin: Theme.windowPadding; rightMargin: Theme.windowPadding
      bottomMargin: foot.visible ? Theme.gapGroup : Theme.windowPadding
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
