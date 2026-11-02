import QtQuick
import qs.config
import "colour.js" as Colour

// A colour choice: a row of dots, the picked one ringed, the theme's colour
// first. The user's own colours (ShellSettings.customColours, at most customColoursMax) sit
// right of a divider, once there is one; with them the last dot is a plus that
// turns the row into a strip (back, a hue plate, a shade plate, a preview, a
// tick) saving the colour as one more dot. A cross over an own colour on hover
// removes it. They show where `always` is set (the accent) or while Appearance ›
// Colours › Share own colours is on. A colour is a name or a #rrggbb: `picked` and
// chosen() carry either. `colours(name)` is a colour or a [from, to] gradient.
Item {
  id: root

  property string label: ""
  property string hint: ""
  property var names: []                      // the named choices, in order
  property bool always: false                 // own colours here whatever the sharing
  property string picked: ""
  property var colours: name => Theme.foreground0
  property bool dimmed: false
  readonly property int maxCustoms: ShellSettings.customColoursMax

  signal chosen(string value)
  signal customRemoved(string hex)

  readonly property bool useCustoms: always || ShellSettings.shareColours
  readonly property var customs: useCustoms ? ShellSettings.customColours : []
  property bool editing: false
  readonly property real dotSize: 18
  // the strip starts from the picked colour: its hue, saturation and lightness
  property real hue: 0
  property real sat: 0.7
  property real light: 0.5
  readonly property string draft: Colour.hexOfHsl(hue, sat, light)

  function pairOf(value) {
    if (value.startsWith("#")) return [value, value];
    const c = colours(value);
    return Array.isArray(c) ? c : [c, c];
  }
  function startEditing() {
    const hsl = Colour.hslOf(String(pairOf(picked)[0]));
    hue = hsl ? hsl.h : 0.6;
    sat = hsl && hsl.s > 0.25 ? hsl.s : 0.7;
    light = hsl && hsl.l > 0.2 && hsl.l < 0.85 ? hsl.l : 0.55;
    editing = true;
  }
  function save() {
    editing = false;
    ShellSettings.addCustomColour(draft);
    chosen(draft);
  }
  function ramp(n, make) {
    const out = [];
    for (let i = 0; i < n; i++) out.push(make(i / (n - 1)));
    return out;
  }

  width: parent ? parent.width : 0
  implicitHeight: Theme.rowHeight

  // ---- the row: label left, dots right ----
  KitRow {
    label: root.label
    hint: root.hint
    dimmed: root.dimmed
    width: parent.width
    opacity: root.editing ? 0 : 1
    visible: opacity > 0
    enabled: !root.editing
    Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }

    Row {
      spacing: Theme.gapMedium

      Repeater {
        model: root.names

        Rectangle {
          id: named
          required property string modelData
          readonly property var pair: root.pairOf(modelData)
          width: root.dotSize; height: width
          radius: Theme.pill(height)
          border.width: root.picked === modelData ? Theme.ring : 0
          border.color: Theme.foreground0
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: named.pair[0] }
            GradientStop { position: 1; color: named.pair[1] }
          }
          Behavior on border.width { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.chosen(named.modelData)
          }
        }
      }

      // the own colours start after a divider, once there are some
      Rectangle {
        visible: root.customs.length > 0
        anchors.verticalCenter: parent.verticalCenter
        width: 2; height: root.dotSize
        radius: 1
        color: Theme.gray
      }

      Repeater {
        model: root.customs

        Item {
          id: own
          required property string modelData
          readonly property bool over: dotArea.containsMouse || crossArea.containsMouse
          width: root.dotSize; height: width
          scale: 0
          Component.onCompleted: scale = 1
          Behavior on scale { enabled: Motion.controls; NumberAnimation { duration: Motion.normal; easing.type: Easing.OutBack } }

          Rectangle {
            anchors.fill: parent
            radius: Theme.pill(height)
            color: own.modelData
            border.width: root.picked === own.modelData ? Theme.ring : 0
            border.color: Theme.foreground0
            Behavior on border.width { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
          }
          MouseArea {
            id: dotArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.chosen(own.modelData)
          }
          // the cross over an own colour, as over a bar in the arrangement
          Rectangle {
            anchors { right: parent.right; top: parent.top; rightMargin: -6; topMargin: -6 }
            width: 14; height: 14
            radius: Theme.pill(height)
            color: crossArea.containsMouse ? Theme.pickFill : Theme.controlFill
            border.width: Theme.frameWidth
            border.color: Theme.controlLineHover
            opacity: own.over ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
            Accessible.role: Accessible.Button
            Accessible.name: "Remove " + own.modelData
            KitIcon { anchors.centerIn: parent; name: "x"; size: 9; tint: Theme.foreground0 }
            MouseArea {
              id: crossArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                ShellSettings.removeCustomColour(own.modelData);
                root.customRemoved(own.modelData);
              }
            }
          }
        }
      }

      // the plus dot: hollow, while there is room for another colour
      Rectangle {
        visible: root.useCustoms && root.customs.length < root.maxCustoms
        width: root.dotSize; height: width
        radius: Theme.pill(height)
        color: plusArea.containsMouse ? Theme.controlHover : Theme.clear
        border.width: Theme.hairline
        border.color: plusArea.containsMouse ? Theme.foreground2 : Theme.gray
        Accessible.role: Accessible.Button
        Accessible.name: "Add colour"
        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
        KitIcon { anchors.centerIn: parent; name: "plus"; size: Theme.iconSmall; tint: Theme.foreground2 }
        MouseArea {
          id: plusArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.startEditing()
        }
      }
    }
  }

  // ---- the strip: back, hue, shade, preview, tick ----
  Item {
    id: strip
    anchors.fill: parent
    opacity: root.editing ? 1 : 0
    visible: opacity > 0
    enabled: root.editing
    transform: Translate { x: root.editing ? 0 : 12; Behavior on x { enabled: Motion.controls; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } } }
    Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }

    KitButton {
      id: back
      anchors { left: parent.left; verticalCenter: parent.verticalCenter }
      icon: "arrow-left"
      Accessible.name: "Back"
      onClicked: root.editing = false
    }

    KitButton {
      id: tick
      anchors { right: parent.right; verticalCenter: parent.verticalCenter }
      icon: "check"
      Accessible.name: "Save colour"
      color: hovered ? Theme.pickFill : Theme.accentFor("choices", Theme.background3)
      iconTint: Theme.background0
      onClicked: root.save()
    }

    Rectangle {
      id: preview
      anchors { right: tick.left; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
      width: root.dotSize + 4; height: width
      radius: Theme.pill(height)
      color: root.draft
    }

    KitSlider {
      id: shade
      anchors { right: preview.left; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
      width: Math.min(110, Math.max(70, (strip.width - 2 * back.width - preview.width - 4 * Theme.gapMedium) * 0.4))
      height: Theme.controlHeight
      accessibleName: "Shade"
      spectrum: root.ramp(12, t => Colour.hexOfHsl(root.hue, root.sat, 0.08 + 0.84 * t))
      value: (root.light - 0.08) / 0.84
      text: Math.round(root.light * 100) + "%"
      onMoved: v => root.light = 0.08 + 0.84 * v
    }

    KitSlider {
      anchors {
        left: back.right; leftMargin: Theme.gapMedium
        right: shade.left; rightMargin: Theme.gapMedium
        verticalCenter: parent.verticalCenter
      }
      height: Theme.controlHeight
      accessibleName: "Hue"
      spectrum: root.ramp(24, t => Colour.hexOfHsl(t, root.sat, root.light))
      value: root.hue
      text: Math.round(root.hue * 360) + "°"
      onMoved: v => root.hue = v
    }
  }
}
