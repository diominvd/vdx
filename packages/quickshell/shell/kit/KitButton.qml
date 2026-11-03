import QtQuick
import qs.config

// Outlined button: an optional icon and a label. `selected` fills it one step
// up with a lighter frame and bold text (one of a group of choices).
// `busy` swaps the icon for a spinner. Material: a tonal pill, no frame; `primary` (the
// one main action of a view) is filled with `tone` (Theme.primary unless given); `joinLeft` /
// `joinRight`: a side that meets a neighbour in a connected group (KitChoices) is barely rounded.
Rectangle {
  id: root

  property string icon: ""               // kit/icons name
  property color iconTint: Theme.foreground0
  property bool iconFilled: false
  property bool iconWithText: false       // show the icon beside the label
  property bool iconSolid: ShellSettings.solidIcons
  property string text: ""
  readonly property string displayText: text.replace(/(?:…|\.\.\.)$/, "")
  property bool selected: false
  property bool busy: false
  property bool disabled: false
  property bool compact: false             // short toolbar choices keep their content width
  property bool primary: false             // Material: filled, the view's main action
  property color tone: Theme.primary       // the fill of a primary button
  property bool joinLeft: false
  property bool joinRight: false
  property bool segment: false             // one of a connected group: picked, it is filled (Material)
  readonly property bool kitFree: true     // KitFrame: a run of buttons alone stands outside a section
  property real kitShift: 0              // KitFrame: a footer's way down past a section's edge
  transform: Translate { y: root.kitShift }
  readonly property bool m3: Theme.material
  readonly property bool filled: m3 && primary
  readonly property bool picked: m3 && segment && selected
  readonly property color ink: Theme.inkOn(tone)

  readonly property bool hovered: area.containsMouse && !disabled
  activeFocusOnTab: true
  enabled: !disabled && !busy
  Accessible.role: Accessible.Button
  Accessible.name: displayText || icon
  Accessible.description: busy ? "Working" : ""
  Accessible.onPressAction: if (!disabled && !busy) clicked()
  Keys.onSpacePressed: event => { if (!disabled && !busy && !event.isAutoRepeat) clicked(); }
  Keys.onReturnPressed: event => { if (!disabled && !busy && !event.isAutoRepeat) clicked(); }
  Keys.onEnterPressed: event => { if (!disabled && !busy && !event.isAutoRepeat) clicked(); }

  signal clicked()

  // an icon alone is a square of the control height
  implicitWidth: displayText !== "" ? Math.max(compact ? 0 : Theme.buttonWidth,
    content.implicitWidth + (Theme.material ? 32 : 24)) : Theme.controlHeight
  implicitHeight: Theme.controlHeight
  radius: Theme.radiusControl
  topLeftRadius: m3 && joinLeft ? Theme.radiusJoin : radius
  bottomLeftRadius: m3 && joinLeft ? Theme.radiusJoin : radius
  topRightRadius: m3 && joinRight ? Theme.radiusJoin : radius
  bottomRightRadius: m3 && joinRight ? Theme.radiusJoin : radius
  // set once: whether it sits in a Settings box (a walk up, not a binding)
  property bool boxed: false
  Component.onCompleted: boxed = Theme.boxed(parent)
  color: filled ? (area.pressed || hovered ? Theme.mix(tone, ink, area.pressed ? 0.16 : 0.08) : tone)
       : picked ? Theme.primary
       : area.pressed && !disabled && !busy ? Theme.pickFill : selected ? Theme.selectedFill : hovered ? Theme.hoverOn(boxed) : Theme.fillOn(boxed)
  border.width: activeFocus ? Theme.focusWidth : Theme.frameWidth
  border.color: activeFocus ? Theme.focusRing : selected || hovered ? Theme.controlLineHover : Theme.controlLineRest
  opacity: disabled ? 0.4 : 1

  Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
  Behavior on border.color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Theme.gapMedium

    KitIcon {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.icon !== "" && (root.displayText === "" || root.iconWithText) && !root.busy
      name: root.icon
      tint: root.filled ? root.ink : root.picked ? Theme.inkOn(Theme.primary)
        : root.selected && root.iconTint === Theme.foreground0 ? Theme.selectedText : root.iconTint
      solid: root.iconSolid
      filled: root.iconFilled
      size: Theme.fontSize + 1
    }

    KitSpinner {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.busy
    }

    KitText {
      visible: root.displayText !== ""
      text: root.displayText
      color: root.filled ? root.ink : root.picked ? Theme.inkOn(Theme.primary)
        : root.selected ? Theme.selectedText : Theme.foreground0
      font.weight: Font.Medium
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
    onClicked: if (!root.disabled && !root.busy) root.clicked()
  }
}
