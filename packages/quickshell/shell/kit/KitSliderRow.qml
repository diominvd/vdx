import QtQuick
import qs.config

// A slider with its reading. Two layouts:
//   * `label` set — small-caps "LABEL ......... value" over a full-width slider
//     (`rowStyle`: the label and value as in a KitRow);
//   * `label` empty — icon, slider and value on one line; with `clickable` the
//     icon is a button (mute and the like).
Item {
  id: root

  property string label: ""
  property string icon: ""
  property color iconTint: Theme.foreground0
  property bool clickable: false
  // Name for the optional icon action; sliders can override their own name separately.
  property string accessibleName: ""
  property string sliderAccessibleName: ""
  property real value: 0
  property string text: ""
  property bool dimmed: false
  property color tint: Theme.foreground0
  property var snaps: []
  property var spectrum: []
  property bool rowStyle: false

  readonly property bool captioned: label !== ""
  readonly property bool pressed: slider.pressed
  readonly property real dragValue: slider.dragValue

  signal moved(real value)
  signal released(real value)
  signal iconClicked()

  width: parent ? parent.width : 0
  implicitHeight: captioned ? (rowStyle ? rowCaption.implicitHeight + Theme.gapMedium : caption.implicitHeight + 6) + slider.implicitHeight : 26

  KitLabel {
    id: caption
    visible: root.captioned && !root.rowStyle
    text: root.label
    value: root.text
    valueColor: root.dimmed ? Theme.gray : Theme.foreground2
  }

  KitText {
    id: rowCaption
    visible: root.captioned && root.rowStyle
    text: root.label
  }

  KitText {
    visible: rowCaption.visible
    anchors { right: parent.right; baseline: rowCaption.baseline }
    text: root.text
    color: root.dimmed ? Theme.gray : Theme.foreground2
  }

  // ---- inline layout ----
  Item {
    id: iconBox
    visible: !root.captioned
    anchors { left: parent.left; verticalCenter: slider.verticalCenter }
    width: 26
    height: 26

    Rectangle {
      anchors.fill: parent
      visible: root.clickable && (iconArea.containsMouse || iconArea.activeFocus || iconArea.keyboardPressed)
      radius: Theme.radiusControl
      color: iconArea.keyboardPressed || iconArea.pressed ? Theme.background3 : Theme.background1
      border.width: iconArea.activeFocus ? 2 : 0
      border.color: Theme.foreground0
    }

    KitIcon {
      anchors.centerIn: parent
      name: root.icon
      tint: root.iconTint
      size: 16
      scale: iconArea.pressed || iconArea.keyboardPressed ? 0.9 : 1
      Behavior on scale { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
    }

    MouseArea {
      id: iconArea
      anchors.fill: parent
      enabled: root.clickable && root.enabled
      hoverEnabled: true
      activeFocusOnTab: enabled
      property bool keyboardPressed: false
      onActiveFocusChanged: if (!activeFocus) keyboardPressed = false
      Accessible.role: Accessible.Button
      Accessible.name: root.accessibleName !== "" ? root.accessibleName : root.icon.replace("-", " ")
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      Keys.onPressed: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
        if (!event.isAutoRepeat && enabled) {
          keyboardPressed = true;
          root.iconClicked();
        }
        event.accepted = true;
      }
      Keys.onReleased: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
          keyboardPressed = false;
          event.accepted = true;
        }
      }
      onClicked: { forceActiveFocus(); root.iconClicked(); }
    }
  }

  FontMetrics { id: metrics; font: inlineValue.font }

  KitText {
    id: inlineValue
    visible: !root.captioned
    anchors { right: parent.right; verticalCenter: slider.verticalCenter }
    width: metrics.advanceWidth("150%")
    horizontalAlignment: Text.AlignRight
    text: root.text
    color: root.dimmed ? Theme.gray : Theme.foreground2
    font.pixelSize: Theme.fontSize - 1
  }

  KitSlider {
    id: slider
    anchors {
      left: root.captioned ? parent.left : iconBox.right
      leftMargin: root.captioned ? 0 : 8
      right: root.captioned ? parent.right : inlineValue.left
      rightMargin: root.captioned ? 0 : 10
      bottom: parent.bottom
      bottomMargin: root.captioned ? 0 : 4
    }
    accessibleName: root.sliderAccessibleName !== "" ? root.sliderAccessibleName
      : root.label !== "" ? root.label : root.icon
    value: root.value
    dimmed: root.dimmed
    tint: root.tint
    snaps: root.snaps
    spectrum: root.spectrum
    onMoved: value => root.moved(value)
    onReleased: value => root.released(value)
  }
}
