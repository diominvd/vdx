import QtQuick
import Quickshell.Widgets
import qs.config
import qs.kit

// Interface › Style: the two styles as cards, each a small window drawn in its own
// way — Strict with outlines and small corners, Material 3 with tonal surfaces and
// pills — over the theme's colours; the one in use has a check.
Row {
  id: root

  spacing: Theme.gapMedium

  readonly property var styles: [
    { value: false, name: "Strict", hint: "Clean outlines, compact controls" },
    { value: true, name: "Material 3", hint: "Tonal surfaces, soft controls" }
  ]

  Repeater {
    model: root.styles

    Rectangle {
      id: card
      required property var modelData
      readonly property bool picked: ShellSettings.material === modelData.value

      width: (root.width - root.spacing) / 2
      height: mock.height + footer.height
      radius: Theme.radiusCard
      color: picked ? Theme.pickFill : Theme.controlFill
      border.width: Theme.frameWidth
      border.color: picked ? Theme.foreground2 : area.containsMouse ? Theme.controlLineHover : Theme.controlLine
      Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

      // the picture: laid out for 170 x 80 and scaled to the card's height
      ClippingRectangle {
        id: mock
        readonly property bool m3: card.modelData.value
        readonly property real k: height / 80
        x: Theme.frameWidth; y: Theme.frameWidth
        width: parent.width - 2 * Theme.frameWidth
        height: 104
        topLeftRadius: Theme.radiusCard - Theme.frameWidth
        topRightRadius: topLeftRadius
        color: Theme.background1

        Rectangle {
          id: win
          x: (parent.width - width) / 2
          y: 12 * mock.k
          width: 150 * mock.k
          height: parent.height
          radius: (mock.m3 ? 8 : 3) * mock.k
          color: Theme.background0
          border.width: Theme.hairline
          border.color: Theme.background3

          Rectangle { x: 10 * mock.k; y: 9 * mock.k; width: 36 * mock.k; height: 3 * mock.k; radius: Theme.pill(height); color: Theme.foreground0 }

          Column {
            x: 10 * mock.k; y: 20 * mock.k
            spacing: 5 * mock.k

            // a switch row
            Rectangle {
              width: 130 * mock.k; height: 13 * mock.k
              radius: (mock.m3 ? 5 : 2) * mock.k
              color: mock.m3 ? Theme.sectionFill : Theme.clear
              border.width: mock.m3 ? 0 : Theme.hairline
              border.color: Theme.controlLine
              Rectangle { x: 6 * mock.k; anchors.verticalCenter: parent.verticalCenter; width: 30 * mock.k; height: 3 * mock.k; radius: Theme.pill(height); color: Theme.foreground2 }
              Rectangle {
                anchors { right: parent.right; rightMargin: 6 * mock.k; verticalCenter: parent.verticalCenter }
                width: 14 * mock.k; height: 7 * mock.k
                radius: mock.m3 ? Theme.pill(height) : 1.5 * mock.k
                color: mock.m3 ? Theme.primary : Theme.clear
                border.width: mock.m3 ? 0 : Theme.hairline
                border.color: Theme.foreground2
                Rectangle {
                  x: mock.m3 ? parent.width - width - 1 * mock.k : 1.5 * mock.k
                  anchors.verticalCenter: parent.verticalCenter
                  width: 5 * mock.k; height: width
                  radius: mock.m3 ? Theme.pill(height) : 1 * mock.k
                  color: mock.m3 ? Theme.inkOn(Theme.primary) : Theme.foreground2
                }
              }
            }

            // a choice row
            Rectangle {
              width: 130 * mock.k; height: 13 * mock.k
              radius: (mock.m3 ? 5 : 2) * mock.k
              color: mock.m3 ? Theme.sectionFill : Theme.clear
              border.width: mock.m3 ? 0 : Theme.hairline
              border.color: Theme.controlLine
              Rectangle { x: 6 * mock.k; anchors.verticalCenter: parent.verticalCenter; width: 22 * mock.k; height: 3 * mock.k; radius: Theme.pill(height); color: Theme.foreground2 }
              Row {
                anchors { right: parent.right; rightMargin: 4 * mock.k; verticalCenter: parent.verticalCenter }
                spacing: 2 * mock.k
                Repeater {
                  model: 3
                  Rectangle {
                    required property int index
                    width: 14 * mock.k; height: 7 * mock.k
                    radius: mock.m3 ? Theme.pill(height) : 1.5 * mock.k
                    color: index === 1 ? (mock.m3 ? Theme.secondaryContainer : Theme.pickFill) : Theme.clear
                    border.width: !mock.m3 && index !== 1 ? Theme.hairline : 0
                    border.color: Theme.controlLine
                  }
                }
              }
            }
          }

          // the button
          Rectangle {
            x: 10 * mock.k; y: 55 * mock.k
            width: 34 * mock.k; height: 10 * mock.k
            radius: mock.m3 ? Theme.pill(height) : 2 * mock.k
            color: mock.m3 ? Theme.primary : Theme.clear
            border.width: mock.m3 ? 0 : Theme.hairline
            border.color: Theme.foreground2
            Rectangle { anchors.centerIn: parent; width: 16 * mock.k; height: 3 * mock.k; radius: Theme.pill(height); color: mock.m3 ? Theme.inkOn(Theme.primary) : Theme.foreground0 }
          }
        }
      }

      Item {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 44

        Column {
          anchors { left: parent.left; leftMargin: Theme.gapLoose; right: mark.left; rightMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
          spacing: Theme.gapHair
          KitText { width: parent.width; elide: Text.ElideRight; text: card.modelData.name; color: card.picked ? Theme.foreground0 : Theme.foreground2; font.weight: card.picked ? Theme.pickWeight : Font.Normal }
          KitText { width: parent.width; elide: Text.ElideRight; text: card.modelData.hint; color: Theme.muted; font.pixelSize: Theme.fontSize - 1 }
        }

        Item {
          id: mark
          anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
          width: 16; height: 16
          KitIcon { anchors.centerIn: parent; visible: card.picked; name: "check"; tint: Theme.green; size: Theme.iconSmall }
        }
      }

      MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellSettings.set("material", card.modelData.value)
      }
    }
  }
}
