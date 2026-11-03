import QtQuick
import qs.config
import qs.kit

// The value of a live activity, Material 3 style: a tonal capsule (the activity's
// colour at a low strength) around the number that matters. `solid` fills it for an alert.
// Strict keeps the bare text it always was: `plainText` / `plainTint` / `plainBold` are its look.
Rectangle {
  id: root

  property string text: ""
  property color tint: Theme.foreground1
  property bool solid: false
  property int size: 22
  property int corner: Theme.pill(height)          // the chip's less its inset: concentric (IslandLive.badgeRadius)
  // at a chip's end: a capsule sits the inset in, Strict's bare text as text (IslandLiveFace.padFor)
  readonly property string liveEnd: Theme.material ? "badge" : "text"
  property string plainText: text
  property color plainTint: tint
  property bool plainBold: true

  anchors.verticalCenter: parent ? parent.verticalCenter : undefined
  width: label.implicitWidth + (Theme.material ? Theme.gapLoose * 2 : 0)
  height: size
  radius: corner
  color: !Theme.material ? "transparent" : solid ? tint : Theme.mix(Theme.background0, tint, 0.22)

  KitText {
    id: label
    anchors.centerIn: parent
    text: Theme.material ? root.text : root.plainText
    color: !Theme.material ? root.plainTint : root.solid ? Theme.background0 : root.tint
    font.weight: Theme.material || root.plainBold ? Font.Medium : Font.Normal
  }
}
