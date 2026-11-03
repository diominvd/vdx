import QtQuick
import Quickshell.Services.Pipewire
import qs.components
import qs.config
import qs.kit

// Audio: output and input devices with their volume, then each application's
// stream.
KitFrame {
  id: root
  // rows already on show: a new one eases in (KitAppear)
  property KitSeen seen: KitSeen {}

  readonly property bool headphones: AudioService.headphones

  // Set while the popup is shown; the input level meter runs only then.
  property bool open: false
  signal closeRequested()

  // Live input level: the peak in dBFS mapped onto 0..1 over -60..0 dB.
  // PwNodePeakMonitor reports the cube root of the sample peak, so dBFS = 60·log10.
  readonly property real micLevel: {
    const peak = micPeak.peak;
    return peak > 0 ? Math.max(0, Math.min(1, (60 * Math.log10(peak) + 60) / 60)) : 0;
  }

  PwNodePeakMonitor {
    id: micPeak
    node: AudioService.source
    enabled: root.open && !(AudioService.source?.audio?.muted ?? true)
  }

  // ---- header ----
  KitHeader {
    icon: !AudioService.live || AudioService.muted ? "volume-x" : root.headphones ? "headphones" : "volume"
    iconColor: AudioService.live && !AudioService.muted ? Theme.foreground0 : Theme.muted
    title: "Audio"
    subtitle: !AudioService.sink ? "NO OUTPUT"
      : !AudioService.live ? "OFF"
      : AudioService.muted ? "OUTPUT MUTED"
      : "VOLUME " + AudioService.volume + "%"

    KitSwitch {
      anchors.verticalCenter: parent.verticalCenter
      checked: AudioService.live
      accessibleName: "Audio"
      disabled: !AudioService.sink?.audio && !AudioService.source?.audio
      onToggled: AudioService.setMuted(AudioService.live)
    }
  }

  KitLine {}

  // ---- output ----
  Column {
    width: parent.width
    spacing: Theme.gapMedium

    KitLabel {
      text: "OUTPUT"
      value: (AudioService.outputs.length === 0 ? "none found" : AudioService.outputNote).toUpperCase()
    }

    AudioDeviceDropdown {
      id: output
      entries: AudioService.outputs
      current: AudioService.outputKey
      onExpandedChanged: if (expanded) input.expanded = false
    }

    KitText {
      width: parent.width
      visible: AudioService.portError !== "" && AudioService.portErrorTarget === "output"
      text: AudioService.portError
      color: Theme.red
      wrapMode: Text.WordWrap
      font.pixelSize: Theme.fontSize - 1
    }

    AudioVolumeRow {
      node: AudioService.sink
      iconOn: root.headphones ? "headphones" : "volume"
    }
  }

  // ---- input ----
  Column {
    width: parent.width
    spacing: Theme.gapMedium

    KitLabel {
      text: "INPUT"
      value: (AudioService.inputs.length === 0 ? "none found" : AudioService.inputNote).toUpperCase()
    }

    AudioDeviceDropdown {
      id: input
      entries: AudioService.inputs
      current: AudioService.inputKey
      onExpandedChanged: if (expanded) output.expanded = false
    }

    KitText {
      width: parent.width
      visible: AudioService.portError !== "" && AudioService.portErrorTarget === "input"
      text: AudioService.portError
      color: Theme.red
      wrapMode: Text.WordWrap
      font.pixelSize: Theme.fontSize - 1
    }

    AudioVolumeRow {
      node: AudioService.source
      iconOn: "mic"
      iconOff: "mic-off"
    }

    // what the microphone hears right now, a thin bar under the slider: green, yellow near the top, red at clipping
    Rectangle {
      radius: Theme.pill(height)
      width: parent.width
      height: 3
      color: Theme.background3
      opacity: micPeak.enabled ? 1 : 0.4

      Rectangle {
        width: root.micLevel * parent.width
        height: parent.height
        radius: parent.radius
        color: root.micLevel > 0.92 ? Theme.red : root.micLevel > 0.75 ? Theme.yellow : Theme.green

        Behavior on width { enabled: Motion.controls; NumberAnimation { duration: Motion.ms(60) } }
      }
    }
  }

  // ---- applications: only while something plays ----
  Column {
    width: parent.width
    visible: AudioService.streams.length > 0
    spacing: Theme.gapMedium

    KitLabel { text: "APPLICATIONS (" + AudioService.streams.length + ")" }

    Repeater {
      model: AudioService.streams

      Column {
        id: stream
        required property var modelData

        // an app that starts playing eases in
        KitAppear { target: stream; seen: root.seen; key: String(stream.modelData.id) }

        width: parent.width
        spacing: Theme.gapSmall          // a caption over its slider

        KitText {
          width: parent.width
          text: AudioService.nameOf(modelData)
          elide: Text.ElideRight
          color: Theme.foreground2
          font.pixelSize: Theme.fontSize - 1
        }

        AudioVolumeRow { node: modelData }
      }
    }
  }

  KitLine {}

  KitButton {
    width: parent.width
    icon: "sliders"
    text: "Open settings"
    onClicked: {
      root.closeRequested();
      ShellIpc.call("shell", "open", ["sound"]);
    }
  }
}
