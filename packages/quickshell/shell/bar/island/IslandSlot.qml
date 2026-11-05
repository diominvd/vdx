import QtQuick
import qs.bar
import qs.components
import qs.config
import qs.kit

// One module in the resting pill. With Rings in the pill (Bar look › Style) a module
// whose value has a whole is drawn as its complication (bar/Complications.qml, ring 22);
// a pointer resting on it 150 ms adds its words beside the rings (the peek);
// its face stays under the rings, unseen, so the click, the wheel and the popup are the
// module's own, as on the strip. A module with no whole (the workspaces, a layout, the
// clock) and a separator keep their face of words.
Item {
  id: slot

  required property string modelData
  property var modules: ({})
  signal settings(string id)
  signal peeked(bool on)                         // the pill grows taller for it

  readonly property bool separator: BarLayout.isSeparator(modelData)
  readonly property var rings: ShellSettings.pillRings && !separator ? Complications.of(modelData) : []
  readonly property bool drawn: rings.length > 0
  // the glance: the pointer rests on the rings a moment and their words show beside them
  property bool peek: false
  onPeekChanged: peeked(peek)
  // the ring grows from the pill's size to the peek's
  property real ringSize: peek ? Theme.ringPeek : Theme.ringPill
  Behavior on ringSize { enabled: Motion.island; NumberAnimation { duration: Motion.normal; easing.type: Motion.morph } }

  anchors.verticalCenter: parent ? parent.verticalCenter : undefined
  implicitWidth: drawn ? dial.implicitWidth : face.implicitWidth
  implicitHeight: drawn ? ringSize : face.implicitHeight

  Component { id: separatorFace; Separator {} }

  Loader {
    id: face
    width: slot.drawn ? slot.width : implicitWidth
    height: slot.drawn ? slot.height : implicitHeight
    sourceComponent: slot.separator ? separatorFace : (slot.modules[slot.modelData] ?? null)
    // under the rings the face only takes the pointer
    opacity: slot.drawn ? 0 : 1
  }

  Row {
    id: dial
    visible: slot.drawn
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.gapSmall

    // by count, so a new value only moves the ring (it eases), never remakes it
    Repeater {
      model: slot.rings.length
      KitRing {
        required property int index
        readonly property var spec: slot.rings[index] ?? ({})
        anchors.verticalCenter: parent.verticalCenter
        size: Math.round(slot.ringSize)
        kind: spec.kind ?? "fill"
        value: spec.value ?? 0
        text: spec.text ?? ""
        icon: spec.icon ?? ""
        tint: spec.tint ?? Theme.foreground1
        on: spec.on ?? true
        quiet: spec.quiet ?? false
        steps: spec.steps ?? 5
      }
    }

    KitText {
      anchors.verticalCenter: parent.verticalCenter
      visible: slot.peek
      text: Complications.line(slot.rings)
      color: Theme.muted
      font.pixelSize: Theme.fontSize - 1
    }
  }

  HoverHandler {
    id: hover
    enabled: slot.drawn
    onHoveredChanged: {
      if (hovered) wait.restart();
      else { wait.stop(); slot.peek = false; }
    }
  }
  Timer { id: wait; interval: 150; onTriggered: slot.peek = true }

  // a right click takes its options; without this it falls through to the island
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    enabled: !slot.separator
    onClicked: if (ShellSettings.barRightSettings) slot.settings(slot.modelData)
  }
}
