import QtQuick
import Quickshell
import qs.bar
import qs.config
import qs.kit
import qs.modules.player

// Bar module: Media — what plays in other apps (a browser, Spotify, mpv; MPRIS).
// The title while it plays, the icon alone otherwise. A click opens the popup, a
// middle click plays or pauses.
Item {
  id: root

  required property PanelWindow bar

  // the Folder and the live slot open this module's popup
  function openPopup() { popup.toggle(); }

  readonly property var media: PlayerService.media

  implicitWidth: face.implicitWidth
  implicitHeight: face.implicitHeight

  KitBarItem {
    id: face
    icon: "play"
    text: BarLayout.faceText("media", root.media.playing ? root.media.title : "")
    tint: root.media.playing ? Theme.foreground0 : Theme.gray
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.MiddleButton) root.media.togglePlay();
      else popup.toggle();
    }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "media"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    MediaPopup {
      id: content
      anchors.fill: parent
    }
  }
}
