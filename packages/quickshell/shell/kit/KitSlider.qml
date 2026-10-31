import QtQuick
import Quickshell.Widgets
import qs.config

// Thin slider: a 3px track, the filled part in `tint`, a round knob; with
// Appearance › Controls › Material it is Material 3's: a thick track split by a
// bar handle, stops as dots inside the track. It never
// writes `value` itself: drag and click emit moved(value) for live
// changes (volume), and released(value) fires once when a drag ends (seeking).
// While pressed it shows the pointer position (`shown`).
// `snaps` (0..1 each, ascending): the stops the knob locks to, drawn as ticks;
// Empty: continuous. The wheel is left to the page: it scrolls, never slides.
Item {
  id: root

  property real value: 0                 // 0..1
  property bool dimmed: false
  property color tint: Theme.foreground0
  property var snaps: []
  property bool ticks: true              // false: the stops still snap, no marks
  property var spectrum: []              // colours laid along the track as a smooth ramp, instead of the fill
  property bool plate: false             // Strict: two tonal segments with a mark between them
  property string text: ""               // a plate carries its reading inside, at the right

  // the default tint takes the accent (Appearance › Colours › Sliders); a
  // state colour passed in (a load, a battery) keeps its own
  readonly property bool accented: !dimmed && tint === Theme.foreground0 && Theme.accentOn("sliders")
  readonly property color fill: dimmed ? Theme.gray : accented ? Theme.accent : tint
  readonly property bool pressed: area.pressed
  property real dragValue: 0
  // let go: the released position stays shown until the value follows it (an
  // applied change is async: a scale, brightness), or for 2 s if it never does
  property real held: -1
  readonly property real shown: Math.max(0, Math.min(1, pressed ? dragValue : held >= 0 ? held : value))
  onValueChanged: held = -1
  Timer { id: holdTimer; interval: 2000; onTriggered: root.held = -1 }
  function letGo(v) { held = v; holdTimer.restart(); released(v); }
  readonly property real knobSize: m3 ? 4 : 12
  readonly property bool m3: Theme.material && spectrum.length === 0
  readonly property bool splitPlate: !m3 && spectrum.length === 0 && ShellSettings.segmentedSliders
  readonly property bool flat: splitPlate || (plate && !m3)           // Strict plates; colour ramps stay thin
  readonly property real plateGap: splitPlate && shown > 0 && shown < 1 ? 8 : 0
  readonly property real plateEdge: shown * (width - plateGap)
  readonly property real track: 12            // Material: the track's height
  readonly property real gap: 5               // Material: the space on each side of the handle
  readonly property real handleX: shown * (width - knobSize)

  property string accessibleName: "Level"
  property real keyboardStep: 0.05
  activeFocusOnTab: true
  Accessible.role: Accessible.Slider
  Accessible.name: accessibleName
  Accessible.description: Math.round(shown * 100) + "%"
  function adjust(step) {
    if (!enabled || dimmed) return;
    let next;
    if (snaps.length) {
      const choices = snaps.filter(s => step > 0 ? s > shown + 0.001 : s < shown - 0.001);
      next = choices.length ? (step > 0 ? choices[0] : choices[choices.length - 1]) : shown;
    } else next = Math.max(0, Math.min(1, shown + step * keyboardStep));
    send(next);
    letGo(next);
  }
  Keys.onLeftPressed: adjust(-1)
  Keys.onRightPressed: adjust(1)
  Accessible.onIncreaseAction: adjust(1)
  Accessible.onDecreaseAction: adjust(-1)

  Rectangle {
    anchors { fill: parent; margins: -3 }
    radius: Theme.radiusControl
    visible: root.activeFocus
    color: Theme.clear
    border.width: Theme.focusWidth
    border.color: Theme.focusRing
  }

  signal moved(real value)
  signal released(real value)

  function nearest(v) {
    return snaps.length === 0 ? v : snaps.reduce((best, s) => Math.abs(s - v) < Math.abs(best - v) ? s : best, snaps[0]);
  }

  function send(v) {
    dragValue = nearest(Math.max(0, Math.min(1, v)));
    moved(dragValue);
  }

  // set once: whether it sits in a Settings box (a walk up, not a binding)
  property bool boxed: false
  Component.onCompleted: boxed = Theme.boxed(parent)

  implicitWidth: 120
  implicitHeight: m3 ? 28 : flat ? 36 : 18
  opacity: enabled ? 1 : 0.4

  KitGlow {
    z: -1
    target: "sliders"
    lit: !root.m3 && !root.flat && root.spectrum.length === 0 && !root.dimmed && root.shown > 0
    anchors.verticalCenter: parent.verticalCenter
    width: root.shown * parent.width
    height: 3
    tint: root.fill
    radius: Theme.pill(height)
  }

  ClippingRectangle {
    visible: !root.m3 && !root.flat
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: 3
    radius: Theme.pill(height)
    color: Theme.background3
    clip: true

    // a spectrum (a colour picker's ramp): the track is its colours, no fill
    Row {
      visible: root.spectrum.length > 0
      width: parent.width
      height: parent.height
      Repeater {
        model: Math.max(root.spectrum.length - 1, 0)

        Rectangle {
          required property int index
          width: parent.width / (root.spectrum.length - 1)
          height: parent.height
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.spectrum[index] }
            GradientStop { position: 1; color: root.spectrum[index + 1] }
          }
        }
      }
    }

    Rectangle {
      visible: root.spectrum.length === 0
      width: root.shown * parent.width
      height: parent.height
      radius: Theme.pill(height)
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: root.fill }
        GradientStop { position: 1; color: root.accented ? Theme.accentEnd : root.fill }
      }
    }
  }

  // a stop: a tick centred on the knob's position at that value
  Repeater {
    id: stops
    // at most 11 marks: a long run of stops shows every n-th (and the last); it still snaps to each
    model: {
      if (!root.ticks) return [];
      const s = root.snaps, step = Math.ceil((s.length - 1) / 10);
      return step <= 1 ? s : s.filter((v, i) => i % step === 0 || i === s.length - 1);
    }

    Rectangle {
      required property real modelData
      visible: !root.m3 && !root.flat
      x: modelData * (root.width - root.knobSize) + root.knobSize / 2 - 1
      anchors.verticalCenter: parent.verticalCenter
      width: 2
      height: 10
      radius: Theme.pill(width)
      color: Theme.gray
    }
  }

  // ---- Material 3: active track | gap | handle | gap | inactive track ----
  Rectangle {
    visible: root.m3
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(0, root.handleX - root.gap)
    height: root.track
    radius: Theme.pill(height)
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0; color: root.fill }
      GradientStop { position: 1; color: root.accented ? Theme.accentEnd : root.fill }
    }
  }

  Rectangle {
    visible: root.m3
    anchors.verticalCenter: parent.verticalCenter
    x: Math.min(root.width, root.handleX + root.knobSize + root.gap)
    width: Math.max(0, root.width - x)
    height: root.track
    radius: Theme.pill(height)
    color: Theme.background3
  }

  // stops: a dot per shown stop (none under the handle), and one at the end
  Repeater {
    model: !root.m3 ? [] : root.ticks && root.snaps.length > 0 ? stops.model : [1]

    Rectangle {
      required property real modelData
      readonly property real cx: modelData * (root.width - root.knobSize) + root.knobSize / 2
      visible: Math.abs(cx - (root.handleX + root.knobSize / 2)) > root.gap + 3 && cx > 4 && cx < root.width - 4 || modelData === 1 && root.shown < 0.97
      x: Math.max(3, Math.min(root.width - 7, cx - 2))
      anchors.verticalCenter: parent.verticalCenter
      width: 4
      height: 4
      radius: Theme.pill(height)
      color: cx < root.handleX ? Theme.background0 : root.fill
      opacity: 0.8
    }
  }

  Rectangle {
    visible: root.m3
    anchors.verticalCenter: parent.verticalCenter
    x: root.handleX
    width: root.knobSize
    height: area.containsMouse || root.pressed ? root.track + 16 : root.track + 12
    radius: Theme.pill(width)
    color: root.fill
    Behavior on height { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
  }

  Rectangle {
    visible: !root.m3 && !root.flat
    readonly property int size: area.containsMouse || root.pressed ? 14 : 12
    width: size
    height: size
    radius: Theme.pill(size)
    Behavior on width { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
    Behavior on height { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
    anchors.verticalCenter: parent.verticalCenter
    x: root.shown * (root.width - width)
    color: root.fill
    border.width: 2
    border.color: Theme.background0
  }

  // ---- Strict plate: choose the split style or the original continuous track ----
  Rectangle {
    visible: root.flat && !root.splitPlate
    anchors.fill: parent
    radius: Theme.radiusControl
    color: Theme.fillOn(root.boxed)
  }

  Rectangle {
    visible: root.flat && !root.splitPlate
    width: root.plateEdge
    height: parent.height
    radius: Math.min(Theme.radiusControl, width / 2)
    color: root.dimmed ? Theme.controlHover : Theme.mix(Theme.pickFill, Theme.foreground0, 0.14)
  }

  Rectangle {
    visible: root.flat && !root.splitPlate && Theme.frameWidth > 0
    anchors.fill: parent
    radius: Theme.radiusControl
    color: Theme.clear
    border.width: Theme.frameWidth
    border.color: Theme.controlLineRest
  }

  Rectangle {
    visible: root.splitPlate
    x: root.plateEdge + root.plateGap
    width: Math.max(0, parent.width - x)
    height: parent.height
    radius: Theme.radiusControl
    color: Theme.background3
  }

  Rectangle {
    visible: root.splitPlate
    width: root.plateEdge
    height: parent.height
    radius: Theme.radiusControl
    color: root.dimmed ? Theme.controlHover
      : root.accented ? Theme.mix(Theme.background0, Theme.accent, 0.28)
      : Theme.mix(Theme.pickFill, Theme.foreground0, 0.14)
  }

  // The short white mark sits in the gap between the two independent segments.
  Rectangle {
    visible: root.splitPlate && root.plateGap > 0
    x: root.plateEdge + (root.plateGap - width) / 2
    anchors.verticalCenter: parent.verticalCenter
    width: 3
    height: Math.min(28, parent.height - 12)
    radius: Theme.pill(width)
    color: Theme.foreground0
  }

  // A spectrum keeps its continuous colour ramp and lights only the part before the knob.
  Item {
    visible: root.splitPlate && root.spectrum.length > 0
    anchors.fill: parent
    clip: true

    Item {
      width: root.plateEdge
      height: parent.height
      clip: true

      Row {
        width: root.width
        height: parent.height

        Repeater {
          model: Math.max(root.spectrum.length - 1, 0)

          Rectangle {
            required property int index
            width: root.width / (root.spectrum.length - 1)
            height: parent.height
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0; color: root.spectrum[index] }
              GradientStop { position: 1; color: root.spectrum[index + 1] }
            }
          }
        }
      }
    }
  }

  Item {
    visible: root.splitPlate
    anchors.fill: parent

    // stop marks are tucked into the inactive segment, past its rounded end
    Repeater {
      model: root.flat ? stops.model : []

      Rectangle {
        required property real modelData
        readonly property real cx: modelData * (root.width - root.plateGap)
        visible: cx > root.plateEdge + root.plateGap + 8 && cx < root.width - 56
        x: cx - 1.5
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: 3
        radius: Theme.pill(height)
        color: Theme.muted
      }
    }

    KitText {
      anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
      text: root.text
      color: root.dimmed ? Theme.gray : Theme.foreground2
      font.pixelSize: Theme.fontSize - 1
    }
  }

  Rectangle {
    visible: root.flat && !root.splitPlate && root.plateEdge > 18
    x: root.plateEdge - 10
    anchors.verticalCenter: parent.verticalCenter
    width: 2
    height: 16
    radius: Theme.pill(height)
    color: root.dimmed ? Theme.gray : root.accented ? Theme.accent : Theme.foreground0
  }

  Item {
    visible: root.flat && !root.splitPlate
    anchors.fill: parent

    Repeater {
      model: root.ticks ? stops.model : []
      Rectangle {
        required property real modelData
        readonly property real cx: modelData * root.width
        visible: cx > root.plateEdge + 8 && cx < root.width - 56
        x: cx - 1.5
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: 3
        radius: Theme.pill(height)
        color: Theme.muted
      }
    }

    KitText {
      anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
      text: root.text
      color: root.dimmed ? Theme.gray : Theme.foreground2
      font.pixelSize: Theme.fontSize - 1
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    preventStealing: true
    cursorShape: Qt.PointingHandCursor
    onPressed: mouse => root.send(mouse.x / width)
    onPositionChanged: mouse => { if (pressed) root.send(mouse.x / width); }
    onReleased: root.letGo(root.dragValue)
    onCanceled: root.letGo(root.dragValue)   // a click the page took over still counts
  }
}
