import QtQuick
import Quickshell.Services.Pipewire
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
      accessibleName: "Live audio output"
      anchors.verticalCenter: parent.verticalCenter
      checked: AudioService.live
      onToggled: AudioService.setMuted(AudioService.live)
    }
  }

  KitLine {}

  // ---- output ----
  Column {
    width: parent.width
    spacing: Theme.gapGroup

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

    AudioVolumeRow {
      node: AudioService.sink
      iconOn: root.headphones ? "headphones" : "volume"
    }
  }

  KitLine {}

  // ---- input ----
  Column {
    width: parent.width
    spacing: Theme.gapGroup

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

    AudioVolumeRow {
      node: AudioService.source
      iconOn: "mic"
      iconOff: "mic-off"
    }

    // what the microphone hears right now: green, yellow near the top, red at clipping
    Column {
      width: parent.width
      spacing: 5

      KitInfo {
        label: "Level"
        value: micPeak.enabled ? Math.round(root.micLevel * 100) + "%" : "muted"
        valueColor: micPeak.enabled ? Theme.foreground2 : Theme.gray
      }

      Rectangle {
        radius: Theme.pill(height)
        width: parent.width
        height: 4
        color: Theme.background3

        Rectangle {
          width: root.micLevel * parent.width
          height: parent.height
          color: root.micLevel > 0.92 ? Theme.red : root.micLevel > 0.75 ? Theme.yellow : Theme.green

          Behavior on width { enabled: Motion.controls; NumberAnimation { duration: Motion.ms(60) } }
        }
      }
    }
  }

  KitLine {}

  // ---- applications ----
  Column {
    width: parent.width
    spacing: Theme.gapMedium

    KitLabel { text: "APPLICATIONS (" + AudioService.streams.length + ")" }

    KitText {
      visible: AudioService.streams.length === 0
      text: "Nothing is playing."
      color: Theme.muted
      font.pixelSize: Theme.fontSize - 1
    }

    Repeater {
      model: AudioService.streams

      Column {
        id: stream
        required property var modelData

        // an app that starts playing eases in
        KitAppear { target: stream; seen: root.seen; key: String(stream.modelData.id) }

        width: parent.width
        spacing: Theme.gapMedium          // a caption over its slider

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
}
