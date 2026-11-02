import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.kit

// While recording, when the focused monitor's bar has no Capture module to
// show it: a small panel with the elapsed time and Stop (Super+Shift+S stops
// too), in the first corner the recorded area leaves free — it is not in the video.
// Not on the island with its recording live activity: that one has Pause and Stop.
Variants {
  readonly property bool inIsland: Theme.island && ShellSettings.liveEnabled && ShellSettings.liveOn("recording")
  model: CaptureService.recording && CaptureService.recordStarted > 0 && !inIsland
    ? Quickshell.screens.filter(s => s.name === (Hyprland.focusedMonitor?.name ?? s.name)
                                     && !CaptureService.faceScreens.includes(s.name)).slice(0, 1)
    : []

  PanelWindow {
    id: root

    required property var modelData

    readonly property int gap: 16
    // the corner, picked once: bottom right, bottom left, top right, top left
    readonly property var corner: {
      const r = CaptureService.recordRect, s = modelData;
      const w = Theme.popupWidth, h = panel.implicitHeight, top = Theme.barEdge + gap;
      const spots = [
        { right: true,  bottom: true, x: s.x + s.width - gap - w, y: s.y + s.height - gap - h },
        { right: false, bottom: true, x: s.x + gap,               y: s.y + s.height - gap - h },
        { right: true,  bottom: false, x: s.x + s.width - gap - w, y: s.y + top },
        { right: false, bottom: false, x: s.x + gap,               y: s.y + top }
      ];
      const clear = c => c.x + w <= r.x || c.x >= r.x + r.width || c.y + h <= r.y || c.y >= r.y + r.height;
      return spots.find(clear) ?? spots[0];
    }

    screen: modelData
    anchors { right: corner.right; left: !corner.right; bottom: corner.bottom; top: !corner.bottom }
    margins { right: gap; left: gap; bottom: gap; top: Theme.barEdge + gap }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-recording"
    implicitWidth: Theme.popupWidth
    implicitHeight: panel.implicitHeight
    color: "transparent"

    // the popups' frame: a header with the time and Stop, then where it goes
    KitFrame {
      id: panel

      anchors.fill: parent

      KitHeader {
        icon: "circle"
        iconColor: Theme.red
        title: "Recording"
        subtitle: CaptureService.elapsedText + " · " + CaptureService.recordFps + " FPS"
          + (CaptureService.recordAudio !== "off" ? " · " + CaptureService.recordAudio.toUpperCase() : "")

        KitButton {
          icon: CaptureService.paused ? "play" : "pause"
          iconFilled: true
          iconTint: Theme.foreground1
          onClicked: CaptureService.togglePause()
        }

        KitButton {
          icon: "square"
          iconWithText: true
          iconFilled: true
          text: "Stop"
          onClicked: CaptureService.stopRecording()
        }
      }

      KitLine {}

      KitInfo {
        label: "Saves to"
        value: CaptureService.recordAsk ? "asks when you stop" : CaptureService.recordFile.replace(Quickshell.env("HOME"), "~")
      }
    }
  }
}
