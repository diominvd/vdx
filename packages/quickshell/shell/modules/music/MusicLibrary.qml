import QtQuick
import Quickshell
import qs.bar
import qs.config
import qs.kit
import qs.modules.mpd
import qs.modules.yandex

// Quick picks as tiles, only the sources installed: Yandex Music's likes (one wide
// tile) and the local folders of Modules › Music (a click plays the folder, recursively),
// two to a row. "Open Music" at the foot opens the window for the rest (playlists).
Column {
  id: root

  signal openWindow()

  readonly property bool yandexOn: BarLayout.installed("yandex")
  readonly property bool filesOn: BarLayout.installed("files")
  readonly property var folders: ModuleSettings.get("music", "folders", ["~/Music"])
  readonly property real half: Math.floor((width - Theme.gapMedium) / 2)

  // a folder's path with ~ as the home folder, and its name
  function home(path) { return path.replace(/^~(?=\/|$)/, Quickshell.env("HOME")); }

  spacing: Theme.gapWide

  KitText {
    visible: !root.yandexOn && !root.filesOn
    width: parent.width
    text: "Install mpd to play music here"
    color: Theme.muted
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSize - 1
  }

  // ---- Yandex Music ----
  Column {
    visible: root.yandexOn
    width: parent.width
    spacing: Theme.gapMedium

    KitLabel { text: "YANDEX MUSIC" }

    MusicTile {
      width: parent.width
      icon: "heart-filled"
      iconTint: Theme.red
      text: "Likes"
      caption: YandexService.liked.length + " tracks"
      current: MpdService.source === "likes" && !MpdService.stopped
      busy: MpdService.busy === "likes"
      onClicked: if (!current) MpdService.load("likes", ["--likes"])
    }
  }

  // ---- files ----
  Column {
    visible: root.filesOn
    width: parent.width
    spacing: Theme.gapMedium

    KitLabel { text: "FILES" }

    KitText {
      visible: root.folders.length === 0
      width: parent.width
      text: "No folders. Add some in Modules › Music."
      color: Theme.muted
      wrapMode: Text.WordWrap
      font.pixelSize: Theme.fontSize - 1
    }

    Flow {
      width: parent.width
      spacing: Theme.gapMedium

      Repeater {
        model: root.filesOn ? root.folders : []

        MusicTile {
          required property var modelData
          readonly property string path: root.home(modelData)
          width: root.half
          icon: "folder"
          text: Paths.nameOf(path)
          caption: "Folder"
          current: MpdService.source === "files" && !MpdService.stopped && MpdService.file.startsWith(path + "/")
          busy: MpdService.busy === path
          onClicked: if (!current) MpdService.playFolder(path)
        }
      }
    }
  }

  KitButton {
    visible: root.yandexOn || root.filesOn
    width: parent.width
    icon: "external"
    text: "Open Music"
    onClicked: root.openWindow()
  }
}
