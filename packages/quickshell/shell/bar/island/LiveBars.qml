import QtQuick
import qs.config
import qs.kit

// The sound as thin bars (LiveBarsService.levels): live while it plays, a
// flat dim row when paused. While visible it keeps the service running.
Row {
  id: root

  property int barWidth: 2
  property int barCount: LiveBarsService.bars      // fewer bars take their levels evenly from the 12
  property bool active: IslandService.playing    // live bars, else a dim flat row
  property bool flatWhenIdle: false              // not active: a flat row (a live activity's: its own player, not the room's sound)
  property string glowTarget: ""                 // a Glow target; the live activity's bars: "live"
  property var tone: null                       // one colour for all, over the theme's

  readonly property color colour: tone ?? Theme.frame

  spacing: 2

  // `visible` is the effective one: hidden with any parent
  property bool counted: false
  function count() {
    if (visible === counted) return;
    counted = visible;
    LiveBarsService.users += visible ? 1 : -1;
  }
  onVisibleChanged: count()
  Component.onCompleted: count()
  Component.onDestruction: if (counted) LiveBarsService.users--

  Repeater {
    model: root.barCount

    Rectangle {
      required property int index

      anchors.verticalCenter: parent.verticalCenter
      width: root.barWidth
      radius: Theme.pill(width)
      color: root.colour
      opacity: root.active ? 1 : 0.5
      height: root.flatWhenIdle && !root.active ? width : Math.max(width, root.height * (LiveBarsService.levels[Math.floor((index + 0.5) * LiveBarsService.bars / root.barCount)] ?? 0))

      Behavior on height { enabled: Motion.bar; NumberAnimation { duration: Motion.ms(70) } }

    }
  }
}
