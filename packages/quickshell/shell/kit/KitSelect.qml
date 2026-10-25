import QtQuick
import qs.config

// A setting row: a label (and a dim hint under it) on the left, an outlined
// box with the current value and a chevron on the right. Clicking the box
// opens the choices in an outlined list under the row. Model: [{label, value,
// note?}] — a note ("not installed") shows dim on the right of its choice. A
// long list shows `maxRows` and scrolls, the current choice in view.
Column {
  id: root

  // set once: whether it sits in a Settings box (a walk up, not a binding)
  property bool boxed: false
  Component.onCompleted: boxed = Theme.boxed(parent)

  property string label: ""
  property string hint: ""
  property color hintColor: Theme.muted
  property var model: []
  property var current: null
  property bool busy: false
  property bool disabled: false
  property bool expanded: false
  property int highlightedIndex: -1
  // The box takes the standard width (KitRow's, so the right edges line up) when
  // the row has room for it; a narrower row gives the label half of it (less the
  // gap). It never grows past the standard width: a long choice elides in the box.
  property real boxWidth: Math.min(width, Math.max(Math.min(choiceWidth, Theme.controlWidth),
    Math.min(Theme.controlWidth, (width - Theme.gapWide) / 2)))
  // The open list floats over what follows instead of pushing it down.
  property bool overlay: false
  property int maxRows: 6
  readonly property int rowHeight: 28

  readonly property var selected: model.find(c => c.value === current) ?? null

  // the width the widest choice needs: its text in the font, plus the box's
  // and the list's own padding (text margin, chevron or check, gaps)
  readonly property real choiceWidth: {
    let widest = 0;
    for (let i = 0; i < choiceSizes.count; i++) widest = Math.max(widest, choiceSizes.objectAt(i).advanceWidth);
    return Math.ceil(widest) + 2 * Theme.gapLoose + Theme.iconSmall + Theme.gapSmall;
  }

  // a hidden measure of every choice's text, in the box's font
  Item {
    visible: false
    Instantiator {
      id: choiceSizes
      model: root.model

      TextMetrics {
        required property var modelData
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Theme.fontWeight
        text: modelData.label
      }
    }
  }

  signal picked(var value)

  width: parent ? parent.width : 0
  spacing: Theme.gapSmall
  z: expanded ? 10 : 0

  onDisabledChanged: if (disabled) expanded = false
  onBusyChanged: if (busy) expanded = false
  // Do not leave a logically open menu behind when its row is hidden.
  onVisibleChanged: if (!visible) expanded = false
  onModelChanged: {
    if (!expanded) return;
    const index = model.findIndex(choice => choice.value === current);
    highlightedIndex = model.length > 0 ? Math.max(0, index) : -1;
  }
  onCurrentChanged: {
    if (!expanded) return;
    const index = model.findIndex(choice => choice.value === current);
    highlightedIndex = model.length > 0 ? Math.max(0, index) : -1;
  }
  onExpandedChanged: highlightedIndex = expanded && model.length > 0
    ? Math.max(0, model.findIndex(choice => choice.value === current)) : -1

  function moveHighlight(delta) {
    if (model.length === 0) { highlightedIndex = -1; return; }
    highlightedIndex = Math.max(0, Math.min(model.length - 1, highlightedIndex + delta));

    // Scroll only when the highlighted row leaves the viewport. Avoid jumping
    // an extra row on every arrow press near the bottom of the list.
    const optionTop = highlightedIndex * rowHeight;
    const optionBottom = optionTop + rowHeight;
    const viewportTop = scroller.contentY;
    const viewportBottom = viewportTop + scroller.height;
    if (optionTop < viewportTop) scroller.contentY = optionTop;
    else if (optionBottom > viewportBottom) scroller.contentY = optionBottom - scroller.height;
  }

  function chooseHighlighted() {
    if (disabled || busy || highlightedIndex < 0 || highlightedIndex >= model.length) return;
    const choice = model[highlightedIndex];
    if (choice.value !== current) picked(choice.value);
    expanded = false;
  }

  Item {
    id: row
    width: parent.width
    height: Math.max(box.height, text.implicitHeight)

    Column {
      id: text
      anchors { left: parent.left; right: box.left; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
      spacing: Theme.gapTight

      KitText {
        width: parent.width
        text: root.label
        elide: Text.ElideRight
      }

      KitText {
        width: parent.width
        visible: root.hint !== ""
        text: root.hint
        elide: Text.ElideRight
        color: root.hintColor
        font.pixelSize: Theme.fontSize - 2
      }
    }

    Rectangle {
      id: box
      anchors.right: parent.right
      // Keep native enabled state aligned with the custom disabled appearance.
      // Busy selects remain enabled/focusable so "Loading options" is announced.
      enabled: !root.disabled
      activeFocusOnTab: !root.disabled
      Accessible.role: Accessible.ComboBox
      Accessible.name: root.label
      Accessible.description: root.busy ? qsTr("Loading options")
        : root.expanded && root.highlightedIndex >= 0 && root.highlightedIndex < root.model.length
          ? qsTr("Highlighted option: %1").arg(root.model[root.highlightedIndex].label)
            + (root.selected ? ". " + qsTr("Current value: %1").arg(root.selected.label) : "")
            + (root.hint !== "" ? ". " + root.hint : "")
          : root.hint + (root.hint !== "" ? ". " : "")
            + (root.selected ? qsTr("Current value: %1").arg(root.selected.label) : qsTr("No value selected"))
      width: root.boxWidth
      height: Theme.controlHeight
      radius: Theme.radiusControl
      color: boxArea.containsMouse && !root.disabled ? Theme.hoverOn(root.boxed) : Theme.fillOn(root.boxed)
      border.width: activeFocus ? Theme.focusRingWidth : Theme.frameWidth
      border.color: activeFocus ? Theme.focusRing : root.expanded ? Theme.accentFor("selects", Theme.foreground2)
        : boxArea.containsMouse ? Theme.foreground2 : Theme.gray
      opacity: root.disabled ? 0.4 : 1

      Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
      Behavior on border.color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

      KitFieldLine { active: root.expanded }

      KitText {
        anchors { left: parent.left; leftMargin: Theme.gapLoose; right: mark.left; rightMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
        text: root.selected?.label ?? "—"
        elide: Text.ElideRight
      }

      Item {
        id: mark
        anchors { right: parent.right; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
        width: 14
        height: 14

        KitSpinner {
          anchors.centerIn: parent
          visible: root.busy
        }

        KitIcon {
          anchors.centerIn: parent
          visible: !root.busy
          name: "chevron-down"
          tint: Theme.foreground2
          size: Theme.iconSmall
          rotation: root.expanded ? 180 : 0

          Behavior on rotation { enabled: Motion.controls; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
        }
      }

      Keys.onDownPressed: event => {
        if (root.disabled || root.busy) { event.accepted = true; return; }
        if (!root.expanded) root.expanded = true;
        else root.moveHighlight(1);
        event.accepted = true;
      }
      Keys.onUpPressed: event => {
        if (root.disabled || root.busy) { event.accepted = true; return; }
        if (!root.expanded) root.expanded = true;
        else root.moveHighlight(-1);
        event.accepted = true;
      }
      Keys.onHomePressed: event => {
        if (!root.disabled && !root.busy && root.expanded && root.model.length > 0) {
          root.highlightedIndex = 0;
          scroller.contentY = 0;
        }
        event.accepted = true;
      }
      Keys.onEndPressed: event => {
        if (!root.disabled && !root.busy && root.expanded && root.model.length > 0) {
          root.highlightedIndex = root.model.length - 1;
          scroller.contentY = Math.max(0, scroller.contentHeight - scroller.height);
        }
        event.accepted = true;
      }
      // Activation keys must not reopen/close the menu repeatedly when held.
      Keys.onPressed: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
        if (!event.isAutoRepeat && !root.disabled && !root.busy) {
          if (root.expanded) root.chooseHighlighted();
          else root.expanded = true;
        }
        event.accepted = true;
      }
      Keys.onEscapePressed: event => {
        if (root.expanded) {
          root.expanded = false;
          event.accepted = true;
        }
      }

      MouseArea {
        id: boxArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.disabled || root.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: {
          if (!root.disabled && !root.busy) {
            box.forceActiveFocus();
            root.expanded = !root.expanded;
          }
        }
      }
    }
  }

  // Column lays out no zero-height child, so in overlay mode the list hangs
  // off the row (below it, over the following content) instead of the slot.
  // The list spans the whole row: the box's width is for the closed control only.
  Item {
    id: slot
    width: parent.width
    height: list.height
    visible: root.expanded && !root.overlay

    Rectangle {
      id: list
      parent: root.overlay ? row : slot
      y: root.overlay ? row.height + root.spacing : 0
      visible: root.expanded
      width: parent.width
      x: 0
      height: Math.max(2 * inset, Math.min(options.implicitHeight, Math.max(0, root.maxRows) * root.rowHeight) + 2 * inset)
      radius: Theme.radiusControl
      // round corners keep the rows off the frame's curve
      readonly property int inset: Theme.frameWidth + (Theme.round ? 3 : 0)

      // the choices drop in: a fade and a few pixels down
      property real shown: 1
      transform: Translate { y: -6 * (1 - list.shown) }
      opacity: shown
      onVisibleChanged: {
        if (!visible) return;
        if (Motion.controls) dropIn.restart();
        // the current choice in view, a row above it showing
        const i = root.model.findIndex(c => c.value === root.current);
        scroller.contentY = Math.max(0, Math.min(scroller.contentHeight - scroller.height, (i - 1) * root.rowHeight));
      }
      NumberAnimation { id: dropIn; target: list; property: "shown"; from: 0; to: 1; duration: Motion.normal; easing.type: Motion.easing }
      color: Theme.material ? Theme.background1 : root.overlay ? Theme.background0 : Theme.clear
      border.width: Theme.frameWidth
      border.color: Theme.gray

      Flickable {
        id: scroller
        x: list.inset
        y: list.inset
        width: Math.max(0, parent.width - 2 * list.inset)
        height: Math.max(0, parent.height - 2 * list.inset)
        contentHeight: options.implicitHeight
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        // the wheel stays in a list that scrolls (the page under it does not move)
        MouseArea {
          z: 1
          width: scroller.width
          height: scroller.contentHeight
          acceptedButtons: Qt.NoButton
          onWheel: wheel => {
            if (!scroller.interactive) { wheel.accepted = false; return; }
            const d = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 120 * root.rowHeight * 2;
            scroller.contentY = Math.max(0, Math.min(scroller.contentHeight - scroller.height, scroller.contentY - d));
          }
        }

      Column {
        id: options
        width: parent.width

        KitText {
          visible: root.model.length === 0
          width: parent.width
          height: root.rowHeight
          text: qsTr("No options available")
          color: Theme.muted
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }

        Repeater {
          model: root.model

          Rectangle {
            id: option

            required property var modelData
            required property int index

            readonly property bool active: modelData.value === root.current
            readonly property bool highlighted: index === root.highlightedIndex

            // Expose each popup choice to assistive technology. The closed
            // control announces the highlighted item; these nodes expose the
            // available labels, optional notes, and the committed selection.
            Accessible.role: Accessible.ListItem
            Accessible.name: modelData.label
            Accessible.description: modelData.note ?? ""
            Accessible.selected: active

            width: options.width
            height: root.rowHeight
            radius: Math.max(0, Theme.radiusControl - 2)
            color: active || highlighted ? Theme.background3 : optionArea.containsMouse ? Theme.controlHover : Theme.clear
            Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

            KitText {
              anchors { left: parent.left; leftMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
              width: Math.max(0, parent.width - Theme.gapLoose * 2 - Theme.iconSmall - Theme.gapSmall - (optionNote.visible ? optionNote.width + Theme.gapSmall : 0))
              elide: Text.ElideRight
              text: option.modelData.label
              color: option.active || option.highlighted || optionArea.containsMouse ? Theme.foreground0 : Theme.foreground2
              Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
              font.weight: option.active ? Font.ExtraBold : Font.DemiBold
            }

            KitText {
              id: optionNote
              anchors { right: parent.right; rightMargin: Theme.gapLoose + Theme.iconSmall + Theme.gapSmall; verticalCenter: parent.verticalCenter }
              visible: (option.modelData.note ?? "") !== ""
              text: option.modelData.note ?? ""
              elide: Text.ElideRight
              width: Math.min(implicitWidth, Math.max(0, parent.width / 3))
              color: Theme.muted
              font.pixelSize: Theme.fontSize - 2
            }

            KitIcon {
              anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
              visible: option.active
              name: "check"
              tint: Theme.green
              size: Theme.iconSmall
            }

            MouseArea {
              id: optionArea
              anchors.fill: parent
              hoverEnabled: true
              enabled: !root.disabled && !root.busy
              cursorShape: root.disabled || root.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
              onClicked: {
                box.forceActiveFocus();
                if (!option.active) root.picked(option.modelData.value);
                root.expanded = false;
              }
            }
          }
        }
      }
      }
    }
  }
}
