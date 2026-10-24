import QtQuick
import Quickshell
import qs.components
import qs.bar
import qs.config
import qs.kit
import qs.modules.mpd
import qs.modules.player
import qs.modules.radio
import qs.modules.yandex

// Music, the bar's popup: what plays now (any source), the queue of MPD and the
// library to pick from (Yandex Music, the local folders, the radio). The external
// button opens the Music window.
KitFrame {
  id: root

  property string tab: "playing"
  // the switch: the music service (MPD) runs; off, the popup shows only that it is off
  readonly property bool mpdOn: BarLayout.installed("files")
  readonly property bool running: MpdService.service && !MpdService.stopped
  // what the switch was flipped to, until MPD gets there (starting or stopping it takes
  // a second): the switch and the popup follow it at once instead of flickering
  property var wanted: null
  readonly property bool on: !mpdOn || (wanted !== null ? wanted : running)
  onRunningChanged: if (running === wanted) wanted = null

  Connections {
    target: MpdService
    function onErrorChanged() { if (MpdService.error !== "") root.wanted = null; }
  }

  Timer {
    running: root.wanted !== null
    interval: 8000
    onTriggered: root.wanted = null
  }
  // only MPD has a queue of ours (Yandex, files): a browser or the radio shows no Queue tab
  readonly property bool hasQueue: PlayerService.mpd && !PlayerService.radio
  readonly property string shownTab: tab === "queue" && !hasQueue ? "playing" : tab

  signal openWindow()

  // the bar popup opened: what the tabs show is read now
  function shown() {
    MpdService.refreshQueue();
    if (BarLayout.installed("yandex")) {
      YandexService.popupShown();
    }
    if (BarLayout.installed("radio")) RadioService.popupShown();
  }

  // ---- header ----
  KitHeader {
    icon: "music"
    iconColor: root.on && PlayerService.hasMedia ? Theme.foreground0 : Theme.muted
    title: "Music"
    subtitle: !root.on ? "OFF"
      : !PlayerService.hasMedia ? "NOTHING PLAYING"
      : PlayerService.radio ? "ON AIR · " + PlayerService.artist.toUpperCase()
      : (PlayerService.playing ? "PLAYING" : "PAUSED") + " · " + PlayerService.name.toUpperCase()

    KitButton {
      anchors.verticalCenter: parent.verticalCenter
      icon: "external"
      onClicked: {
        root.openWindow();
        ShellIpc.call("music", "open");
      }
    }

    // the music service (MPD) on or off: off stops it, on plays what it kept (else the likes);
    // other players (a browser) are not its to stop
    KitSwitch {
      accessibleName: "MPD playback"
      anchors.verticalCenter: parent.verticalCenter
      visible: root.mpdOn
      checked: root.on
      onToggled: {
        root.wanted = !root.on;
        MpdService.setOn(root.wanted);
      }
    }
  }

  KitChoices {
    visible: root.on
    width: parent.width
    stretch: true
    model: [
      { label: "Now playing", value: "playing" },
      { label: "Queue (" + MpdService.queue.length + ")", value: "queue" },
      { label: "Library", value: "library" }
    ].filter(t => t.value !== "queue" || root.hasQueue)
    current: root.shownTab
    onPicked: value => root.tab = value
  }

  KitLine {}

  KitText {
    visible: !root.on
    width: parent.width
    text: MpdService.busy === "on" ? "Starting…" : "Music is off. Switch it on to play."
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 1
  }

  MusicNowPlaying {
    visible: root.on && root.shownTab === "playing"
  }

  MusicQueue {
    width: parent.width
    visible: root.on && root.shownTab === "queue"
  }

  MusicLibrary {
    width: parent.width
    visible: root.on && root.shownTab === "library"
    onOpenWindow: {
      root.openWindow();
      ShellIpc.call("music", "open");
    }
  }

  KitText {
    width: parent.width
    visible: MpdService.error !== ""
    text: MpdService.error
    color: Theme.red
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSize - 1
  }
}
