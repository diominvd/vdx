import QtQuick
import QtQuick.Effects
import qs.config

// Shared icon renderer. All shell icons use the bundled Phosphor set; no
// runtime fallback to the legacy Material assets. Icon weight is independent
// of window corner geometry.
Item {
  id: root

  property string name: ""
  property color tint: Theme.foreground0
  property int size: Theme.fontSize + 3
  property bool solid: ShellSettings.solidIcons

  // Keep the existing KitIcon API stable while mapping Material-era aliases
  // to the matching local Phosphor glyph. Dynamic states use explicit aliases.
  readonly property string phosphorName: ({
    "activity": "pulse",
    "app-window": "app-window",
    "arrow-left": "arrow-left",
    "arrow-right": "arrow-right",
    "arrow-up": "arrow-up",
    "battery-0": "battery-empty",
    "battery-2": "battery-low",
    "battery-4": "battery-medium",
    "battery-5": "battery-full",
    "battery-6": "battery-full",
    "battery-bolt": "battery-charging",
    "battery-full": "battery-full",
    "battery-plugged": "battery-charging",
    "battery-saver": "battery-charging-vertical",
    "bell": "bell",
    "bluetooth": "bluetooth",
    "bluetooth-off": "bluetooth-x",
    "bot": "robot",
    "brush": "paint-brush",
    "camera": "camera",
    "check": "check",
    "chevron-down": "caret-down",
    "chevron-right": "caret-right",
    "circle": "circle",
    "clipboard": "clipboard-text",
    "clock": "clock",
    "columns": "columns",
    "cpu": "cpu",
    "crop": "crop",
    "cursor": "cursor",
    "download": "download",
    "eject": "eject",
    "external": "arrow-square-out",
    "eye-off": "eye-slash",
    "file": "file-text",
    "folder": "folder",
    "gauge": "gauge",
    "grid": "squares-four",
    "hard-drive": "hard-drive",
    "headphones": "headphones",
    "heart": "heart",
    "heart-filled": "heart",
    "history": "clock-counter-clockwise",
    "home": "house",
    "info": "info",
    "image": "image",
    "keyboard": "keyboard",
    "laptop": "laptop",
    "layout": "squares-four",
    "list": "list-bullets",
    "lock": "lock",
    "log-out": "sign-out",
    "menu": "list",
    "message": "chat-circle",
    "mic": "microphone",
    "mic-off": "microphone-slash",
    "monitor": "monitor",
    "moon": "moon",
    "more": "dots-three-vertical",
    "music": "music-note",
    "package": "package",
    "palette": "palette",
    "pause": "pause",
    "play": "play",
    "plus": "plus",
    "power": "power",
    "public": "globe",
    "puzzle": "puzzle-piece",
    "radio": "radio",
    "refresh": "arrow-clockwise",
    "repeat": "repeat",
    "repeat-1": "repeat-once",
    "rotate-ccw": "arrow-counter-clockwise",
    "scan": "scan",
    "search": "magnifying-glass",
    "server": "hard-drives",
    "settings": "gear",
    "shield": "shield",
    "shuffle": "shuffle",
    "skip-back": "skip-back",
    "skip-forward": "skip-forward",
    "sliders": "sliders-horizontal",
    "square": "square",
    "star": "star",
    "sun": "sun",
    "text": "text-t",
    "tiling": "squares-four",
    "trash": "trash",
    "usb": "usb",
    "video": "video-camera",
    "volume": "speaker-high",
    "volume-x": "speaker-slash",
    "wifi": "wifi-high",
    "wifi-off": "wifi-slash",
    "x": "x",
    "zap": "lightning"
  }[name] ?? "")

  readonly property bool phosphorAvailable: phosphorName !== ""

  // `heart-filled` is a semantic state, not just a weight preference: keep
  // liked tracks visibly filled even when the global icon weight is Regular.
  readonly property bool forceFill: name === "heart-filled"

  // Battery glyphs are wide and short, so give them a slightly wider box.
  readonly property real optical: name.startsWith("battery-") ? 1.35 : 1

  // Widen battery glyphs without making the whole icon taller.
  implicitWidth: size * optical
  implicitHeight: size

  Component.onCompleted: {
    if (name !== "" && !phosphorAvailable)
      console.warn("KitIcon: no Phosphor mapping for icon key:", name)
  }

  Image {
    id: image
    anchors.fill: parent
    source: root.name === "" || !root.phosphorAvailable ? ""
      : Qt.resolvedUrl("icons/phosphor/" + root.phosphorName + ((root.solid || root.forceFill) ? "-fill" : "") + ".svg")
    sourceSize { width: root.implicitWidth * 2; height: root.implicitHeight * 2 }
    // SVGs can have different viewBox ratios; never stretch a glyph to fill its box.
    fillMode: Image.PreserveAspectFit
    smooth: true
    visible: false
  }

  MultiEffect {
    anchors.fill: parent
    source: image
    // Normalize monochrome SVGs to white before tinting. SVG currentColor
    // is resolved by Qt's SVG renderer as black, and colorizing black leaves
    // it black because there is no luminance to recolor.
    brightness: 1
    colorization: 1
    colorizationColor: root.tint
  }
}
