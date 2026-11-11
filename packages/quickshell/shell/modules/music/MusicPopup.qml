import QtQuick
import Quickshell
import qs.components
import qs.bar
import qs.config
import qs.kit
import qs.modules.mpd
import qs.modules.player
import qs.modules.yandex

// Music, the bar's popup: what plays now (Yandex Music or the local files; the radio and
// other apps have popups of their own), the queue of MPD and the library to pick from. The external
// button opens the Music window.
KitFrame {
  id: root

  property string tab: "playing"
  // only MPD has a queue of ours (Yandex, files): nothing else has one
  readonly property bool hasQueue: PlayerService.music?.hasMedia ?? false
  readonly property string shownTab: tab === "queue" && !hasQueue ? "playing" : tab

  signal openWindow()
  signal closeRequested()

  // the bar popup opened: what the tabs show is read now
  function shown() {
    MpdService.refreshQueue();
    if (BarLayout.installed("yandex")) {
      YandexService.popupShown();
    }
  }

  // ---- header ----
  KitHeader {
    icon: "music"
    iconColor: PlayerService.music.hasMedia ? Theme.foreground0 : Theme.muted
    title: "Music"
    subtitle: !PlayerService.music.hasMedia ? "NOTHING PLAYING"
      : (PlayerService.music.playing ? "PLAYING" : "PAUSED") + " · " + PlayerService.music.name.toUpperCase()
  }

  KitChoices {
    width: parent.width
    stretch: true
    model: [
      { label: "Now playing", value: "playing" },
      { label: "Queue (" + PlayerService.musicQueue.length + ")", value: "queue" },
      { label: "Library", value: "library" }
    ].filter(t => t.value !== "queue" || root.hasQueue)
    current: root.shownTab
    onPicked: value => root.tab = value
  }

  KitLine {}

  MusicNowPlaying {
    visible: root.shownTab === "playing"
    onPickRequested: root.tab = "library"
    onCloseRequested: root.closeRequested()
  }

  MusicQueue {
    width: parent.width
    visible: root.shownTab === "queue"
  }

  MusicLibrary {
    width: parent.width
    visible: root.shownTab === "library"
    onOpenWindow: {
      root.openWindow();
      ShellIpc.call("music", "open");
    }
  }

  KitNotice {
    id: playbackError
    shown: MpdService.error !== ""
    icon: "info"
    tone: Theme.red
    title: "Playback error"
    text: MpdService.error
    action: "Dismiss"
    onActed: MpdService.clearError()
  }
}
