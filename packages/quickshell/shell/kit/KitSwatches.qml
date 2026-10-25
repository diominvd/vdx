import QtQuick
import qs.config

// A dot per choice, pushed to the right edge: `colours(name)` gives its
// [from, to] gradient (one colour twice), the picked one carries a ring. Laid
// out right to left, so the model runs backwards. `exclude` leaves names out.
// `add` is a choice that is empty until something is saved in it: while
// `addEmpty`, its dot is hollow with a plus (choose it to type one).
Row {
  id: root

  property var model: []
  property var exclude: []
  property string picked: ""
  property var colours: name => [Theme.frame, Theme.frame]
  property string add: ""
  property bool addEmpty: false
  property bool alignLeft: false
  property bool disabled: false               // dimmed, and no click (a choice made elsewhere)

  signal chosen(string name)

  function focusSwatch(index) {
    const item = swatchRepeater.itemAt(index);
    if (item) item.focusOption();
  }

  spacing: Theme.gapMedium
  layoutDirection: alignLeft ? Qt.LeftToRight : Qt.RightToLeft
  opacity: disabled ? 0.4 : 1

  Repeater {
    id: swatchRepeater
    model: root.model.filter(name => root.exclude.indexOf(name) < 0)

    Rectangle {
      id: swatch
      required property string modelData
      required property int index
      readonly property bool hollow: modelData === root.add && root.addEmpty
      function focusOption() { swatchArea.forceActiveFocus(); }
      readonly property bool picked: root.picked === modelData
      readonly property var pair: hollow ? [Theme.clear, Theme.clear] : root.colours(modelData)

      anchors.verticalCenter: parent.verticalCenter
      width: 18
      height: 18
      radius: Theme.pill(height)
      border.width: swatchArea.activeFocus ? Theme.focusRingWidth : picked ? Theme.ring : hollow ? Theme.hairline : 0
      border.color: swatchArea.activeFocus ? Theme.focusRing : picked ? Theme.foreground0 : Theme.gray
      // Use roving Tab focus: arrow keys move through the radio choices.
      readonly property bool tabStop: !root.disabled && (picked || (index === 0 && !root.model.filter(name => root.exclude.indexOf(name) < 0).includes(root.picked)))
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: swatch.pair[0] }
        GradientStop { position: 1; color: swatch.pair[1] }
      }

      KitIcon {
        anchors.centerIn: parent
        visible: swatch.hollow
        name: "plus"
        tint: Theme.foreground2
        size: Theme.iconSmall
      }

      MouseArea {
        id: swatchArea
        anchors.fill: parent
        enabled: !root.disabled
        hoverEnabled: true
        activeFocusOnTab: enabled && swatch.tabStop
        Accessible.role: Accessible.RadioButton
        Accessible.name: swatch.modelData
        Accessible.checked: swatch.picked
        Accessible.description: swatch.hollow ? "Add a custom colour" : "Choose colour"
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
          forceActiveFocus();
          root.chosen(swatch.modelData);
        }
        Keys.onPressed: event => {
          if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
          if (!event.isAutoRepeat && enabled) root.chosen(swatch.modelData);
          event.accepted = true;
        }
        Keys.onLeftPressed: event => {
          if (enabled && swatchRepeater.count > 0) {
            const delta = root.layoutDirection === Qt.RightToLeft ? 1 : -1;
            const next = (swatch.index + delta + swatchRepeater.count) % swatchRepeater.count;
            const item = swatchRepeater.itemAt(next);
            // Delegates can briefly be unavailable while a dynamic palette changes.
            if (item) {
              root.chosen(item.modelData);
              Qt.callLater(() => root.focusSwatch(next));
            }
          }
          event.accepted = true;
        }
        Keys.onRightPressed: event => {
          if (enabled && swatchRepeater.count > 0) {
            const delta = root.layoutDirection === Qt.RightToLeft ? -1 : 1;
            const next = (swatch.index + delta + swatchRepeater.count) % swatchRepeater.count;
            const item = swatchRepeater.itemAt(next);
            // Delegates can briefly be unavailable while a dynamic palette changes.
            if (item) {
              root.chosen(item.modelData);
              Qt.callLater(() => root.focusSwatch(next));
            }
          }
          event.accepted = true;
        }
      }
    }
  }
}
