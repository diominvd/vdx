import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.apps.shellmanager
import qs.config

// The wallpaper the picker has picked (WallpaperService.previewRel), on the desktop: above the
// wallpaper, under every window, on every monitor; the new picture fades in over the old one once it is loaded.
Variants {
  model: Quickshell.screens

  PanelWindow {
    id: win
    required property var modelData

    readonly property string want: WallpaperService.previewRel === "" ? "" : WallpaperService.pathOf(WallpaperService.previewRel)
    property bool front: true

    screen: modelData
    visible: want !== ""
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}                        // the pointer goes through
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "wallpaper-preview"

    onWantChanged: {
      if (want !== "") (front ? back : fore).source = "file://" + want;
      else { fore.source = ""; back.source = ""; front = true; }
    }

    Image {
      id: fore
      anchors.fill: parent
      fillMode: Image.PreserveAspectCrop
      sourceSize: Qt.size(width, height)
      asynchronous: true
      opacity: win.front ? 1 : 0
      Behavior on opacity { enabled: Motion.pages; NumberAnimation { duration: Motion.ms(220) } }
      onStatusChanged: if (status === Image.Ready && !win.front) win.front = true
    }

    Image {
      id: back
      anchors.fill: parent
      fillMode: Image.PreserveAspectCrop
      sourceSize: Qt.size(width, height)
      asynchronous: true
      opacity: win.front ? 0 : 1
      Behavior on opacity { enabled: Motion.pages; NumberAnimation { duration: Motion.ms(220) } }
      onStatusChanged: if (status === Image.Ready && win.front) win.front = false
    }
  }
}
