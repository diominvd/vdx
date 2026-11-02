import QtQuick
import qs.config

// Shared crossfade face. Only the selected activity group is instantiated;
// hidden groups do not keep media effects, equalizer bars or service bindings alive.
Row {
  id: face

  property string kind: ""
  property bool inputEnabled: true
  property int coverSize: 18
  property int badgeRadius: 4
  readonly property bool track: kind === "music" || kind === "media"
  readonly property bool badged: track || kind === "notice" && ShellSettings.liveNoticeMark === "avatar"
  readonly property var faceComponent: ["recording", "update", "backup"].includes(kind) ? taskFace
    : kind === "notice" ? noticeFace
    : ["music", "media", "radio"].includes(kind) ? mediaFace
    : statusFace

  anchors.verticalCenter: parent.verticalCenter
  visible: kind !== ""

  Loader {
    sourceComponent: face.kind === "" ? null : face.faceComponent
    anchors.verticalCenter: parent.verticalCenter
  }

  Component { id: taskFace; IslandLiveTask { kind: face.kind; inputEnabled: face.inputEnabled; coverSize: face.coverSize } }
  Component { id: noticeFace; IslandLiveNoticeFace { kind: face.kind; coverSize: face.coverSize; badgeRadius: face.badgeRadius } }
  Component { id: statusFace; IslandLiveStatus { kind: face.kind } }
  Component { id: mediaFace; IslandLiveMedia { kind: face.kind; coverSize: face.coverSize; badgeRadius: face.badgeRadius } }
}
