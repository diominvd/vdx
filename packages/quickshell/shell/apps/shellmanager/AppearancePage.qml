import QtQuick
import qs.config
import qs.kit

// Appearance: everything that changes how the desktop looks, top to bottom —
// the accent, the wallpaper (the theme, the font and the cursor have pages of
// their own), then SHAPE (corners, icons) and CONTROLS. Each group has its caps
// label here or in its section.
KitColumn {
  id: root

  // the theme shown in the preview; Apply makes it the active one
  property string selected: ThemeService.current
  readonly property var themeColors: ThemeService.colors[selected] ?? ({})
  readonly property bool customWallpaper: ShellSettings.wallpaperMode === "custom"
  readonly property bool imageWallpaper: ShellSettings.wallpaperMode === "image"
  // the picture of the active theme
  readonly property string currentImage: imageWallpaper ? WallpaperService.imageFor(ThemeService.current) : ""
  readonly property color wallpaper: customWallpaper ? ShellSettings.wallpaperColor : p("background1")

  function p(role) { return themeColors[role] ?? Theme[role]; }

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "sun"
  readonly property string title: "Appearance"
  readonly property string subtitle: (ThemeService.current || "—").toUpperCase()
    + (currentImage !== "" ? " · IMAGE WALLPAPER" : customWallpaper ? " · CUSTOM WALLPAPER" : " · THEME WALLPAPER")
    + (ShellSettings.accent ? " · ACCENT " + ShellSettings.accentStops.map(n => n === "theme" ? "THEME" : n.toUpperCase()).join(" → ") : "")

  // groups for the Shell Manager's sidebar: a click scrolls to `y`
  // the header's Reset: these ShellSettings keys back to their defaults (the theme, the font and the cursor are on their pages)
  readonly property var resetKeys: ["solidIcons", "wallpaperMode", "wallpaperColor", "wallpaperImages", "wallpaperOutputs", "corners", "cornerRadius", "cornerSplit", "cornerRadii", "material", "accent", "accentStops", "accentGradient", "accentCustom", "accentWhere", "passwordDots"]
  readonly property bool changed: ShellSettings.changed(resetKeys)
  function reset() { ShellSettings.reset(resetKeys); }

  readonly property var jumps: [
    { key: "style",     label: "Style",     y: styleLabel.y },
    { key: "accent",    label: "Accent",    y: accentSection.y },
    { key: "wallpaper", label: "Wallpaper", y: wallpaperSection.y },
    { key: "shape",     label: "Shape",     y: shapeLabel.y }
  ]

  spacing: Theme.gapGroup

  KitLabel { id: styleLabel; text: "STYLE" }

  KitRow {
    wide: true
    label: "Style"
    hint: "Material: filled, no frames"

    KitSegments {
      model: [
        { label: "Terminal", value: false },
        { label: "Material", value: true }
      ]
      current: ShellSettings.material
      onPicked: value => ShellSettings.set("material", value)
    }
  }

  // the theme's light or dark twin (themes/mktheme.py); a theme without one stays
  KitRow {
    wide: true
    label: "Mode"
    hint: "The theme's light or dark twin"

    KitSegments {
      disabled: ThemeService.busy
      model: [{ label: "Dark", value: false }, { label: "Light", value: true }]
      current: ThemeService.light
      onPicked: value => ThemeService.setLight(value)
    }
  }

  // how a typed password shows: the lock and every password field of the shell
  KitRow {
    wide: true
    label: "Typed characters"
    hint: "In every password field"

    KitSegments {
      model: [{ label: "Dots", value: true }, { label: "Squares", value: false }]
      current: ShellSettings.passwordDots
      onPicked: value => ShellSettings.set("passwordDots", value)
    }
  }
  KitLine {}

  AccentSection { id: accentSection; width: parent.width }
  KitLine {}
  WallpaperSection { id: wallpaperSection; width: parent.width; page: root }
  KitLine {}

  KitLabel {
    id: shapeLabel
    width: parent.width
    text: "SHAPE"
    value: (ShellSettings.corners === "round" ? "ROUND " + ShellSettings.cornerRadius + " PX" : "SHARP")
      + " · " + (ShellSettings.solidIcons ? "FILL" : "REGULAR")
  }

  CornersSection { id: cornersSection; width: parent.width }
  IconsSection { id: iconsSection; width: parent.width }

  KitGrouper {}
}
