import QtQuick
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
  property string accessibleName: ""
  property color tint: Theme.foreground0
  property var snaps: []
  property bool ticks: true              // false: the stops still snap, no marks
  property var spectrum: []              // colours laid along the track, instead of the fill

  // the default tint takes the accent (Appearance › Accent › Sliders); a
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
  readonly property real track: 12            // Material: the track's height
  readonly property real gap: 5               // Material: the space on each side of the handle
  readonly property real handleX: shown * (width - knobSize)

  signal moved(real value)
  signal released(real value)

  function nearest(v) {
    return snaps.length === 0 ? v : snaps.reduce((best, s) => Math.abs(s - v) < Math.abs(best - v) ? s : best, snaps[0]);
  }

  function send(v) {
    // A compact/hidden layout can temporarily give the slider zero width.
    // Ignore invalid coordinates instead of propagating NaN into the value.
    if (!isFinite(v)) return;
    dragValue = nearest(Math.max(0, Math.min(1, v)));
    moved(dragValue);
  }

  function keyboardStep(delta) {
    if (!enabled) return;
    // Step from the position currently shown, not only the externally supplied
    // value: a caller may apply changes asynchronously or debounce updates.
    const current = shown;
    let next;
    if (snaps.length > 0) {
      let closest = 0;
      for (let i = 1; i < snaps.length; i++)
        if (Math.abs(snaps[i] - current) < Math.abs(snaps[closest] - current)) closest = i;
      next = snaps[Math.max(0, Math.min(snaps.length - 1, closest + delta))];
    } else {
      next = Math.max(0, Math.min(1, current + delta * 0.01));
    }
    send(next);
    letGo(dragValue);
  }

  activeFocusOnTab: enabled
  Accessible.role: Accessible.Slider
  Accessible.name: accessibleName !== "" ? accessibleName : qsTr("Slider")
  Accessible.description: Math.round(shown * 100) + "%"
  Keys.onLeftPressed: event => { keyboardStep(-1); event.accepted = true; }
  Keys.onDownPressed: event => { keyboardStep(-1); event.accepted = true; }
  Keys.onRightPressed: event => { keyboardStep(1); event.accepted = true; }
  Keys.onUpPressed: event => { keyboardStep(1); event.accepted = true; }
  Keys.onPressed: event => {
    if (event.key === Qt.Key_Home) { if (enabled) { send(0); letGo(dragValue); } event.accepted = true; }
    else if (event.key === Qt.Key_End) { if (enabled) { send(1); letGo(dragValue); } event.accepted = true; }
  }

  implicitWidth: 120
  implicitHeight: m3 ? 28 : 18
  opacity: enabled ? 1 : 0.4

  Rectangle {
    visible: !root.m3
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
        model: root.spectrum

        Rectangle {
          required property color modelData
          width: parent.width / root.spectrum.length
          height: parent.height
          color: modelData
        }
      }
    }

    Rectangle {
      visible: root.spectrum.length === 0
      width: root.shown * parent.width
      height: parent.height
      radius: parent.radius
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
      visible: !root.m3
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
      radius: 2
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
    visible: !root.m3
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

  Rectangle {
    anchors.fill: parent
    color: Theme.clear
    radius: Theme.radiusControl
    border.width: root.activeFocus ? 2 : 0
    border.color: Theme.foreground0
    z: 1
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    preventStealing: true
    cursorShape: Qt.PointingHandCursor
    onPressed: mouse => {
      if (width <= 0) return;
      root.forceActiveFocus();
      root.send(mouse.x / width);
    }
    onPositionChanged: mouse => {
      if (pressed && width > 0) root.send(mouse.x / width);
    }
    onReleased: root.letGo(root.dragValue)
    onCanceled: root.letGo(root.dragValue)   // a click the page took over still counts
  }
}
