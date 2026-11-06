import QtQuick
import qs.config

// Shared crossfade face. Only the selected activity group is instantiated;
// hidden groups do not keep media effects, sound bars or service bindings alive.
Row {
  id: face

  property string kind: ""
  property bool inputEnabled: true
  property int coverSize: 18
  property int badgeRadius: 4
  property int chipHeight: 24
  property int chipRadius: 0
  property int inset: 3
  property real shift: 0                 // the dots' column at the chip's left (IslandLive)
  readonly property bool track: kind === "music" || kind === "media"
  readonly property var faceComponent: ["recording", "update", "backup"].includes(kind) ? taskFace
    : kind === "notice" ? noticeFace
    : ["music", "media"].includes(kind) ? mediaFace
    : statusFace

  // The chip's side padding, read from what stands at each end, so the gap to the
  // chip's side reads as the gap above and below: a badge (`liveEnd: "badge"`: a
  // glyph circle, a capsule, a cover, a button, coverSize high) sits `inset` in,
  // concentric with the chip's corners; anything bare (text, a dot, bars) sits as
  // far in as its ink is from the chip's top, and no closer than the corner's radius
  // (in a round end that is the same gap, measured to the curve).
  readonly property int capHeight: Math.round(Theme.fontSize * 0.73)   // the shell's monospace caps, ~0.73 em
  readonly property var ends: {
    const body = loader.item;
    if (!body) return [null, null];
    let first = null, last = null;
    for (const child of body.children) {
      if (!child.visible || child.width <= 0) continue;
      if (!first) first = child;
      last = child;
    }
    return [first, last];
  }
  function padFor(end) {
    if (!end) return 0;
    const shape = end.liveEnd ?? (typeof end.text === "string" && end.font !== undefined ? "text" : "");
    if (shape === "badge") return inset;
    const ink = shape === "text" ? capHeight : end.height;
    return Math.max(Math.round((chipHeight - ink) / 2), chipRadius);
  }
  readonly property int leadPad: padFor(ends[0])
  readonly property int trailPad: padFor(ends[1])

  x: shift + leadPad
  anchors.verticalCenter: parent.verticalCenter
  visible: kind !== ""

  Loader {
    id: loader
    sourceComponent: face.kind === "" ? null : face.faceComponent
    anchors.verticalCenter: parent.verticalCenter
  }

  Component { id: taskFace; IslandLiveTask { kind: face.kind; inputEnabled: face.inputEnabled; coverSize: face.coverSize; badgeRadius: face.badgeRadius } }
  Component { id: noticeFace; IslandLiveNoticeFace { kind: face.kind; coverSize: face.coverSize; badgeRadius: face.badgeRadius } }
  Component { id: statusFace; IslandLiveStatus { kind: face.kind; coverSize: face.coverSize; badgeRadius: face.badgeRadius } }
  Component { id: mediaFace; IslandLiveMedia { kind: face.kind; coverSize: face.coverSize; badgeRadius: face.badgeRadius; showCover: face.kind === "media" ? ShellSettings.liveMediaCover : ShellSettings.liveMusicCover } }
}
