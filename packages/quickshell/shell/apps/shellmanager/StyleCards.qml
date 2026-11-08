import QtQuick
import Quickshell.Widgets
import qs.config
import qs.kit

// One shared preview follows the chosen style and the shape/control settings.
// The illustrated controls have no input handlers or background work.
Item {
  id: root

  property bool kitUnboxed: true
  implicitHeight: choices.y + choices.height
  readonly property bool m3: ShellSettings.material
  readonly property int corner: Theme.radiusCard
  readonly property color paper: Theme.background0
  readonly property color panel: m3 ? Theme.surfaceContainer : Theme.mix(paper, Theme.foreground0, 0.025)
  readonly property color fill: m3 ? Theme.surfaceHigh : Theme.mix(paper, Theme.foreground0, 0.04)
  readonly property color stroke: Theme.mix(paper, Theme.foreground0, 0.17)
  readonly property color selectedFill: m3 ? Theme.secondaryContainer : Theme.mix(paper, Theme.foreground0, 0.14)
  readonly property color accent: m3 ? Theme.primary : Theme.foreground0
  readonly property int controlRadius: Theme.scaled(19, Theme.cornerOf("controls") * Theme.softness)
  readonly property int windowRadius: Theme.round ? Math.round(Theme.cornerOf("windows") * 0.7) : 0

  component Skel: Rectangle {
    height: 4
    radius: height / 2
    color: Theme.muted
    opacity: 0.55
  }

  ClippingRectangle {
    id: picture
    width: root.width
    height: Math.round(Math.max(170, Math.min(208, width * 0.29)))
    radius: root.corner
    color: root.m3 ? Theme.mix(root.paper, Theme.primary, 0.13) : Theme.background1
    // Draw at native size so text and strokes stay sharp on the pixel grid.
    Item {
      x: 16; y: 14
      width: picture.width - 32
      height: 220

      ClippingRectangle {
        id: window
        anchors.fill: parent
        radius: root.windowRadius
        color: root.paper
        Rectangle {
          id: sidebar
          width: 69
          height: parent.height
          color: root.panel

          Row {
            x: 12; y: 13
            spacing: 5
            Repeater { model: 3; Rectangle { width: 4; height: 4; radius: 2; color: Theme.muted; opacity: 0.55 } }
          }
          Column {
            x: 8; y: 36
            spacing: 6
            Repeater {
              model: 4
              Rectangle {
                required property int index
                width: 53; height: 17
                radius: root.controlRadius
                color: index === 1 ? root.selectedFill : Theme.clear
                Skel { x: 7; y: Math.round((parent.height - height) / 2); width: index === 1 ? 32 : 23; color: index === 1 ? Theme.foreground0 : Theme.muted }
              }
            }
          }
        }

        Rectangle { x: sidebar.width; width: 1; height: parent.height; color: root.stroke; visible: !root.m3 }

        Column {
          x: sidebar.width + 17; y: 17
          width: window.width - x - 17
          spacing: 9
          KitText { text: "Appearance"; font.weight: Font.Medium }
          KitText { text: "Make it yours"; color: Theme.hint; font.pixelSize: Theme.fontSize - 1 }

          Rectangle {
            width: parent.width; height: 102
            radius: root.m3 && Theme.round ? 10 : root.controlRadius
            color: root.panel
            border.width: root.m3 ? 0 : 1
            border.color: root.stroke

            Column {
              anchors { fill: parent; margins: 11 }
              spacing: 10
              Item {
                width: parent.width; height: 19
                KitText { y: Math.round((parent.height - height) / 2); text: "Notifications" }
                Rectangle {
                  anchors.right: parent.right
                  y: Math.round((parent.height - height) / 2)
                  width: root.m3 ? 33 : 29; height: root.m3 ? 19 : 15
                  radius: root.controlRadius
                  color: root.accent
                  Rectangle {
                    anchors { right: parent.right; rightMargin: 3 }
                    y: Math.round((parent.height - height) / 2)
                    width: root.m3 ? 13 : 9; height: width
                    radius: root.controlRadius
                    color: root.m3 ? Theme.inkOn(root.accent) : root.paper
                  }
                }
              }
              Item {
                width: parent.width; height: 19
                KitText { text: "Volume"; y: Math.round((parent.height - height) / 2) }
                Rectangle {
                  anchors.right: parent.right
                  y: Math.round((parent.height - height) / 2)
                  width: 69; height: root.m3 ? 8 : ShellSettings.segmentedSliders ? 6 : 3
                  radius: root.controlRadius
                  color: root.selectedFill
                  Rectangle { width: Math.round(parent.width * 0.6); height: parent.height; radius: parent.radius; color: root.accent }
                  Rectangle {
                    visible: !root.m3 && ShellSettings.segmentedSliders
                    x: Math.round(parent.width * 0.6 - width / 2)
                    width: 4; height: parent.height
                    color: root.panel
                  }
                  Rectangle {
                    visible: root.m3 || !ShellSettings.segmentedSliders
                    x: Math.round(parent.width * 0.6 - width / 2)
                    y: Math.round((parent.height - height) / 2)
                    width: root.m3 ? 3 : 7; height: root.m3 ? 15 : 7
                    radius: root.m3 ? 1 : 4
                    color: root.accent
                  }
                }
              }
              Item {
                width: parent.width; height: 19
                KitText { text: "Search"; y: Math.round((parent.height - height) / 2) }
                Rectangle {
                  anchors.right: parent.right
                  width: 69; height: 19
                  radius: root.controlRadius
                  color: root.fill
                  border.width: root.m3 ? 0 : 1
                  border.color: root.stroke
                  Skel { x: ShellSettings.inputAlign === "center" ? Math.round((parent.width - width) / 2) : 7; width: 31; height: 3; y: Math.round((parent.height - height) / 2) }
                  Rectangle { visible: root.m3; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.stroke }
                }
              }
            }
          }

        }
      }
    }
  }

  Rectangle {
    anchors.fill: picture
    radius: picture.radius
    color: Theme.clear
    border.width: Theme.hairline
    border.color: root.stroke
  }

  Row {
    id: choices
    y: picture.height + Theme.gapWide
    width: Math.min(root.width, 320)
    spacing: Theme.gapSmall
    Keys.onLeftPressed: ShellSettings.set("material", false)
    Keys.onRightPressed: ShellSettings.set("material", true)

    Repeater {
      model: [{ label: "Strict", value: false }, { label: "Material 3", value: true }]
      KitButton {
        required property var modelData
        readonly property bool current: ShellSettings.material === modelData.value
        width: (choices.width - choices.spacing) / 2
        text: modelData.label
        selected: current
        icon: current ? "check" : ""
        iconWithText: true
        iconTint: Theme.green
        Accessible.role: Accessible.RadioButton
        Accessible.checked: current
        onClicked: ShellSettings.set("material", modelData.value)
      }
    }
  }
}
