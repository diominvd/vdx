import QtQuick
import Quickshell.Widgets
import qs.bar
import qs.bar.island
import qs.config
import qs.kit
import qs.modules.audio
import qs.modules.brightness

ClippingRectangle {
  id: root
  required property string widgetId
  property string fmt: "Tall"
  property bool preview: false
  readonly property var node: widgetId === "volume" ? AudioService.sink : AudioService.source
  readonly property real level: widgetId === "volume" || widgetId === "microphone" ? node?.audio?.volume ?? 0
    : widgetId === "brightness" ? BrightnessService.brightness / 100
    : widgetId === "night" ? (BrightnessService.temperature - BrightnessService.temperatureMin) / (BrightnessService.temperatureMax - BrightnessService.temperatureMin)
    : (BrightnessService.gamma - BrightnessService.gammaMin) / (100 - BrightnessService.gammaMin)
  readonly property bool available: widgetId === "volume" || widgetId === "microphone" ? !!node?.audio : widgetId !== "brightness" || BrightnessService.available
  readonly property string reading: !available ? "—" : widgetId === "night" ? (BrightnessService.temperature / 1000).toFixed(1) + "K" : String(Math.round(level * 100))
  readonly property bool muted: (widgetId === "volume" || widgetId === "microphone") && (node?.audio?.muted ?? false)
  readonly property color ink: muted ? Theme.gray : widgetId === "night" ? Theme.orange : Theme.accentFor("sliders", Theme.foreground0)
  implicitHeight: Math.max(128, Theme.fontSize * 10)
  radius: Theme.radiusFor(Math.min(width, height))
  color: Theme.controlFill
  border.width: Theme.frameWidth
  border.color: Theme.controlLineRest
  function setLevel(v) {
    if (preview || !available) return;
    v = Math.max(0, Math.min(1, v));
    if (widgetId === "volume" || widgetId === "microphone") AudioService.setVolume(node, v);
    else if (widgetId === "brightness") BrightnessService.setBrightness(v * 100);
    else if (widgetId === "night") BrightnessService.setTemperature(BrightnessService.temperatureMin + v * (BrightnessService.temperatureMax - BrightnessService.temperatureMin));
    else BrightnessService.setGamma(BrightnessService.gammaMin + v * (100 - BrightnessService.gammaMin));
  }
  Rectangle {
    anchors.bottom: parent.bottom
    width: parent.width
    height: parent.height * Math.max(0, Math.min(1, root.level))
    color: root.ink
    Behavior on height { enabled: Motion.controls && !adjust.pressed; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
  }
  KitText {
    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.gapWide }
    text: root.reading
    font.pixelSize: Theme.fontSize + 2
    color: root.level > 0.8 ? Theme.inkOn(root.ink) : Theme.foreground0
  }
  KitIcon {
    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.gapWide }
    name: root.muted ? root.widgetId === "volume" ? "volume-x" : "mic-off" : HubWidgets.icon(root.widgetId)
    size: 17
    tint: root.level > 0.16 ? Theme.inkOn(root.ink) : Theme.foreground0
  }
  MouseArea {
    id: adjust
    anchors.fill: parent
    enabled: !root.preview && root.available
    preventStealing: true
    cursorShape: Qt.PointingHandCursor
    onPressed: mouse => { root.setLevel(1 - mouse.y / height); }
    onPositionChanged: mouse => { if (pressed) root.setLevel(1 - mouse.y / height); }
    onWheel: wheel => { root.setLevel(root.level + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)); wheel.accepted = true; }
  }
  MouseArea {
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    height: 34
    enabled: !root.preview && root.available && ["volume", "microphone", "brightness"].includes(root.widgetId)
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (root.widgetId === "brightness") BrightnessService.setNight(!BrightnessService.nightActive);
      else AudioService.toggleMute(root.node);
    }
  }
}
