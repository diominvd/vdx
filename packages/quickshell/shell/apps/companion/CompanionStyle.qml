import QtQuick
import qs.config

// Kimmy's look as the user set it (Shell Manager › Kimmy): every part on its own, no
// presets. Reads ModuleSettings "companion" and hands the resolved values to a
// CompanionBall (`style: CompanionStyle {}`). A colour is a name (white, black or a
// theme colour) or #rrggbb; unset keys give today's white ball with black eyes.
QtObject {
  id: root

  function pick(key, fallback) { return ModuleSettings.get("companion", key, fallback); }
  function colour(value, fallback) {
    const v = String(value ?? "");
    if (v === "") return fallback;
    if (v === "white") return "#ffffff";
    if (v === "black") return "#0c0c0e";
    return Theme.accentColour(v);
  }
  function number(key, fallback, lo, hi) {
    const v = Number(pick(key, fallback));
    return isNaN(v) ? fallback : Math.max(lo, Math.min(hi, v));
  }

  // body
  readonly property color bodyColour: colour(pick("bodyColour", "white"), "#ffffff")
  readonly property real bodyDepth: number("bodyDepth", 45, 0, 100) / 100        // how much darker the bottom is
  readonly property bool rimOn: pick("rim", false) === true
  readonly property color rimColour: colour(pick("rimColour", "white"), "#ffffff")
  readonly property real rimWidth: number("rimWidth", 4, 1, 10) / 100            // of the size
  readonly property bool shineOn: pick("shine", false) === true
  // eyes
  readonly property color eyeColour: colour(pick("eyeColour", "black"), "#0c0c0e")
  readonly property real eyeWidth: number("eyeWidth", 100, 50, 150) / 100
  readonly property real eyeHeight: number("eyeHeight", 100, 50, 150) / 100
  readonly property real eyeGap: number("eyeGap", 100, 70, 140) / 100
  readonly property real eyeTilt: number("eyeTilt", 0, -15, 15)                  // degrees
  // halo and stars
  readonly property bool glowOn: pick("glow", false) === true
  readonly property color glowColour: colour(pick("glowColour", ""), "#a35bd6")
  readonly property real glowSize: number("glowSize", 100, 30, 150) / 100
  readonly property int sparkleCount: Math.round(number("sparkles", 0, 0, 10))
  readonly property color sparkleColour: colour(pick("sparkleColour", "white"), "#ffffff")
  // the ground
  readonly property bool shadowOn: pick("shadow", true) !== false
}
