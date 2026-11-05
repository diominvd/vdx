import QtQuick
import qs.config
import qs.kit

// Kimmy's options, the one place with their rows: Shell Manager › Kimmy shows them whole
// under its live preview. Its look is set part by part, no presets (CompanionStyle reads
// these keys); then where it lives, how it behaves and its voice. Motion follows
// Appearance › Motion (off: it stays at home, still, and only blinks).
Column {
  id: root
  spacing: Theme.sectionGap

  // the groups' tops, for the page's jumps
  readonly property real bodyY: bodyLabel.y
  readonly property real eyesY: eyesLabel.y
  readonly property real haloY: haloLabel.y
  readonly property real homeY: homeLabel.y
  readonly property real behaviourY: behaviourLabel.y
  readonly property real voiceY: voiceLabel.y

  // the look's keys: the page's Reset the look clears only these
  readonly property var lookKeys: ["size", "bodyColour", "bodyDepth", "shine", "rim", "rimColour", "rimWidth", "shadow",
                                   "eyeColour", "eyeWidth", "eyeHeight", "eyeGap", "eyeTilt",
                                   "glow", "glowColour", "glowSize", "sparkles", "sparkleColour"]

  function isOn(key, fallback) { return ModuleSettings.get("companion", key, fallback) === true; }

  // ---- body ----
  KitLabel { id: bodyLabel; text: "BODY" }

  KitOptionRow {
    module: "companion"; key: "size"; fallback: "medium"
    label: "Size"
    model: [{ label: "Small", value: "small" }, { label: "Medium", value: "medium" }, { label: "Large", value: "large" }]
  }

  CompanionColourRow {
    key: "bodyColour"; fallback: "white"
    label: "Colour"
  }

  CompanionSlider {
    key: "bodyDepth"; fallback: 45; from: 0; to: 100; step: 5; unit: "%"
    label: "Shading"
  }

  KitToggleRow {
    module: "companion"; key: "shine"; fallback: false
    label: "Shine"
    hint: "A soft light on its top left"
  }

  KitToggleRow {
    module: "companion"; key: "rim"; fallback: false
    label: "Rim"
    hint: "A bright line round its edge"
  }

  CompanionColourRow {
    visible: root.isOn("rim", false)
    key: "rimColour"; fallback: "white"
    label: "Rim colour"
  }

  CompanionSlider {
    visible: root.isOn("rim", false)
    key: "rimWidth"; fallback: 4; from: 1; to: 10; step: 1; unit: "%"
    label: "Rim width"
  }

  KitToggleRow {
    module: "companion"; key: "shadow"; fallback: true
    label: "Ground shadow"
    hint: "A soft spot under it"
  }

  KitLine {}

  // ---- eyes ----
  KitLabel { id: eyesLabel; text: "EYES" }

  CompanionColourRow {
    key: "eyeColour"; fallback: "black"
    label: "Colour"
  }

  CompanionSlider {
    key: "eyeWidth"; fallback: 100; from: 50; to: 150; step: 5; unit: "%"
    label: "Width"
  }

  CompanionSlider {
    key: "eyeHeight"; fallback: 100; from: 50; to: 150; step: 5; unit: "%"
    label: "Height"
  }

  CompanionSlider {
    key: "eyeGap"; fallback: 100; from: 70; to: 140; step: 5; unit: "%"
    label: "Spacing"
  }

  CompanionSlider {
    key: "eyeTilt"; fallback: 0; from: -15; to: 15; step: 1; unit: "°"
    label: "Tilt"
  }

  KitLine {}

  // ---- halo ----
  KitLabel { id: haloLabel; text: "HALO" }

  KitToggleRow {
    module: "companion"; key: "glow"; fallback: false
    label: "Halo"
    hint: "A soft glow around it"
  }

  CompanionColourRow {
    visible: root.isOn("glow", false)
    key: "glowColour"; fallback: ""
    label: "Halo colour"
    hint: "Violet by default"
  }

  CompanionSlider {
    visible: root.isOn("glow", false)
    key: "glowSize"; fallback: 100; from: 30; to: 150; step: 10; unit: "%"
    label: "Halo size"
  }

  CompanionSlider {
    key: "sparkles"; fallback: 0; from: 0; to: 10; step: 1; zeroText: "None"
    label: "Sparkles"
  }

  CompanionColourRow {
    visible: Number(ModuleSettings.get("companion", "sparkles", 0)) > 0
    key: "sparkleColour"; fallback: "white"
    label: "Sparkle colour"
  }

  KitLine {}

  // ---- home ----
  KitLabel { id: homeLabel; text: "HOME" }

  KitToggleRow {
    module: "companion"; key: "enabled"; fallback: true
    label: "Show Kimmy"
    hint: "A ball with eyes beside the bar"
  }

  KitOptionRow {
    visible: root.isOn("enabled", true)
    module: "companion"; key: "side"; fallback: "right"
    label: "Corner"
    hint: "Where it rests and naps"
    model: [{ label: "Left", value: "left" }, { label: "Right", value: "right" }]
  }

  KitLine {}

  // ---- behaviour ----
  KitLabel { id: behaviourLabel; text: "BEHAVIOUR" }

  KitOptionRow {
    module: "companion"; key: "temper"; fallback: "playful"
    label: "Temper"
    hint: "How soon it comes to play"
    tip: "Calm stays home. Playful runs to the pointer when bored. Clingy comes soon and stays long"
    model: [{ label: "Calm", value: "calm" }, { label: "Playful", value: "playful" }, { label: "Clingy", value: "clingy" }]
  }

  KitToggleRow {
    module: "companion"; key: "follow"; fallback: true
    label: "Watch the pointer"
    hint: "Eyes follow it. Off: it stays home"
  }

  KitLine {}

  // ---- voice ----
  KitLabel { id: voiceLabel; text: "VOICE" }

  KitToggleRow {
    module: "companion"; key: "speech"; fallback: true
    label: "Mumbling"
    hint: "Little words in a bubble"
  }

  // CompanionWit: it speaks only through Mumbling, so it hides with it
  KitToggleRow {
    visible: root.isOn("speech", true)
    module: "companion"; key: "smart"; fallback: true
    label: "Smarter online"
    hint: "No window titles or screen text sent"
    tip: "Now and then a free opencode model (the Chat module's) words its line. It is told only the kind of program, the time of day, how long you have sat, its mood, how many days you have known each other and the machine's state (music, a busy processor, the battery); never a window title, a file or text from the screen. Offline: its usual lines"
  }

  KitToggleRow {
    module: "companion"; key: "sound"; fallback: true
    label: "Sounds"
    hint: "Soft blips; none when muted or in Focus"
  }

  KitOptionRow {
    visible: root.isOn("sound", true)
    module: "companion"; key: "volume"; fallback: "quiet"
    label: "Volume"
    model: [{ label: "Quiet", value: "quiet" }, { label: "Normal", value: "normal" }]
  }

  KitGrouper {}
}
