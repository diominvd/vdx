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
  property string placeholder: "—"         // shown while no choice is current
  property color hintColor: Theme.muted
  property var model: []
  property var current: null
  property bool busy: false
  property bool disabled: false
  property bool expanded: false
  property int highlighted: -1
  function openChoices() {
    if (disabled || busy || !model.length) return;
    highlighted = Math.max(0, model.findIndex(c => c.value === current));
    expanded = !expanded;
  }
  function choose(index) {
    if (disabled || busy || !model[index]) return;
    if (model[index].value !== current) picked(model[index].value);
    expanded = false;
  }
  function moveChoice(step) {
    if (disabled || busy || !model.length) return;
    if (!expanded) { openChoices(); return; }
    highlighted = Math.max(0, Math.min(model.length - 1, highlighted + step));
    scroller.contentY = Math.max(0, Math.min(scroller.contentHeight - scroller.height,
      highlighted * rowHeight - (scroller.height - rowHeight) / 2));
  }
  // The box takes the standard width (KitRow's, so the right edges line up) when
  // the row has room for it; a narrower row gives the label half of it (less the
  // gap). It never grows past the standard width: a long choice elides in the box.
  // In a narrow row (KitRow's rule: Theme.rowStackBelow) the box goes under the text across
  // the whole row, as a wide KitRow's control does (never a diagonal from the label).
  readonly property bool stacked: width < Theme.rowStackBelow && (label !== "" || hint !== "")   // a box alone has nothing to stack
  readonly property int stackPad: Math.round((Theme.rowHeight - Theme.controlHeight) / 2)
  property real boxWidth: stacked ? width
    : Math.min(width, Math.max(Math.min(choiceWidth, Theme.controlWidth),
      Math.min(Theme.controlWidth, (width - Theme.gapWide) / 2)))
  property int maxRows: 6
  readonly property int rowHeight: Theme.navigationHeight

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
  onModelChanged: expanded = false

  Item {
    id: row
    width: parent.width
    height: root.stacked ? 2 * root.stackPad + text.implicitHeight + Theme.gapSmall + box.height
                         : Math.max(Theme.rowHeight, box.height, text.implicitHeight)

    Column {
      id: text
      anchors { left: parent.left; right: root.stacked ? parent.right : box.left; rightMargin: root.stacked ? 0 : Theme.gapWide }
      y: root.stacked ? root.stackPad : (row.height - height) / 2
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
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        color: root.hintColor
        font.pixelSize: Theme.fontSize - 1
      }
    }

    Rectangle {
      id: box
      activeFocusOnTab: true
      enabled: !root.disabled && !root.busy
      Accessible.role: Accessible.ComboBox
      Accessible.name: root.label
      Accessible.description: root.selected?.label ?? ""
      Accessible.onPressAction: root.openChoices()
      Keys.onSpacePressed: root.openChoices()
      Keys.onDownPressed: root.moveChoice(1)
      Keys.onUpPressed: root.moveChoice(-1)
      Keys.onEscapePressed: root.expanded = false
      Keys.onReturnPressed: {
        if (!root.expanded) root.openChoices();
        else root.choose(root.highlighted);
      }
      // a click focuses it (the keys work) but draws no ring: the ring is for Tab
      property bool byMouse: false
      readonly property bool ring: activeFocus && !byMouse
      onActiveFocusChanged: { if (!activeFocus) { root.expanded = false; if (Window.active) byMouse = false; } }
      anchors.right: parent.right
      y: root.stacked ? root.stackPad + text.height + Theme.gapSmall : (row.height - height) / 2
      width: root.boxWidth
      height: Theme.controlHeight
      radius: Theme.radiusControl
      color: boxArea.containsMouse && !root.disabled ? Theme.hoverOn(root.boxed) : Theme.fillOn(root.boxed)
      border.width: box.ring && !Theme.material ? Theme.focusWidth : Theme.frameWidth
      border.color: box.ring ? Theme.focusRing : root.expanded ? Theme.accentFor("selects", Theme.controlLineHover)
        : boxArea.containsMouse ? Theme.controlLineHover : Theme.controlLineRest
      opacity: root.disabled ? 0.4 : 1

      Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
      Behavior on border.color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

      KitFieldLine { active: root.expanded || box.activeFocus }

      KitText {
        anchors { left: parent.left; leftMargin: Theme.gapLoose; right: mark.left; rightMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
        text: root.selected?.label ?? root.placeholder
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

      MouseArea {
        id: boxArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: { box.forceActiveFocus(Qt.MouseFocusReason); box.byMouse = true; root.openChoices(); }
      }
    }
  }

  // Choices are always inline: opening reserves space in every host.
  Item {
    id: slot
    width: parent.width
    height: list.height
    visible: root.expanded

    Rectangle {
      id: list
      visible: root.expanded
      width: parent.width
      x: 0
      height: Math.min(options.implicitHeight, root.maxRows * root.rowHeight) + 2 * inset
      radius: Theme.radiusControl
      // round corners keep the rows off the frame's curve
      readonly property int inset: Theme.frameWidth + (Theme.round ? 3 : 0)

      // Fade within the reserved area without crossing neighbouring rows.
      property real shown: 1
      opacity: shown
      onVisibleChanged: {
        if (!visible) return;
        if (Motion.controls) dropIn.restart();
        // the current choice in view, a row above it showing
        const i = root.model.findIndex(c => c.value === root.current);
        scroller.contentY = Math.max(0, Math.min(scroller.contentHeight - scroller.height, (i - 1) * root.rowHeight));
      }
      NumberAnimation { id: dropIn; target: list; property: "shown"; from: 0; to: 1; duration: Motion.normal; easing.type: Motion.easing }
      color: Theme.controlFill
      border.width: Theme.frameWidth
      border.color: Theme.controlLine

      Flickable {
        id: scroller
        x: list.inset
        y: list.inset
        width: parent.width - 2 * list.inset
        height: parent.height - 2 * list.inset
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

        Repeater {
          model: root.model

          Rectangle {
            id: option

            required property var modelData
            required property int index

            readonly property bool active: modelData.value === root.current

            width: options.width
            height: root.rowHeight
            radius: Math.max(0, Theme.radiusControl - 2)
            color: active ? Theme.selectedFill : optionArea.containsMouse || (box.activeFocus && index === root.highlighted) ? Theme.controlHover : Theme.clear
            Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

            KitText {
              anchors { left: parent.left; leftMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
              text: option.modelData.label
              color: option.active ? Theme.selectedText : optionArea.containsMouse ? Theme.foreground0 : Theme.foreground2
              Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
              font.weight: option.active ? Theme.pickWeight : Font.DemiBold
            }

            KitText {
              anchors { right: parent.right; rightMargin: Theme.gapLoose + Theme.iconSmall + Theme.gapSmall; verticalCenter: parent.verticalCenter }
              visible: (option.modelData.note ?? "") !== ""
              text: option.modelData.note ?? ""
              color: Theme.muted
              font.pixelSize: Theme.fontSize - 1
            }

            KitIcon {
              anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
              visible: option.active
              name: "check"
              tint: Theme.accentFor("selects", Theme.foreground0)
              size: Theme.iconSmall
            }

            MouseArea {
              id: optionArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.choose(option.index);
              }
            }
          }
        }
      }
      }
    }
  }
}
