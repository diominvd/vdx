import QtQuick
import qs.config

// Reset in two steps: the first click asks ("Reset now?", for 3 s), the second one
// resets. Set `changed` (nothing to reset: disabled) and handle `reset`.
KitButton {
  id: root

  property bool changed: true
  property bool armed: false

  signal reset()

  icon: "rotate-ccw"
  text: armed ? qsTr("Reset now?") : qsTr("Reset")
  // The confirmation label should explain the action to assistive technology.
  accessibleName: armed ? qsTr("Confirm reset") : qsTr("Reset")
  Accessible.description: armed
    ? qsTr("Press again within three seconds to confirm reset")
    : qsTr("Requires a second activation to confirm reset")
  selected: armed
  disabled: !changed
  onChangedChanged: {
    armed = false;
    disarm.stop();
  }
  onClicked: {
    if (!armed) { armed = true; disarm.restart(); return; }
    armed = false;
    disarm.stop();
    root.reset();
  }

  Timer { id: disarm; interval: 3000; onTriggered: root.armed = false }
}
