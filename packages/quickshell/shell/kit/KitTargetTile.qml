import QtQuick
import qs.config

// A tile that switches one thing on: a small sample of the control in a well, the name,
// the hint and ON / OFF. On, the sample is drawn in the accent and the tile is ringed in it.
// `sample`: switch | slider | choices | select. Stands on the page (KitGrouper: kitUnboxed).
Rectangle {
  id: root

  property bool kitUnboxed: true
  property string sample: "switch"
  property string label: ""
  property string hint: ""
  property bool checked: false
  readonly property bool hovered: area.containsMouse
  readonly property color tone: checked ? Theme.accent : Theme.gray

  signal toggled()

  implicitHeight: body.implicitHeight + 2 * Theme.gapMedium
  radius: Theme.radiusCard
  color: hovered ? Theme.mix(Theme.groupFill, Theme.foreground0, 0.03) : Theme.groupFill
  border.width: checked ? Theme.ring : Theme.hairline
  border.color: checked ? Theme.accent : Theme.controlLine
  Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
  Behavior on border.color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

  activeFocusOnTab: true
  Accessible.role: Accessible.CheckBox
  Accessible.name: label
  Accessible.description: hint
  Accessible.checkable: true
  Accessible.checked: checked
  Accessible.onToggleAction: toggled()
  Keys.onSpacePressed: event => { if (!event.isAutoRepeat) toggled(); }
  Keys.onReturnPressed: event => { if (!event.isAutoRepeat) toggled(); }

  Column {
    id: body
    anchors { fill: parent; margins: Theme.gapMedium + Theme.ring }
    spacing: Theme.gapMedium

    // ---- the sample, in a well ----
    Rectangle {
      width: parent.width
      height: 56
      radius: Math.max(0, Theme.radiusCard - Theme.gapMedium)
      color: Theme.background0

      // switch
      Rectangle {
        visible: root.sample === "switch"
        anchors.centerIn: parent
        width: 38; height: 20
        radius: Theme.pill(height)
        color: root.tone
        Rectangle {
          width: 14; height: 14
          radius: Theme.pill(height)
          anchors { right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter }
          color: root.checked ? Theme.inkOn(Theme.accent) : Theme.background0
        }
      }

      // slider
      Item {
        visible: root.sample === "slider"
        anchors.centerIn: parent
        width: 80; height: 12
        Rectangle { anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter } height: 4; radius: 2; color: Theme.controlLine }
        Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: parent.width * 0.55; height: 4; radius: 2; color: root.tone }
        Rectangle { x: parent.width * 0.55 - 6; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; radius: 6; color: Theme.foreground0 }
      }

      // choices
      Row {
        visible: root.sample === "choices"
        anchors.centerIn: parent
        spacing: 2
        Repeater {
          model: 3
          Rectangle {
            required property int index
            width: 22; height: 18
            radius: Math.max(0, Theme.radiusControl - 2)
            color: index === 1 ? (root.checked ? Theme.secondaryContainer : Theme.pickFill) : Theme.fillOn(true)
          }
        }
      }

      // dropdown
      Rectangle {
        visible: root.sample === "select"
        anchors.centerIn: parent
        width: 80; height: 24
        radius: Theme.radiusControl
        color: Theme.fillOn(true)
        border.width: Theme.hairline
        border.color: root.checked ? Theme.accent : Theme.controlLine
        KitIcon { anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter } name: "chevron-down"; size: Theme.iconSmall; tint: root.checked ? Theme.accent : Theme.foreground2 }
        Rectangle { anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter } width: 28; height: 4; radius: 2; color: Theme.foreground2 }
      }
    }

    // ---- name and state ----
    Item {
      width: parent.width
      height: name.implicitHeight
      KitText {
        id: name
        text: root.label
        color: Theme.foreground0
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Theme.fontWeight
      }
      KitText {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        text: root.checked ? "ON" : "OFF"
        color: root.checked ? Theme.accent : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.sectionCaptionSize
        font.letterSpacing: Theme.sectionCaptionTracking
      }
    }
    KitText {
      width: parent.width
      text: root.hint
      color: Theme.muted
      elide: Text.ElideRight
      font.family: Theme.fontFamily
      font.pixelSize: Theme.sectionCaptionSize
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled()
  }
}
