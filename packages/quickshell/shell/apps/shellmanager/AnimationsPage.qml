import QtQuick
import qs.config
import qs.kit

// Animations: how the shell moves (Motion reads these, ShellSettings keeps
// them). GENERAL — all on / off, the speed, a sample that plays at it; PARTS —
// each part of the shell on its own: bar popups (fade, slide, grow), the
// underline under an open module, panels, controls, the bar, these pages and
// the lock screen.
Column {
  id: root

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "zap"
  readonly property string title: "Animations"
  readonly property string subtitle: !ShellSettings.motion ? "OFF"
    : ShellSettings.motionSpeed.toUpperCase() + " · POPUPS " + ShellSettings.motionPopups.toUpperCase()

  // groups for the Shell Manager's sidebar: a click scrolls to `y`
  // the header's Reset: these ShellSettings keys back to their defaults
  readonly property var resetKeys: ["motion", "motionSpeed", "motionPopups", "underlineAnimation", "motionPanels", "motionControls", "motionBar", "motionPages", "motionIsland", "motionLock"]
  readonly property bool changed: ShellSettings.changed(resetKeys)
  function reset() { ShellSettings.reset(resetKeys); }

  readonly property var jumps: [
    { key: "general", label: "General", y: generalGroup.y },
    { key: "parts",   label: "Parts",   y: partsGroup.y }
  ]

  spacing: Theme.gapGroup

  // ---- general ----
  KitLabel { id: generalGroup; text: "GENERAL" }

  KitRow {
    label: "Animations"
    hint: "Off: everything snaps in place"

    KitSwitch {
      accessibleName: "Animations"
      checked: ShellSettings.motion
      onToggled: ShellSettings.set("motion", !checked)
    }
  }

  KitRow {
    wide: true
    label: "Speed"
    hint: "How long every move takes"

    KitSegments {
      accessibleName: "Animation speed"
      disabled: !ShellSettings.motion
      model: [{ label: "Slow", value: "slow" }, { label: "Normal", value: "normal" }, { label: "Fast", value: "fast" }]
      current: ShellSettings.motionSpeed
      onPicked: value => { ShellSettings.set("motionSpeed", value); sample.play(); }
    }
  }

  // a square crossing a track at the chosen speed: a click plays it again
  KitRow {
    wide: true
    label: "Sample"
    hint: "Click to preview"

    Item {
      id: sample
      height: 20
      opacity: ShellSettings.motion ? 1 : 0.4

      property bool atEnd: false
      function play() { if (Motion.on) atEnd = !atEnd; }

      Rectangle {
        radius: Theme.pill(height)
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 3
        color: Theme.background3
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: Theme.pill(height)
        x: sample.atEnd ? sample.width - width : 0
        color: Theme.foreground0

        Behavior on x { enabled: Motion.on; NumberAnimation { duration: Motion.slow * 2; easing.type: Easing.InOutCubic } }
      }

      // The preview is an action, not decoration: keep it usable without a pointer.
      MouseArea {
        id: previewArea
        anchors.fill: parent
        enabled: Motion.on
        hoverEnabled: true
        activeFocusOnTab: enabled
        Accessible.role: Accessible.Button
        Accessible.name: "Preview animation"
        Accessible.description: enabled ? "Play the animation sample" : "Enable animations to preview"
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
          forceActiveFocus();
          sample.play();
        }
        Keys.onPressed: event => {
          if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
          if (!event.isAutoRepeat) sample.play();
          event.accepted = true;
        }
      }

      Rectangle {
        anchors.fill: parent
        visible: previewArea.activeFocus
        color: Theme.clear
        radius: Theme.radiusControl
        border.width: 2
        border.color: Theme.foreground0
        z: 2
      }
    }
  }

  KitLine {}

  // ---- parts ----
  KitLabel { id: partsGroup; text: "PARTS"; value: ShellSettings.motion ? "" : "ALL OFF"; valueColor: Theme.muted }

  KitRow {
    wide: true
    label: "Bar popups"
    hint: "How a popup comes in under the bar"

    KitSegments {
      disabled: !ShellSettings.motion
      model: [{ label: "None", value: "none" }, { label: "Fade", value: "fade" },
              { label: "Slide", value: "slide" }, { label: "Grow", value: "grow" }]
      current: ShellSettings.motionPopups
      onPicked: value => ShellSettings.set("motionPopups", value)
    }
  }

  KitRow {
    wide: true
    label: "Underline"
    hint: "The line under an open module"

    KitSegments {
      disabled: !ShellSettings.motion || !ShellSettings.motionBar
      model: [{ label: "None", value: "none" }, { label: "Grow", value: "grow" }, { label: "Slide", value: "slide" }]
      current: ShellSettings.underlineAnimation
      onPicked: value => ShellSettings.set("underlineAnimation", value)
    }
  }

  Repeater {
    model: [
      { key: "motionPanels",   label: "Panels",      hint: "Launcher, keybinds, overview zoom in" },
      { key: "motionControls", label: "Controls",    hint: "Hovers, switches, rows, level bars" },
      { key: "motionBar",      label: "Bar",         hint: "Workspaces and colours" },
      { key: "motionPages",    label: "Pages",       hint: "This window's pages and sidebar" },
      { key: "motionIsland",   label: "Island",      hint: "Morphs between its views" },
      { key: "motionLock",     label: "Lock screen", hint: "Comes in, shakes on a wrong password" }
    ]

    KitRow {
      id: part
      required property var modelData

      label: modelData.label
      hint: modelData.hint

      KitSwitch {
        accessibleName: modelData.label
        disabled: !ShellSettings.motion
        checked: ShellSettings[part.modelData.key]
        onToggled: ShellSettings.set(part.modelData.key, !checked)
      }
    }
  }

  KitGrouper {}
}
