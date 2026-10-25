import QtQuick
import Quickshell.Widgets
import qs.config

// A segmented control: one track, a segment per choice; the one matching
// `current` is raised (filled, bold), the rest are plain text. Model:
// [{label, value}]. Takes the width it is given (KitRow wide) and splits it evenly.
// Material (Appearance › Controls): the Material 3 segmented button — an
// outlined pill split by hairlines, the picked segment filled with a check.
Rectangle {
  id: root

  property var model: []
  property var current: null
  property bool disabled: false
  // The setting row supplies the label for the group of radio-like segments.
  property string accessibleName: ""

  Accessible.role: Accessible.Grouping
  Accessible.name: accessibleName !== "" ? accessibleName : qsTr("Options")

  signal picked(var value)

  readonly property bool m3: Theme.material
  readonly property int inset: m3 ? 0 : 2

  // Repeater delegates are children of the Repeater, not the Row. Resolve
  // the requested segment through itemAt() so arrow/Home/End navigation can
  // actually move keyboard focus as well as changing the selected value.
  function focusIndex(i) {
    const item = segmentRepeater.itemAt(i);
    if (item && typeof item.forceActiveFocus === "function") item.forceActiveFocus();
  }

  implicitWidth: Theme.controlWidth
  implicitHeight: Theme.controlHeight
  radius: Theme.radiusControl
  color: m3 ? Theme.clear : Theme.background0
  border.width: m3 ? 1 : Theme.frameWidth
  border.color: Theme.gray
  opacity: disabled ? 0.4 : 1

  // the segments are cut to the outline's inside: material the pill, terminal the rounded frame
  ClippingRectangle {
    anchors { fill: parent; margins: root.m3 ? 1 : root.inset }
    radius: Math.max(0, root.radius - (root.m3 ? 1 : root.inset))
    color: Theme.clear

    Row {
      id: segments
      anchors.fill: parent

      Repeater {
        id: segmentRepeater
        model: root.model

        Rectangle {
          id: segment

          required property var modelData
          required property int index

          readonly property bool selected: modelData.value === root.current

          // Keep each option's native enabled state consistent with the whole control.
          enabled: !root.disabled
          activeFocusOnTab: !root.disabled && (selected || (index === 0 && !root.model.some(choice => choice.value === root.current)))
          Accessible.role: Accessible.RadioButton
          Accessible.name: modelData.label
          Accessible.checked: selected

          Keys.onSpacePressed: event => {
            if (!event.isAutoRepeat && !root.disabled && !selected) root.picked(modelData.value);
            event.accepted = true;
          }
          Keys.onReturnPressed: event => {
            if (!event.isAutoRepeat && !root.disabled && !selected) root.picked(modelData.value);
            event.accepted = true;
          }
          Keys.onEnterPressed: event => {
            if (!event.isAutoRepeat && !root.disabled && !selected) root.picked(modelData.value);
            event.accepted = true;
          }
          Keys.onHomePressed: event => {
            if (!root.disabled && root.model.length > 0) {
              if (root.model[0].value !== root.current) root.picked(root.model[0].value);
              Qt.callLater(() => root.focusIndex(0));
            }
            event.accepted = true;
          }
          Keys.onEndPressed: event => {
            if (!root.disabled && root.model.length > 0) {
              const last = root.model.length - 1;
              if (root.model[last].value !== root.current) root.picked(root.model[last].value);
              Qt.callLater(() => root.focusIndex(last));
            }
            event.accepted = true;
          }
          Keys.onLeftPressed: event => {
            if (!root.disabled && root.model.length > 0) {
              const next = (index - 1 + root.model.length) % root.model.length;
              if (root.model[next].value !== root.current) root.picked(root.model[next].value);
              Qt.callLater(() => root.focusIndex(next));
            }
            event.accepted = true;
          }
          Keys.onRightPressed: event => {
            if (!root.disabled && root.model.length > 0) {
              const next = (index + 1) % root.model.length;
              if (root.model[next].value !== root.current) root.picked(root.model[next].value);
              Qt.callLater(() => root.focusIndex(next));
            }
            event.accepted = true;
          }
          readonly property bool hovered: area.containsMouse && !root.disabled && !selected

          // Keep delegate geometry finite if a caller temporarily supplies an empty model.
          width: segments.width / Math.max(1, root.model.length)
          height: segments.height
          radius: 0      // the outer corners come from the clip; each segment's own corners would notch the joint
          color: selected ? Theme.background3 : hovered ? Theme.background2 : Theme.clear

          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

          // material: a hairline between two segments
          Rectangle {
            visible: root.m3 && segment.index > 0
            width: 1
            height: parent.height
            color: Theme.gray
          }

          Row {
            anchors.centerIn: parent
            width: Math.max(0, Math.min(implicitWidth, parent.width - Theme.gapMedium))
            spacing: Theme.gapSmall

            KitIcon {
              id: tick
              anchors.verticalCenter: parent.verticalCenter
              visible: root.m3 && segment.selected && segment.width >= label.implicitWidth + 40
              name: "check"
              tint: label.color
              size: Theme.iconSmall
            }

            KitText {
              id: label
              anchors.verticalCenter: parent.verticalCenter
              width: Math.max(0, Math.min(implicitWidth, segment.width - Theme.gapMedium - (tick.visible ? tick.width + parent.spacing : 0)))
              elide: Text.ElideRight
              text: segment.modelData.label
              color: segment.selected ? Theme.accentFor("choices", Theme.foreground0) : Theme.foreground2
              font.weight: segment.selected ? Font.ExtraBold : Font.Normal
            }
          }

          Rectangle {
            anchors.fill: parent
            color: Theme.clear
            border.width: segment.activeFocus ? Theme.focusRingWidth : 0
            border.color: Theme.focusRing
            z: 1
            radius: 0
          }

          MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
              if (!root.disabled) {
                segment.forceActiveFocus();
                if (!segment.selected) root.picked(segment.modelData.value);
              }
            }
          }
        }
      }
    }
  }
}
