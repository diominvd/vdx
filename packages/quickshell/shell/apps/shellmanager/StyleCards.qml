import QtQuick
import Quickshell.Widgets
import qs.config
import qs.kit

// Interface › Style: the two styles as cards, each a miniature desktop drawn in its own
// way — the island, a window (sidebar, a card of rows, buttons) and a toast, text as grey
// skeleton lines — at 0.6 of the real size, with the real corners (Shape), slider style
// and input text; the one in use has a check. Under the name: the real corner px.
Item {
  id: root

  property bool kitUnboxed: true               // the cards stand on the page, not in the section's box
  readonly property int spacing: Theme.gapMedium

  // the gap under the cards is the one between two sections of a page
  implicitHeight: cards.height + Theme.gapGroup

  readonly property var styles: [
    { value: false, name: "Strict", hint: "Clean outlines, compact controls" },
    { value: true, name: "Material 3", hint: "Tonal surfaces, soft controls" }
  ]

  // a text line of the miniature
  component Skel: Rectangle {
    height: 3
    radius: Theme.pill(height)
    color: Theme.muted
  }

  Row {
    id: cards
    width: parent.width
    spacing: root.spacing

    Repeater {
      model: root.styles

      Rectangle {
        id: card
        required property var modelData
        readonly property bool picked: ShellSettings.material === modelData.value
        readonly property bool m3: modelData.value

        // ---- the miniature's measures: real size x k, corners in the real proportion ----
        readonly property real k: 0.6
        readonly property real soft: m3 ? 2 : 1
        readonly property int ctlH: m3 ? 36 : 34
        function rad(h, part) { return Math.round(Theme.scaled(h, Theme.cornerOf(part) * soft) * k); }
        readonly property int winPx: Theme.round ? Theme.cornerOf("windows") : 0
        readonly property int cardPx: Theme.round ? Math.round(Theme.cornerOf("cards") * (m3 ? 1 : 0.6)) : 0
        readonly property int ctlPx: Theme.scaled(ctlH, Theme.cornerOf("controls") * soft)
        readonly property int winR: Math.round(winPx * k)
        readonly property int cardR: Math.round(cardPx * k)
        readonly property int ctlR: Math.round(ctlPx * k)
        readonly property int ctlMini: Math.round(ctlH * k)
        readonly property color plate: m3 ? Theme.surfaceHigh : Theme.mix(Theme.background0, Theme.foreground0, 0.085)
        readonly property color line: Theme.controlLine
        readonly property color ink: m3 ? Theme.inkOn(Theme.primary) : Theme.background0

        width: (root.width - root.spacing) / 2
        height: mock.height + footer.height
        radius: Theme.radiusCard
        color: picked ? Theme.pickFill : Theme.controlFill
        border.width: Theme.frameWidth
        border.color: picked ? Theme.foreground2 : area.containsMouse ? Theme.controlLineHover : Theme.controlLine
        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

        // ---- the picture ----
        ClippingRectangle {
          id: mock
          x: Theme.frameWidth; y: Theme.frameWidth
          width: parent.width - 2 * Theme.frameWidth
          height: 214
          topLeftRadius: Theme.radiusCard - Theme.frameWidth
          topRightRadius: topLeftRadius
          color: Theme.background1

          // the island
          Rectangle {
            id: island
            anchors { top: parent.top; topMargin: 10; horizontalCenter: parent.horizontalCenter }
            width: 92; height: Math.round(34 * card.k)
            radius: Math.round(Theme.scaled(34, Theme.cornerOf("bar")) * card.k)
            color: Theme.groupFill
            border.width: Theme.hairline
            border.color: card.line
            Row {
              anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
              spacing: 8
              Rectangle { width: 16; height: 8; radius: Math.round(Theme.scaled(22, Theme.cornerOf("bar")) * card.k); color: card.plate }
              Skel { width: 22; anchors.verticalCenter: parent.verticalCenter }
            }
            Rectangle { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter } width: 6; height: 6; radius: 3; color: Theme.green }
          }

          // the window
          Rectangle {
            id: win
            anchors { left: parent.left; right: parent.right; top: island.bottom; bottom: parent.bottom; margins: 10 }
            anchors.topMargin: 8
            radius: card.winR
            color: Theme.background0
            border.width: Theme.hairline
            border.color: Theme.background3
            clip: true

            // sidebar
            Rectangle {
              id: side
              anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
              width: 54
              color: card.m3 ? Theme.surfaceContainer : Theme.mix(Theme.background0, Theme.foreground0, 0.03)
              Column {
                anchors { fill: parent; margins: 6 }
                spacing: 4
                Repeater {
                  model: 5
                  Rectangle {
                    required property int index
                    width: parent.width
                    height: Math.round(30 * card.k)
                    radius: card.rad(30, "controls")
                    color: index === 1 ? (card.m3 ? Theme.secondaryContainer : Theme.pickFill) : Theme.clear
                    border.width: index === 1 && !card.m3 ? Theme.hairline : 0
                    border.color: card.line
                    Skel { x: 6; width: index === 1 ? parent.width * 0.6 : parent.width * 0.48; anchors.verticalCenter: parent.verticalCenter; color: index === 1 ? Theme.foreground0 : Theme.muted }
                  }
                }
              }
            }
            Rectangle { anchors { left: side.right; top: parent.top; bottom: parent.bottom } width: Theme.hairline; color: Theme.background3 }

            // content
            Column {
              anchors { left: side.right; right: parent.right; top: parent.top; margins: 8 }
              anchors.leftMargin: 12
              spacing: 6

              Skel { width: parent.width * 0.38; height: 5; color: Theme.foreground0 }

              // the card of rows
              Rectangle {
                width: parent.width
                height: rows.height + 12
                radius: card.cardR
                color: card.m3 ? Theme.surfaceContainer : Theme.groupFill
                border.width: card.m3 ? 0 : Theme.hairline
                border.color: card.line

                Column {
                  id: rows
                  anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                  spacing: 4

                  // switch
                  Item {
                    width: parent.width; height: card.ctlMini
                    Column { anchors { left: parent.left; verticalCenter: parent.verticalCenter } spacing: 3; Skel { width: 40; height: 4; color: Theme.foreground2 } Skel { width: 62 } }
                    Rectangle {
                      anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                      width: Math.round((card.m3 ? 44 : 38) * card.k); height: Math.round((card.m3 ? 26 : 20) * card.k)
                      radius: card.rad(card.m3 ? 26 : 20, "controls")
                      color: card.m3 ? Theme.primary : Theme.foreground0
                      Rectangle {
                        anchors { right: parent.right; rightMargin: Math.round((card.m3 ? 4 : 3) * card.k); verticalCenter: parent.verticalCenter }
                        width: Math.round((card.m3 ? 18 : 14) * card.k); height: width
                        radius: card.rad(card.m3 ? 18 : 14, "controls")
                        color: card.ink
                      }
                    }
                  }

                  // slider
                  Item {
                    width: parent.width; height: card.ctlMini
                    Column { anchors { left: parent.left; verticalCenter: parent.verticalCenter } spacing: 3; Skel { width: 34; height: 4; color: Theme.foreground2 } Skel { width: 52 } }
                    Item {
                      id: slider
                      readonly property real h: card.m3 ? 10 : ShellSettings.segmentedSliders ? 8 : 3
                      anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                      width: 66; height: 14
                      // fill
                      Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.55 - (card.m3 ? 2 : ShellSettings.segmentedSliders ? 3 : 0); height: slider.h
                        radius: card.m3 ? card.rad(16, "controls") : ShellSettings.segmentedSliders ? card.rad(14, "controls") : height / 2
                        color: card.m3 ? Theme.primary : Theme.foreground0
                      }
                      // remainder
                      Rectangle {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: parent.width * 0.45 - (card.m3 ? 2 : ShellSettings.segmentedSliders ? 3 : 0); height: slider.h
                        radius: card.m3 ? card.rad(16, "controls") : ShellSettings.segmentedSliders ? card.rad(14, "controls") : height / 2
                        color: card.m3 ? Theme.secondaryContainer : card.plate
                      }
                      // the handle: Material's bar, Classic's dot
                      Rectangle {
                        visible: card.m3 || !ShellSettings.segmentedSliders
                        x: parent.width * 0.55 - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: card.m3 ? 3 : 8; height: card.m3 ? 16 : 8
                        radius: Theme.pill(Math.min(width, height))
                        color: Theme.foreground0
                      }
                    }
                  }

                  // segments
                  Item {
                    width: parent.width; height: card.ctlMini
                    Column { anchors { left: parent.left; verticalCenter: parent.verticalCenter } spacing: 3; Skel { width: 30; height: 4; color: Theme.foreground2 } Skel { width: 48 } }
                    Rectangle {
                      anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                      width: segRow.width + (card.m3 ? 0 : 4); height: card.m3 ? segRow.height : card.ctlMini
                      radius: card.m3 ? 0 : card.ctlR
                      color: card.m3 ? Theme.clear : Theme.background1
                      border.width: card.m3 ? 0 : Theme.hairline
                      border.color: card.line
                      Row {
                        id: segRow
                        anchors.centerIn: parent
                        spacing: card.m3 ? 1 : 0
                        Repeater {
                          model: 3
                          Rectangle {
                            required property int index
                            width: 20; height: card.m3 ? card.ctlMini - 2 : card.ctlMini - 6
                            radius: card.m3 ? card.rad(card.ctlH, "controls") : Math.max(0, card.ctlR - 2)
                            color: index === 1 ? (card.m3 ? Theme.secondaryContainer : Theme.pickFill) : card.m3 ? card.plate : Theme.clear
                            Skel { anchors.centerIn: parent; width: 10; color: index === 1 ? Theme.foreground0 : Theme.muted }
                          }
                        }
                      }
                    }
                  }

                  // input
                  Item {
                    width: parent.width; height: card.ctlMini
                    Column { anchors { left: parent.left; verticalCenter: parent.verticalCenter } spacing: 3; Skel { width: 26; height: 4; color: Theme.foreground2 } Skel { width: 44 } }
                    Rectangle {
                      anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                      width: 66; height: card.ctlMini
                      radius: card.ctlR
                      color: card.m3 ? card.plate : Theme.background1
                      border.width: card.m3 ? 0 : Theme.hairline
                      border.color: card.line
                      Skel {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        x: ShellSettings.inputAlign === "center" ? (parent.width - width) / 2 : 7
                      }
                    }
                  }
                }
              }

              // buttons
              Row {
                anchors.right: parent.right
                spacing: 6
                Repeater {
                  model: 2
                  Rectangle {
                    required property int index
                    width: 42; height: card.ctlMini
                    radius: card.ctlR
                    color: index === 1 ? (card.m3 ? Theme.primary : Theme.foreground0) : card.m3 ? card.plate : Theme.clear
                    border.width: index === 0 && !card.m3 ? Theme.hairline : 0
                    border.color: card.line
                    Skel { anchors.centerIn: parent; width: 18; color: index === 1 ? card.ink : Theme.foreground0 }
                  }
                }
              }
            }
          }

          // the toast, over the window's corner
          Rectangle {
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 18; bottomMargin: 16 }
            width: 110; height: 38
            radius: card.winR
            color: Theme.groupFill
            border.width: Theme.hairline
            border.color: card.line
            Rectangle {
              id: toastIcon
              anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
              width: 18; height: 18
              radius: Math.min(9, Math.round(Theme.cornerOf("hub") * 1.5 * card.k))
              color: card.m3 ? Theme.primary : Theme.foreground0
            }
            Column {
              anchors { left: toastIcon.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
              spacing: 4
              Skel { width: 46; height: 4; color: Theme.foreground2 }
              Skel { width: 32 }
            }
          }
        }

        // ---- name, hint, the real corners ----
        Item {
          id: footer
          anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
          height: 62

          Column {
            anchors { left: parent.left; leftMargin: Theme.gapLoose; right: mark.left; rightMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
            spacing: Theme.gapHair
            KitText { width: parent.width; elide: Text.ElideRight; text: card.modelData.name; color: card.picked ? Theme.foreground0 : Theme.foreground2; font.weight: card.picked ? Theme.pickWeight : Font.Normal }
            KitText { width: parent.width; elide: Text.ElideRight; text: card.modelData.hint; color: Theme.muted; font.pixelSize: Theme.fontSize - 1 }
            KitText {
              width: parent.width; elide: Text.ElideRight
              text: "WINDOW " + card.winPx + " · CARD " + card.cardPx + " · CONTROL " + card.ctlPx
              color: Theme.muted
              font.pixelSize: Theme.sectionCaptionSize
            }
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
}
