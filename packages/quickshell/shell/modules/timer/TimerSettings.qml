import QtQuick
import qs.config
import qs.kit

// Custom countdown presets, stored with the timer module's settings.
Column {
  id: root

  spacing: Theme.gapGroup

  readonly property var presets: ModuleSettings.get("timer", "presets", []) ?? []
  property int addedMinutes: -1
  property int removingMinutes: -1

  function addPreset() {
    const minutes = Number(input.text.trim());
    if (!Number.isInteger(minutes) || minutes < 1 || minutes > 1440 || presets.includes(minutes)) return;
    addedMinutes = minutes;
    ModuleSettings.set("timer", "presets", presets.concat([minutes]).sort((a, b) => a - b));
    input.text = "";
  }

  function removePreset(minutes) {
    removingMinutes = minutes;
  }

  function commitRemoval(minutes) {
    if (removingMinutes !== minutes) return;
    ModuleSettings.set("timer", "presets", presets.filter(value => value !== minutes));
    removingMinutes = -1;
  }

  function format(minutes) {
    const hours = Math.floor(minutes / 60), rest = minutes % 60;
    return hours > 0 ? hours + " h" + (rest > 0 ? " " + rest + " min" : "") : minutes + " min";
  }

  KitLabel { text: "COUNTDOWN PRESETS" }

  KitRow {
    wide: true
    label: "Add a preset"
    hint: "Enter a duration in minutes (1–1440)"
    Row {
      width: parent.width
      spacing: Theme.gapSmall

      KitInput {
        id: input
        width: parent.width - addButton.width - parent.spacing
        placeholder: "Minutes, e.g. 90"
        validator: IntValidator { bottom: 1; top: 1440 }
        onAccepted: root.addPreset()
      }
      KitButton { id: addButton; text: "Add"; onClicked: root.addPreset() }
    }
  }

  Flow {
    width: parent.width
    spacing: Theme.gapSmall

    Repeater {
      model: root.presets
      KitButton {
        id: chip
        required property int modelData
        text: root.format(modelData)
        icon: "x"
        opacity: root.addedMinutes === modelData ? 0 : root.removingMinutes === modelData ? 0 : 1
        scale: root.addedMinutes === modelData ? 0.92 : root.removingMinutes === modelData ? 0.92 : 1
        onClicked: root.removePreset(modelData)

        Component.onCompleted: if (root.addedMinutes === modelData) enter.start()

        ParallelAnimation {
          id: enter
          NumberAnimation { target: chip; property: "opacity"; to: 1; duration: Motion.controls ? Motion.quick : 0; easing.type: Motion.easing }
          NumberAnimation { target: chip; property: "scale"; to: 1; duration: Motion.controls ? Motion.quick : 0; easing.type: Motion.easing }
          onFinished: if (root.addedMinutes === chip.modelData) root.addedMinutes = -1
        }

        ParallelAnimation {
          id: leave
          running: root.removingMinutes === chip.modelData
          NumberAnimation { target: chip; property: "opacity"; to: 0; duration: Motion.controls ? Motion.quick : 0; easing.type: Motion.easing }
          NumberAnimation { target: chip; property: "scale"; to: 0.92; duration: Motion.controls ? Motion.quick : 0; easing.type: Motion.easing }
          onFinished: root.commitRemoval(chip.modelData)
        }
      }
    }
  }

  KitGrouper {}
}
