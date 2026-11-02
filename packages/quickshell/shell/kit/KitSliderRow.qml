import QtQuick
import qs.config

// A slider with its reading. Material puts a labelled slider in one row;
// Strict keeps its label and value in the slider plate. Unlabelled sliders keep
// the icon, track and reading together on one line in either style.
// With `clickable` the icon is a button (mute and the like).
Item {
  id: root

  property string label: ""
  property string accessibleName: label || icon
  property string icon: ""
  property color iconTint: Theme.foreground0
  property bool clickable: false
  property real value: 0
  property string text: ""
  property bool dimmed: false
  property color tint: Theme.foreground0
  property var snaps: []
  property var spectrum: []
  property bool rowStyle: false
  // Strict: the label at the left, a bar with its reading inside at the right
  readonly property bool plate: !Theme.material && spectrum.length === 0

  readonly property bool captioned: label !== ""
  readonly property bool inlineCaption: captioned && Theme.material
  // The host column keeps its width across styles; KitGrouper changes the
  // row inset. Measure here so the track stays the same size in both layouts.
  readonly property real trackWidth: Math.min(Theme.controlWidth,
    Math.round((parent ? parent.width : width) * 0.58))
  readonly property bool pressed: slider.pressed
  readonly property real dragValue: slider.dragValue

  signal moved(real value)
  signal released(real value)
  signal iconClicked()

  width: parent ? parent.width : 0
  implicitHeight: inlineCaption ? Math.max(Theme.rowHeight, slider.implicitHeight) : plate ? slider.implicitHeight + 4 : captioned ? (rowStyle ? rowCaption.implicitHeight + Theme.gapMedium : caption.implicitHeight + 6) + slider.implicitHeight : Math.max(28, slider.implicitHeight + 4)

  KitLabel {
    id: caption
    visible: root.captioned && !root.inlineCaption && !root.rowStyle && !root.plate
    text: root.label
    value: root.text
    valueColor: root.dimmed ? Theme.gray : Theme.foreground2
  }

  KitText {
    id: rowCaption
    visible: root.captioned && (root.rowStyle || root.plate || root.inlineCaption)
    anchors {
      left: root.inlineCaption ? parent.left : undefined
      verticalCenter: root.plate || root.inlineCaption ? parent.verticalCenter : undefined
    }
    width: root.inlineCaption ? Math.min(implicitWidth, Math.max(0, slider.x - Theme.gapMedium)) : implicitWidth
    elide: Text.ElideRight
    text: root.label
  }

  KitText {
    id: rowValue
    visible: rowCaption.visible && !root.plate
    anchors {
      right: parent.right
      verticalCenter: root.inlineCaption ? parent.verticalCenter : undefined
      baseline: root.inlineCaption ? undefined : rowCaption.baseline
    }
    text: root.text
    color: root.dimmed ? Theme.gray : Theme.foreground2
  }

  // ---- inline layout ----
  Item {
    id: iconBox
    visible: !root.captioned
    z: 1                       // a plate carries the icon inside its left end
    anchors { left: parent.left; leftMargin: root.plate ? 2 : 0; verticalCenter: slider.verticalCenter }
    width: Math.max(28, slider.implicitHeight + 4)
    height: Math.max(28, slider.implicitHeight + 4)

    Rectangle {
      anchors.centerIn: parent
      width: parent.width - 4
      height: parent.height - 4
      opacity: root.clickable && iconArea.containsMouse ? 1 : 0
      visible: opacity > 0.001
      Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
      radius: Theme.radiusFor(height)         // the control's proportion at its own size, not a 36 px button's
      color: Theme.background1
    }

    KitIcon {
      anchors.centerIn: parent
      name: root.icon
      tint: root.iconTint
      size: 16
    }

    MouseArea {
      id: iconArea
      anchors.fill: parent
      enabled: root.clickable
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.iconClicked()
    }
  }

  FontMetrics { id: metrics; font: inlineValue.font }

  KitText {
    id: inlineValue
    visible: !root.captioned && !root.plate
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
      verticalCenter: root.inlineCaption ? parent.verticalCenter : undefined
      bottom: root.inlineCaption ? undefined : parent.bottom
      bottomMargin: root.plate ? 2 : root.captioned ? 0 : 4
    }
    // Horizontal anchors used to override width when both ends were set.
    // Position explicitly so a style change never stretches a labelled track.
    x: root.captioned
      ? (root.inlineCaption ? rowValue.x - Theme.gapMedium - width : root.width - width)
      : (root.plate ? 0 : iconBox.x + iconBox.width + 8)
    width: root.captioned ? root.trackWidth
      : root.plate ? root.width : Math.max(0, inlineValue.x - x - 10)
    plate: root.plate
    text: root.text
    accessibleName: root.accessibleName
    value: root.value
    dimmed: root.dimmed
    tint: root.tint
    snaps: root.snaps
    spectrum: root.spectrum
    onMoved: value => root.moved(value)
    onReleased: value => root.released(value)
  }
}
