import QtQuick

// Reset in two steps: the first click asks ("Sure?", for 3 s), the second one
// resets. Set `changed` (nothing to reset: disabled) and handle `reset`.
KitButton {
  id: root

  property bool changed: true
  property bool armed: false

  signal reset()

  icon: "rotate-ccw"
  text: armed ? "Sure?" : "Reset"
  disabled: !changed
  onChangedChanged: armed = false
  onClicked: {
    if (!armed) { armed = true; disarm.restart(); return; }
    armed = false;
    root.reset();
  }

  Timer { id: disarm; interval: 3000; onTriggered: root.armed = false }
}
