import QtQuick
import QtQuick.Effects
import qs.config

// An SVG icon from kit/icons, recoloured to `tint`. The files are drawn in
// white, so colorization maps them to any theme colour. The set is the user's
// (Shell Manager › Appearance › Icons): Material Symbols, where `solid` (the
// user's style unless set) picks the filled variant from icons/solid and round
// corners (Appearance › Corners) the Rounded set in icons/round (names:
// icons/material.txt); Phosphor in icons/phosphor, `solid` from phosphor/solid,
// one set for both corners (icons/phosphor.txt); or Lucide in icons/lucide,
// outline only (icons/lucide.txt).
Item {
  id: root

  property string name: ""
  property color tint: Theme.foreground0
  property int size: Theme.fontSize + 3
  property bool solid: ShellSettings.solidIcons
  property bool filled: false              // force filled pause / play / stop glyphs
  readonly property bool filledGlyph: filled && ["pause", "play", "square"].includes(name)

  // the battery glyphs are wide and short, so drawn alone they look smaller
  // than the others: their box is a third larger, the glyph's height matches
  readonly property real optical: name.startsWith("battery-") ? 1.35 : 1

  implicitWidth: size * optical
  implicitHeight: size * optical

  Image {
    id: image
    anchors.fill: parent
    source: root.name === "" ? ""
      : ShellSettings.iconSet === "lucide" ? Qt.resolvedUrl("icons/lucide/" + root.name + ".svg")
      : ShellSettings.iconSet === "phosphor" ? Qt.resolvedUrl("icons/phosphor/" + (root.solid ? "solid/" : "") + root.name + ".svg")
      : Qt.resolvedUrl("icons/" + (Theme.round ? "round/" : "") + (root.solid ? "solid/" : "") + root.name + ".svg")
    sourceSize { width: root.implicitWidth * 2; height: root.implicitHeight * 2 }
    smooth: true
    visible: false
  }

  MultiEffect {
    anchors.fill: parent
    source: image
    visible: !root.filledGlyph
    colorization: 1
    colorizationColor: root.tint
  }

  Row {
    visible: root.filledGlyph && root.name === "pause"
    anchors.centerIn: parent
    spacing: root.size * 0.2
    Repeater {
      model: 2
      Rectangle {
        width: root.size * 0.22
        height: root.size * 0.72
        radius: root.size * 0.04
        anchors.verticalCenter: parent.verticalCenter
        color: root.tint
      }
    }
  }

  Rectangle {
    visible: root.filledGlyph && root.name === "square"
    anchors.centerIn: parent
    width: root.size * 0.64
    height: width
    radius: root.size * 0.08
    color: root.tint
  }

  Canvas {
    id: play
    visible: root.filledGlyph && root.name === "play"
    anchors.fill: parent
    onPaint: {
      const ctx = getContext("2d");
      ctx.clearRect(0, 0, width, height);
      ctx.fillStyle = root.tint;
      ctx.beginPath();
      ctx.moveTo(width * 0.25, height * 0.12);
      ctx.lineTo(width * 0.82, height * 0.5);
      ctx.lineTo(width * 0.25, height * 0.88);
      ctx.closePath();
      ctx.fill();
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Connections {
      target: root
      function onTintChanged() { play.requestPaint(); }
    }
  }
}
