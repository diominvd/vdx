import QtQuick
import qs.config
import "colour.js" as Colour

// The picker under a colour field, on demand: one low panel with a
// saturation × brightness square, a hue strip and the palette as tiles (when
// there is one; the picked tile has a ring, `icons` marks special ones). It keeps its own hue, so a grey or black
// colour does not lose it. `moved(hex)` while dragging, `released(hex)` when
// let go, `chosen(name)` for a palette tile.
Item {
  id: root

  property string colour: ""
  property var palette: []
  property string picked: ""
  property var colours: name => [Theme.frame, Theme.frame]
  property var icons: name => ""             // a tile's icon, "" for none

  property real hue: 0
  property real sat: 1
  property real val: 1
  property string lastOut: ""

  signal moved(string hex)
  signal released(string hex)
  signal chosen(string name)

  readonly property int pad: Theme.gapMedium

  // the palette: two rows that fill the square's height (one row for 4 or fewer)
  readonly property int paletteRows: palette.length > 4 ? 2 : 1
  readonly property int paletteCols: Math.max(1, Math.ceil(palette.length / paletteRows))

  implicitHeight: panel.height + Theme.gapMedium

  // a colour from outside (typed, or a palette tile): the picker follows it
  function follow(text) {
    if (text.trim().toLowerCase() === lastOut) return;
    const c = Colour.hsvOf(text);
    if (!c) return;
    if (c.h >= 0) hue = c.h;
    sat = c.s;
    val = c.v;
  }

  function emitColour(done) {
    const hex = Colour.hexOf(hue, sat, val);
    lastOut = hex;
    if (done) released(hex); else moved(hex);
  }

  function clamp(v) { return Math.max(0, Math.min(1, v)); }

  onColourChanged: follow(colour)
  Component.onCompleted: follow(colour)

  Rectangle {
    id: panel
    y: Theme.gapMedium
    width: parent.width
    height: content.height + 2 * root.pad
    radius: Theme.radiusCard
    color: Theme.background0
    border.width: Theme.hairline
    border.color: Theme.background2

    // one row: the square and its hue strip on the left, the palette fills the rest
    Row {
      id: content
      x: root.pad
      y: root.pad
      width: Math.max(0, parent.width - 2 * root.pad)
      height: square.height
      spacing: Math.min(root.pad, width / (root.palette.length > 0 ? 4 : 3))

      // ---- saturation (→) × brightness (↑) ----
      Rectangle {
        id: square
        width: root.palette.length > 0
          ? Math.max(0, Math.min(180, (content.width - hueBar.width - 2 * content.spacing) / 2))
          : Math.max(0, content.width - hueBar.width - content.spacing)
        height: 96
        radius: Math.min(6, Theme.radiusControl + 2)
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 1) }
          GradientStop { position: 1; color: Qt.hsva(root.hue, 1, 1, 1) }
        }

        Rectangle {
          anchors.fill: parent
          radius: parent.radius
          gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 1) }
          }
        }

        Rectangle {
          x: root.sat * square.width - width / 2
          y: (1 - root.val) * square.height - height / 2
          width: 12
          height: 12
          radius: 6
          color: Qt.hsva(root.hue, root.sat, root.val, 1)
          border.width: 2
          border.color: Qt.rgba(1, 1, 1, 1)
        }

        Rectangle {
          anchors.fill: parent
          radius: square.radius
          color: "transparent"
          border.width: squareArea.activeFocus ? Theme.focusRingWidth : 0
          border.color: Theme.focusRing
        }

        MouseArea {
          id: squareArea
          anchors.fill: parent
          cursorShape: Qt.CrossCursor
          activeFocusOnTab: true
          Accessible.role: Accessible.Slider
          Accessible.name: qsTr("Colour saturation and brightness")
          Accessible.description: qsTr("Use arrow keys to adjust saturation and brightness. Enter or Space commits the colour.")
          function pick(m, done) {
            if (width <= 0 || height <= 0) return;
            root.sat = root.clamp(m.x / width);
            root.val = 1 - root.clamp(m.y / height);
            root.emitColour(done);
          }
          Keys.onLeftPressed: event => { root.sat = root.clamp(root.sat - 0.02); root.emitColour(false); event.accepted = true; }
          Keys.onRightPressed: event => { root.sat = root.clamp(root.sat + 0.02); root.emitColour(false); event.accepted = true; }
          Keys.onUpPressed: event => { root.val = root.clamp(root.val + 0.02); root.emitColour(false); event.accepted = true; }
          Keys.onDownPressed: event => { root.val = root.clamp(root.val - 0.02); root.emitColour(false); event.accepted = true; }
          Keys.onReturnPressed: event => { root.emitColour(true); event.accepted = true; }
          Keys.onEnterPressed: event => { root.emitColour(true); event.accepted = true; }
          Keys.onSpacePressed: event => { root.emitColour(true); event.accepted = true; }
          onPressed: m => { forceActiveFocus(); pick(m, false); }
          onPositionChanged: m => { if (pressed) pick(m, false); }
          onReleased: m => pick(m, true)
        }
      }

      // ---- hue, top to bottom ----
      Rectangle {
        id: hueBar
        width: Math.min(10, Math.max(0, content.width - content.spacing))
        height: square.height
        radius: Theme.pill(width)
        gradient: Gradient {
          GradientStop { position: 0 / 6; color: Qt.hsva(0 / 6 % 1, 1, 1, 1) }
          GradientStop { position: 1 / 6; color: Qt.hsva(1 / 6 % 1, 1, 1, 1) }
          GradientStop { position: 2 / 6; color: Qt.hsva(2 / 6 % 1, 1, 1, 1) }
          GradientStop { position: 3 / 6; color: Qt.hsva(3 / 6 % 1, 1, 1, 1) }
          GradientStop { position: 4 / 6; color: Qt.hsva(4 / 6 % 1, 1, 1, 1) }
          GradientStop { position: 5 / 6; color: Qt.hsva(5 / 6 % 1, 1, 1, 1) }
          GradientStop { position: 6 / 6; color: Qt.hsva(6 / 6 % 1, 1, 1, 1) }
        }

        Rectangle {
          y: root.hue * hueBar.height - height / 2
          anchors.horizontalCenter: parent.horizontalCenter
          width: 14
          height: 14
          radius: 7
          color: Qt.hsva(root.hue, 1, 1, 1)
          border.width: 2
          border.color: Qt.rgba(1, 1, 1, 1)
        }

        Rectangle {
          anchors.fill: parent
          anchors.leftMargin: -6
          anchors.rightMargin: -6
          radius: Theme.pill(width)
          color: "transparent"
          border.width: hueArea.activeFocus ? Theme.focusRingWidth : 0
          border.color: Theme.focusRing
        }

        MouseArea {
          id: hueArea
          anchors { fill: parent; leftMargin: -6; rightMargin: -6 }
          cursorShape: Qt.PointingHandCursor
          activeFocusOnTab: true
          Accessible.role: Accessible.Slider
          Accessible.name: qsTr("Colour hue")
          Accessible.description: qsTr("Use Up and Down arrows to adjust hue. Enter or Space commits the colour.")
          function pick(m, done) {
            if (width <= 0 || height <= 0) return;
            root.hue = root.clamp(m.y / height);
            root.emitColour(done);
          }
          Keys.onUpPressed: event => { root.hue = root.clamp(root.hue - 0.01); root.emitColour(false); event.accepted = true; }
          Keys.onDownPressed: event => { root.hue = root.clamp(root.hue + 0.01); root.emitColour(false); event.accepted = true; }
          Keys.onReturnPressed: event => { root.emitColour(true); event.accepted = true; }
          Keys.onEnterPressed: event => { root.emitColour(true); event.accepted = true; }
          Keys.onSpacePressed: event => { root.emitColour(true); event.accepted = true; }
          onPressed: m => { forceActiveFocus(); pick(m, false); }
          onPositionChanged: m => { if (pressed) pick(m, false); }
          onReleased: m => pick(m, true)
        }
      }

      // ---- palette: the square's height in rows, as many columns as the entries need ----
      Grid {
        id: tiles
        visible: root.palette.length > 0
        width: Math.max(0, content.width - square.width - hueBar.width - 2 * content.spacing)
        height: square.height
        rows: root.paletteRows
        columns: root.paletteCols
        spacing: Theme.gapSmall

        Repeater {
          model: root.palette

          Rectangle {
            id: tile
            required property string modelData
            readonly property var pair: root.colours(modelData)
            readonly property bool chosen: root.picked === modelData

            width: Math.max(0, (tiles.width - (root.paletteCols - 1) * Theme.gapSmall) / root.paletteCols)
            height: root.paletteRows > 1 ? Math.max(0, (square.height - Theme.gapSmall) / 2) : Math.max(0, square.height)
            radius: Math.min(6, Theme.radiusControl + 2)
            readonly property color ink: Colour.hsvOf(String(pair[0]))?.v > 0.6 ? Qt.rgba(0, 0, 0, 1) : Qt.rgba(1, 1, 1, 1)
            border.width: tileArea.activeFocus ? Theme.focusRingWidth : chosen ? Theme.ring : tileArea.containsMouse ? Theme.hairline : 0
            border.color: tileArea.activeFocus ? Theme.focusRing : chosen ? Theme.foreground0 : Theme.foreground2
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0; color: tile.pair[0] }
              GradientStop { position: 1; color: tile.pair[1] }
            }

            // a tile that is not a plain colour (the theme's, your own) says so with an icon
            KitIcon {
              anchors.centerIn: parent
              visible: name !== ""
              name: root.icons(tile.modelData)
              tint: tile.ink
              size: Theme.iconSmall
            }

            MouseArea {
              id: tileArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              activeFocusOnTab: true
              Accessible.role: Accessible.Button
              Accessible.name: tile.modelData
              Accessible.description: tile.chosen ? qsTr("Selected colour") : qsTr("Choose this colour")
              Accessible.checked: tile.chosen
              Keys.onReturnPressed: event => { if (!event.isAutoRepeat) root.chosen(tile.modelData); event.accepted = true; }
              Keys.onEnterPressed: event => { if (!event.isAutoRepeat) root.chosen(tile.modelData); event.accepted = true; }
              Keys.onSpacePressed: event => { if (!event.isAutoRepeat) root.chosen(tile.modelData); event.accepted = true; }
              onPressed: forceActiveFocus()
              onClicked: root.chosen(tile.modelData)
            }
          }
        }
      }
    }
  }
}
