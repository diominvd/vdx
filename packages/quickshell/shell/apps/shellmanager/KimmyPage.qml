import QtQuick
import qs.config
import qs.kit
import qs.apps.companion

// Kimmy: the pet ball. A live Kimmy in the look as set (it watches the pointer over the
// well, a click makes it hop), Reset the look under it, then its options
// (`CompanionSettings`, the one place with the rows: body, eyes, halo, home, behaviour,
// voice). The header's Reset brings every default back. The ball lives only while the
// page does (the window's Loader), so nothing runs once it is closed.
KitColumn {
  id: root

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "bot"
  readonly property string title: "Kimmy"
  readonly property string description: "The pet ball: its look, home, temper and voice."
  readonly property var jumps: [
    { key: "preview", label: "Preview", y: previewLabel.y },
    { key: "body", label: "Body", y: settings.y + settings.bodyY },
    { key: "eyes", label: "Eyes", y: settings.y + settings.eyesY },
    { key: "halo", label: "Halo", y: settings.y + settings.haloY },
    { key: "home", label: "Home", y: settings.y + settings.homeY },
    { key: "behaviour", label: "Behaviour", y: settings.y + settings.behaviourY },
    { key: "voice", label: "Voice", y: settings.y + settings.voiceY }
  ]

  // the header's Reset
  readonly property bool changed: ModuleSettings.changed("companion")
  function reset() { ModuleSettings.reset("companion", null); }

  readonly property bool shown: ModuleSettings.get("companion", "enabled", true)
  readonly property string side: ModuleSettings.get("companion", "side", "right")

  // ---- the live preview ----
  KitLabel {
    id: previewLabel
    text: "PREVIEW"
    value: !root.shown ? "HIDDEN" : root.side === "left" ? "LEFT CORNER" : "RIGHT CORNER"
  }

  Rectangle {
    id: well
    width: parent.width
    height: 232
    radius: Theme.radiusControl
    color: Theme.background0
    clip: true                                   // a large halo fades out at the edge
    Accessible.role: Accessible.Graphic
    Accessible.name: "Kimmy, a live preview of its look"

    // the stage: the ball and its ground shadow, as the window draws them
    Item {
      id: stage
      width: Math.round(ball.size / 0.92)
      height: width
      anchors.centerIn: parent
      anchors.verticalCenterOffset: -Theme.gapMedium

      Rectangle {
        readonly property real far: Math.min(1, Math.max(0, -ball.hopY) / (stage.height * 2))
        visible: ball.style.shadowOn
        width: stage.width * 0.7 * (1 - far * 0.55)
        height: stage.height * 0.12 * (1 - far * 0.3)
        radius: height / 2
        x: (stage.width - width) / 2
        y: stage.height * 0.93
        color: Qt.rgba(0, 0, 0, 1)
        opacity: 0.2 * (1 - far * 0.7)
      }

      CompanionBall {
        id: ball
        anchors.centerIn: parent
        size: 110
        style: CompanionStyle {}
        opacity: root.shown ? 1 : 0.45
        Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
        // the pointer over the well, in the ball's own terms (-1 … 1 each way)
        pointerNear: hover.hovered
        pointerX: hover.hovered ? Math.max(-1, Math.min(1, (hover.point.position.x - well.width / 2) / (well.width / 2))) : 0
        pointerY: hover.hovered ? Math.max(-1, Math.min(1, (hover.point.position.y - well.height / 2) / (well.height / 2))) : 0
      }
    }

    HoverHandler { id: hover }

    TapHandler {
      onTapped: {
        ball.wake();
        ball.hopBy(0.3);
        ball.express("happy", 900);
      }
    }
  }

  KitRow {
    label: "Reset the look"
    hint: "Back to the white ball"

    KitResetButton {
      changed: ModuleSettings.changed("companion", settings.lookKeys)
      onReset: ModuleSettings.reset("companion", settings.lookKeys)
    }
  }

  KitLine {}

  CompanionSettings { id: settings; width: parent.width }

  KitGrouper {}
}
