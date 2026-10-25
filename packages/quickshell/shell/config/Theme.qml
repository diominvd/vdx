pragma Singleton
import QtQuick

// The look: the theme's colours (from its Colors.qml), type, metrics, the
// spacing scale and the colours of a measured value. A module's own numbers
// (polls, limits, its script) live in its service; text formatting in Format,
// paths in Paths. Icons are SVGs in kit/icons, not font glyphs.
QtObject {
  id: root

  // ---- colours (from the active theme's Colors.qml) ----
  // `live` is the active theme's colours read at runtime (ThemeService), so a
  // theme switch recolours everything without reloading the shell.
  property var live: ({})

  readonly property color background0: live.background0 ?? Colors.background0
  readonly property color background1: live.background1 ?? Colors.background1
  readonly property color background2: live.background2 ?? Colors.background2
  readonly property color background3: live.background3 ?? Colors.background3

  readonly property color foreground0: live.foreground0 ?? Colors.foreground0
  readonly property color foreground1: live.foreground1 ?? Colors.foreground1
  readonly property color foreground2: live.foreground2 ?? Colors.foreground2

  readonly property color red:    live.red ?? Colors.red
  readonly property color orange: live.orange ?? Colors.orange
  readonly property color yellow: live.yellow ?? Colors.yellow
  readonly property color green:  live.green ?? Colors.green
  readonly property color aqua:   live.aqua ?? Colors.aqua
  readonly property color blue:   live.blue ?? Colors.blue
  readonly property color purple: live.purple ?? Colors.purple
  readonly property color gray:   live.gray ?? Colors.gray
  // hints and captions: the theme's muted, lifted toward foreground0 until it
  // reads (WCAG 4.5:1 on background0); the theme file keeps its own (kitty's color8)
  readonly property color muted:  legible(live.muted ?? Colors.muted, background0)
  readonly property color frame:  live.frame ?? Colors.frame
  readonly property color dim:    live.dim ?? Colors.dim

  function luminance(c: color): real {
    const f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
    return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
  }
  function contrast(a: color, b: color): real {
    const x = luminance(a), y = luminance(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
  }
  // c mixed toward foreground0 in 2 % steps until it has 4.5:1 on `on`
  function legible(c: color, on: color): color {
    const to = foreground0;
    for (let t = 0; t < 1; t += 0.02) {
      const m = Qt.rgba(c.r + (to.r - c.r) * t, c.g + (to.g - c.g) * t, c.b + (to.b - c.b) * t, 1);
      if (contrast(m, on) >= 4.5) return m;
    }
    return to;
  }

  // the unseen dot (Bar › Notifications dot colour): a name of the choices;
  // "theme" (and anything else) is the theme's own text colour
  function notifyDot(name) {
    return name === "red" ? red : name === "yellow" ? yellow : name === "green" ? green
         : name === "blue" ? blue : foreground0;
  }

  // the equalizer's colours (Modules › Equalizer): one colour, or a [from, to] gradient across its bars
  function equalizerColours(name) {
    // Appearance › Accent, APPLIES TO Bar modules: the accent takes the bars whatever the choice
    if (accentOn("modules")) return [accent, accentEnd];
    const pair = { sea: ["blue", "green"], sunset: ["yellow", "red"] }[name];
    if (pair) return [notifyDot(pair[0]), notifyDot(pair[1])];
    const one = name === "theme" ? frame : notifyDot(name);
    return [one, one];
  }

  // ---- accent (Appearance › Accent) ----
  // A stop by name: "theme" is the theme's frame colour (the accent that follows
  // the theme), "custom" the typed one. slot: the stop it is for (0 the colour,
  // 1 the gradient's end): a custom colour has one per stop
  function accentColour(name, slot) {
    if (name === "custom") {
      const hex = ShellSettings.accentCustom[slot ?? 0];
      return hex ? Qt.color(hex) : frame;
    }
    if (name === "theme") return frame;
    return { red: red, orange: orange, yellow: yellow, green: green, aqua: aqua, blue: blue, purple: purple }[name] ?? foreground0;
  }
  readonly property bool accentGradient: ShellSettings.accentGradient
  // the gradient's two ends; with one, both are the same colour, so a fill can
  // always be a Gradient from `accent` to `accentEnd`
  readonly property color accent: accentColour(ShellSettings.accentStops[0] ?? "theme", 0)
  readonly property color accentEnd: accentGradient ? accentColour(ShellSettings.accentStops[1] ?? "theme", 1) : accent
  // what takes the accent: a target key of Appearance › Accent (off by default)
  function accentOn(key) { return ShellSettings.accent && ShellSettings.accentWhere[key] === true; }
  function accentFor(key, fallback) { return accentOn(key) ? accent : fallback; }

  // ---- type and bar metrics ----
  readonly property string fontFamily: ShellSettings.font     // the system monospace, Shell Manager › Appearance
  readonly property int fontSize: ShellSettings.textSize      // Appearance › Font › Text size
  readonly property int fontWeight: Font.DemiBold
  readonly property int barHeight: 34
  readonly property int moduleSpacing: 2
  readonly property int edgeMargin: 20
  readonly property int separatorMargin: ShellSettings.barGap   // Bar › Style › Spacing, each side of a separator
  readonly property int workspaceMinWidth: 16
  // Bar › Style island: the island floats this far from the screen's top.
  // barEdge: where the bar ends for windows and popups, either style.
  readonly property bool island: ShellSettings.barStyle === "island"
  readonly property int islandTop: 6
  readonly property int islandHeight: 32
  readonly property int islandFrameWidth: 1      // either control style: it floats over windows
  // the island's corners: in proportion while small (radiusFor), no more than
  // half again a popup's when open (sharp: 0)
  readonly property int islandRadius: round ? Math.round(cornerOf("bar") * 1.5) : 0
  readonly property int barEdge: island ? islandTop + islandHeight : barHeight

  // ---- controls (Appearance › Controls) ----
  // outlined: framed controls on the surface (the terminal look). material:
  // no frames — controls are filled one step up, a popup has a quiet hairline
  readonly property bool material: ShellSettings.material
  readonly property color controlFill: material ? background1 : clear
  readonly property color controlHover: material ? background2 : background1
  // a control in a Settings box (KitGrouper) sits on background1: its fills go one step up
  function boxed(item) {
    for (let p = item; p; p = p.parent)
      for (const k of p.data ?? []) if (k.isKitGrouper) return true;
    return false;
  }
  function fillOn(boxed) { return boxed && material ? background2 : controlFill; }
  function hoverOn(boxed) { return boxed ? (material ? background3 : background2) : controlHover; }
  readonly property color popupFrame: material ? background2 : frame

  // ---- corners (Appearance › Corners) ----
  // sharp: all 0. round: one slider (Corners › Radius, R) sets every corner in
  // proportion: a surface takes R, a card 0.6 R, and anything of height h
  // (controls, tracks, knobs, the resting island) h × R / 48 — at the largest
  // stop (24) all of them are pills, at the smallest a hint of a curve
  readonly property bool round: ShellSettings.corners === "round"
  readonly property var cornerStops: [4, 8, 12, 16, 20, 24]    // the slider's ticks, px
  // a part's R: the one slider's, or the part's own (Corners › Separately). The
  // parts read one R the same way, so the same R looks the same on each
  function cornerOf(part) {
    return ShellSettings.cornerSplit ? (ShellSettings.cornerRadii[part] ?? ShellSettings.cornerRadius) : ShellSettings.cornerRadius;
  }
  function scaled(h, r) { return round ? Math.round(Math.min(h / 2, h * r / 48)) : 0; }
  readonly property int radiusSurface: round ? cornerOf("windows") : 0             // popups, windows, panels
  readonly property int radiusCard: round ? Math.round(cornerOf("cards") * 0.6) : 0 // tiles, boxes, picked rows
  readonly property int radiusControl: radiusFor(controlHeight)                    // buttons, fields, selects, segments
  // the corner of a control h px high, in proportion to its R; never past a half circle
  function radiusFor(h) { return scaled(h, cornerOf("controls")); }
  // the bar's: the island and its child bars
  function barRadiusFor(h) { return scaled(h, cornerOf("bar")); }
  // tracks, knobs, switches: the same proportion (a pill only at the largest radius)
  function pill(h) { return radiusFor(h); }

  // ---- popups (kit) ----
  // the dimmed screen under the launcher, the keybinds and the overview
  readonly property color scrim: Qt.rgba(background0.r, background0.g, background0.b, 0.7)
  // no fill, in the hover's colour: a fade to or from it never passes through
  // black ("transparent" is a black with no alpha)
  readonly property color clear: Qt.rgba(controlHover.r, controlHover.g, controlHover.b, 0)

  // the spacing scale: between the items of a column, in px
  readonly property int gapTight: 2
  readonly property int gapHair: 4
  readonly property int gapSmall: 6
  readonly property int gapMedium: 8
  readonly property int gapLoose: 10          // also an edge inset of a row
  readonly property int gapWide: 12
  readonly property int gapGroup: 14
  // icons and the widths of a side column (Shell Manager's pages, the sidebar)
  readonly property int iconSmall: 14
  readonly property int iconLarge: 24
  readonly property int sideWidth: 190
  readonly property int popupPadding: 16       // a popup's frame, every side (KitFrame)
  readonly property int popupWidth: 370
  // a window's frame: the gap to its edges on every side, and the space the
  // title's line keeps above its capitals (the header draws that far into its box)
  readonly property int windowPadding: 24
  readonly property int headerInset: 3
  readonly property int controlHeight: 30       // buttons, selects, fields: one height side by side
  readonly property int controlWidth: 300        // a setting's choices / field (KitRow wide)
  readonly property int buttonWidth: 120         // a setting's action button (text only, right aligned)
  readonly property int rowStackBelow: 480       // a wide KitRow narrower than this puts its control under the label
  readonly property int popupGap: 6
  readonly property int frameWidth: material ? 0 : 1          // controls: buttons, selects, fields
  readonly property int windowFrameWidth: material ? 1 : 2    // popup frames, like hypr windows, mako
  readonly property int hairline: 1                           // an outline in either style: wells, previews, cards at rest
  readonly property int ring: 2                               // the picked card's or tile's outline
  readonly property color focusRing: foreground2              // shared keyboard focus outline
  readonly property int focusRingWidth: 2
  readonly property int visibleRows: 8
  readonly property int popupStatusMs: 2500       // how long ok / error marks stay
  readonly property string ellipsis: "\u2026"

  // ---- the colour of a measured value ----
  // Green / yellow / orange for a measured value. Thresholds may ascend
  // (lower is better: ping, loss) or descend (higher is better: signal).
  function qualityColor(value, good, fair) {
    const lowerIsBetter = good <= fair;
    if (lowerIsBetter ? value <= good : value >= good) return green;
    if (lowerIsBetter ? value <= fair : value >= fair) return yellow;
    return orange;
  }

  // Latency color shared by every module; no measurement reads as muted.
  readonly property int pingGoodMs: 100
  readonly property int pingFairMs: 300

  function pingColor(ms) {
    return ms > 0 ? qualityColor(ms, pingGoodMs, pingFairMs) : muted;
  }

  // Load of a resource in %: yellow from 70, red from 90.
  function loadColor(percent) {
    return percent >= 90 ? red : percent >= 70 ? yellow : foreground0;
  }
}
