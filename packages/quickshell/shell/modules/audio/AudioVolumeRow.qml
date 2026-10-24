import QtQuick
import qs.config
import qs.kit

// Mute button, volume slider and percentage for one Pipewire node.
KitSliderRow {
  id: root

  property var node: null
  property string iconOn: "volume"
  property string iconOff: "volume-x"

  readonly property var audio: node?.audio ?? null
  readonly property bool muted: audio?.muted ?? false

  enabled: !!audio
  clickable: true
  accessibleName: muted ? "Unmute audio" : "Mute audio"
  icon: muted ? iconOff : iconOn
  iconTint: muted ? Theme.red : Theme.foreground0
  value: audio?.volume ?? 0
  text: audio ? Math.round(audio.volume * 100) + "%" : "—"
  dimmed: muted
  onMoved: value => AudioService.setVolume(node, value)
  onIconClicked: AudioService.toggleMute(node)
}
