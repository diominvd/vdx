import QtQuick
import Quickshell.Widgets
import qs.config

// A segmented control: one track, a segment per choice; the one matching
// `current` is raised (filled, bold), the rest are plain text. Model:
// [{label, value}]. Takes the width it is given (KitRow wide); a segment is as wide as its label, the spare width shared evenly.
// Strict: a quiet outlined track, the picked segment a filled plate inset in it that glides to the next one picked.
// Material (Appearance › Controls): Material 3's connected button group — a pill
// per choice, 2 px apart with barely rounded inner corners, the picked one filled (Theme.primary).
Rectangle {
  id: root

  property var model: []
  property var current: null
  property bool disabled: false
  property bool boxed: false
  Component.onCompleted: boxed = Theme.boxed(parent)
  // each label measured in the font it is drawn in (the picked one is bold: the wider)
  readonly property int edge: m3 ? 0 : inset
  readonly property int join: m3 ? Theme.gapTight : 0
  readonly property bool kitFree: true
  property real kitShift: 0              // KitFrame: a footer's way down past a section's edge
  transform: Translate { y: root.kitShift }
  readonly property var natural: {
    const out = [];
    for (let i = 0; i < sizes.count; i++) out.push(Math.ceil(sizes.objectAt(i).advanceWidth) + 2 * Theme.gapLoose);
    return out;
  }
  readonly property real naturalSum: natural.reduce((a, b) => a + b, 0)
  // the narrowest the track can be without cutting a label (a row may give the rest to its hint)
  readonly property real minWidth: Math.min(Theme.controlWidth, naturalSum + 2 * edge + join * Math.max(0, natural.length - 1))
  // equal segments while every label fits its share; else each is as wide as its label needs, the spare width shared evenly, a shortage cut in proportion
  readonly property var widths: {
    const n = natural.length;
    const avail = width - 2 * edge - join * Math.max(0, n - 1);
    if (n === 0 || naturalSum <= 0) return [];
    // every label fits an equal share: the segments are equal
    if (avail >= n * Math.max.apply(null, natural)) return natural.map(() => avail / n);
    return natural.map(w => avail >= naturalSum ? w + (avail - naturalSum) / n : w * avail / naturalSum);
  }

  Instantiator {
    id: sizes
    model: root.model

    TextMetrics {
      required property var modelData
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSize
      font.weight: Theme.pickWeight
      text: modelData.label
    }
  }

  activeFocusOnTab: true
  enabled: !disabled && model.length > 0
  Accessible.role: Accessible.Grouping
  Accessible.name: "Choices"
  function move(step) {
    if (disabled || !model.length) return;
    const i = model.findIndex(c => c.value === current);
    picked(model[Math.max(0, Math.min(model.length - 1, i + step))].value);
  }
  Keys.onLeftPressed: move(-1)
  Keys.onRightPressed: move(1)
  Keys.onPressed: event => {
    if (disabled || !model.length) return;
    if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
      picked(model[event.key === Qt.Key_Home ? 0 : model.length - 1].value);
      event.accepted = true;
    }
  }

  signal picked(var value)

  // a click focuses it (the keys work) but draws no ring: the ring is for Tab
  property bool byMouse: false
  onActiveFocusChanged: if (!activeFocus && Window.active) byMouse = false     // the window losing focus keeps it

  readonly property bool m3: Theme.material
  readonly property int inset: m3 ? 0 : 3

  implicitWidth: Theme.controlWidth
  implicitHeight: Theme.controlHeight
  radius: Theme.radiusControl
  color: m3 ? Theme.clear : Theme.fillOn(boxed)
  border.width: m3 ? 0 : Theme.frameWidth
  border.color: Theme.controlLineRest
  opacity: disabled ? 0.4 : 1

  Rectangle {
    anchors { fill: parent; margins: -3 }
    radius: Theme.radiusFor(height)
    color: Theme.clear
    visible: root.activeFocus && !root.byMouse
    border.width: Theme.focusWidth
    border.color: Theme.focusRing
  }

  // the segments are cut to the outline's inside: material the pill, terminal the rounded frame
  ClippingRectangle {
    anchors { fill: parent; margins: root.m3 ? 0 : root.inset }
    radius: Math.max(0, root.radius - (root.m3 ? 0 : root.inset))
    color: Theme.clear

    // the picked segment's plate: it glides to the one picked, behind the labels
    Rectangle {
      readonly property int at: root.model.findIndex(c => c.value === root.current)
      visible: at >= 0 && !root.m3
      x: root.widths.slice(0, Math.max(0, at)).reduce((a, b) => a + b, 0)
      width: root.widths[at] ?? 0
      height: parent.height
      color: Theme.pickFill
      Behavior on x { enabled: Motion.controls; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
      Behavior on width { enabled: Motion.controls; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
    }

    Row {
      id: segments
      anchors.fill: parent
      spacing: root.join

      Repeater {
        model: root.model

        Rectangle {
          id: segment

          required property var modelData
          required property int index

          readonly property bool selected: modelData.value === root.current
          readonly property bool hovered: area.containsMouse && !root.disabled && !selected

          width: root.widths[index] ?? 0
          height: segments.height
          // Strict: only the enclosing track rounds the outside corners; shared edges stay
          // straight. Material: each is a pill, its inner corners barely rounded
          readonly property bool first: index === 0
          readonly property bool last: index === root.model.length - 1
          radius: 0
          topLeftRadius: root.m3 ? (first ? root.radius : Theme.radiusJoin) : 0
          bottomLeftRadius: topLeftRadius
          topRightRadius: root.m3 ? (last ? root.radius : Theme.radiusJoin) : 0
          bottomRightRadius: topRightRadius
          color: !root.m3 ? (hovered ? Theme.controlHover : Theme.clear)
               : selected ? Theme.primary : hovered ? Theme.hoverOn(root.boxed) : Theme.fillOn(root.boxed)

          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

          Row {
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - Theme.gapMedium)
            spacing: Theme.gapSmall

            KitText {
              id: label
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(implicitWidth, segment.width - Theme.gapMedium)
              elide: Text.ElideRight
              text: segment.modelData.label
              color: segment.selected ? (root.m3 ? Theme.inkOn(Theme.primary) : Theme.selectedText) : Theme.foreground2
              font.weight: segment.selected ? Theme.pickWeight : Font.Normal
            }
          }

          MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
              if (root.disabled) return;
              root.forceActiveFocus(Qt.MouseFocusReason);
              root.byMouse = true;
              if (!segment.selected) root.picked(segment.modelData.value);
            }
          }
        }
      }
    }
  }
}
