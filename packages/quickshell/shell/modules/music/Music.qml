import QtQuick
import Quickshell
import qs.bar
import qs.components
import qs.config
import qs.kit
import qs.modules.player

// The music module: what plays now, of any source (PlayerService: Yandex Music,
// the local files and the radio of MPD, any MPRIS player). Idle: grey "Music".
// Click opens the popup, middle click plays or pauses.
Item {
  id: root

  // title length in the bar, from Modules › Music (-1: full, 0: the icon alone)
  readonly property int maxLength: ModuleSettings.get("music", "titleLength", 60)

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  // what the bar names: icon, both, the title or the artist (Modules › Music)
  readonly property string show: ModuleSettings.get("music", "show", "both")
  readonly property string textMode: ModuleSettings.get("music", "text", "content")
  readonly property bool iconOnly: textMode === "icon" || (textMode === "content" && (show === "icon" || maxLength === 0))
  readonly property string title: (show === "title" ? [PlayerService.title]
                                 : show === "artist" ? [PlayerService.artist]
                                 : [PlayerService.artist, PlayerService.title]).filter(s => s).join(" - ")
  readonly property string text: BarLayout.faceText("music", PlayerService.playing && title !== "" ? title : "Music")

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("music")
  Accessible.description: "Open music player controls; middle-click toggles playback"

  Keys.onPressed: event => {
    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
    if (!event.isAutoRepeat) { popup.toggle(); }
    event.accepted = true;
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusControl
    color: "transparent"
    border.width: root.activeFocus ? Theme.focusRingWidth : 0
    border.color: Theme.focusRing
  }

  KitBarItem {
    id: label
    // the icon marks the idle label only; while playing the track speaks for itself
    icon: PlayerService.playing && !root.iconOnly ? "" : "music"
    text: root.iconOnly ? "" : root.maxLength > 0 && root.text.length > root.maxLength
      ? root.text.slice(0, root.maxLength - 1) + Theme.ellipsis : root.text
    tint: PlayerService.playing ? Theme.accentFor("modules", Theme.foreground0) : Theme.gray
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      root.forceActiveFocus();
      if (mouse.button === Qt.MiddleButton) PlayerService.togglePlay();
      else popup.toggle();
    }
  }

  BarPopup {
    id: popup
    anchorItem: root
    // the Music window's IPC is `music` (apps.json)
    ipcTarget: "player"
    moduleId: "music"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    onShown: content.shown()

    MusicPopup {
      id: content
      anchors.fill: parent
      onOpenWindow: popup.visible = false
    }
  }
}
