import QtQuick
import Quickshell
import qs.components
import qs.apps.display
import qs.config
import qs.kit

// The display in brief: each monitor's scale, the GTK text size, and a button
// to the full window.
KitFrame {
  id: root

  readonly property var ds: DisplayService

  function pct(f) { return Math.round(f * 100) + "%"; }

  signal openWindow()

  KitHeader {
    icon: "monitor"
    title: "Display"
    subtitle: Format.count(ds.monitors.length, "MONITOR")
        + " · TEXT " + root.pct(ds.textFactor)
  }

  KitLine {}

  Column {
    width: parent.width
    spacing: Theme.sectionGap

    Repeater {
      model: root.ds.monitors

      Column {
        required property var modelData

        width: parent.width
        spacing: Theme.gapSmall

        KitLabel {
          text: modelData.name
          value: root.pct(root.ds.stopAt(modelData, scaleSlider.pressed ? scaleSlider.dragValue : scaleSlider.value))
        }

        KitSlider {
          id: scaleSlider
          width: parent.width
          enabled: !root.ds.busy
          snaps: root.ds.stops(modelData)
          value: root.ds.scalePos(modelData)
          onReleased: value => root.ds.setScale(modelData.name, root.ds.stopAt(modelData, value))
        }
      }
    }

    KitLine {}

    KitLabel { text: "TEXT SIZE"; value: root.pct(root.ds.textFactor) }

    KitChoices {
      width: parent.width
      stretch: true
      disabled: root.ds.busy
      model: root.ds.textScales.map(f => ({ label: root.pct(f), value: f }))
      current: root.ds.textFactor
      busyValue: root.ds.working === "text" ? root.ds.pending : null
      onPicked: value => root.ds.setText(value)
    }

    KitText {
      visible: root.ds.error !== ""
      width: parent.width
      text: root.ds.error
      color: Theme.red
      wrapMode: Text.WordWrap
    }
  }

  KitLine {}

  KitButton {
    width: parent.width
    icon: "sliders"
    text: "Open settings"
    onClicked: {
      root.openWindow();
      ShellIpc.call("shell", "open", ["displays"]);
    }
  }
}
