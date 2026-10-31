pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User options set in the Shell Manager, kept in the state dir
// (settings.json). Add an option: a property on `state` and a readonly alias
// here, a control in ShellManager's Appearance tab.
Singleton {
  id: root

  readonly property string iconSet: state.iconSet                 // material | phosphor | lucide (Appearance › Shape)
  readonly property bool solidIcons: state.solidIcons             // Material and Phosphor: the filled twins
  readonly property bool iconTiles: state.iconTiles               // list icons in framed tiles (Appearance › Icons)
  readonly property bool menuIcons: state.menuIcons               // an icon before each page in the Shell Manager's list
  readonly property string managerStart: state.managerStart        // main | last: the page the Shell Manager opens on
  readonly property string managerTab: state.managerTab            // the page it was left on
  readonly property string font: state.font                       // family, kept in step with fontconfig
  readonly property int textSize: state.textSize                  // px, the shell's text (Theme.fontSize): 12 | 13 | 14 | 15
  readonly property string inputAlign: state.inputAlign           // auto | left | center: where the text stands in a field (auto: left, a password in the middle)
  readonly property string underlineAnimation: state.underlineAnimation  // none | grow | slide
  readonly property string wallpaperMode: state.wallpaperMode     // theme | custom | image
  readonly property var wallpaperImages: state.wallpaperImages     // theme -> picture (WallpaperService.pathOf)
  readonly property string wallpaperColor: state.wallpaperColor   // #rrggbb, for custom
  readonly property var wallpaperOutputs: state.wallpaperOutputs   // theme -> {output: picture}: monitors with their own
  readonly property bool exclusiveSound: state.exclusiveSound     // one source at a time: the music, the radio, an app's media — starting one pauses the rest
  readonly property bool pauseMusic: state.pauseMusic             // MPD pauses while another app plays sound
  readonly property bool resumeMusic: state.resumeMusic           // ...and resumes once that sound stops
  readonly property bool barRightSettings: state.barRightSettings // a right click on a bar module opens its options
  readonly property bool barFolderDot: state.barFolderDot         // a dot on the Folder for unseen notices
  readonly property string barDotColor: state.barDotColor         // theme | red | orange | yellow | green | aqua | blue | purple: that dot's colour
  readonly property bool material: state.material                 // controls filled, no frames (Appearance › Controls)
  readonly property bool segmentedSliders: state.segmentedSliders   // Strict: split fill and remainder into two pills
  // the accent (Appearance › Colours): two stops, the first the colour, the second
  // the gradient's end when accentGradient is on. A stop is a colour name (theme =
  // the theme's frame colour | red | … | purple) or "custom", its colour in
  // accentCustom (one #rrggbb per stop, "" until one is typed)
  readonly property bool accent: state.accent                     // the accent on at all (off: monochrome)
  readonly property bool accentGradient: state.accentGradient
  readonly property var accentStops: state.accentStops
  readonly property var accentCustom: Array.isArray(state.accentCustom) ? state.accentCustom : ["", ""]
  // the user's own colours (#rrggbb, at most customColoursMax): the accent's picker always offers them, the other colour
  // choices only with shareColours (Appearance › Colours › Share own colours)
  readonly property var customColours: Array.isArray(state.customColours) ? state.customColours : []
  readonly property bool shareColours: state.shareColours
  readonly property int customColoursMax: state.customColoursMax   // how many own colours (Appearance › Colours › Own colours)
  function addCustomColour(hex) {
    if (customColours.length < customColoursMax && !customColours.includes(hex)) set("customColours", customColours.concat([hex]));
  }
  function removeCustomColour(hex) { set("customColours", customColours.filter(c => c !== hex)); }
  readonly property var accentWhere: state.accentWhere            // target key -> true: what takes the accent
  // the glow (Appearance › Glow): a halo behind bright elements; glowWhere: target key -> false when switched off
  readonly property bool glow: state.glow
  readonly property int glowStrength: state.glowStrength          // 0..100
  readonly property var glowWhere: state.glowWhere
  readonly property bool passwordDots: state.passwordDots         // legacy import compatibility; password fields always use dots
  readonly property string corners: state.corners                 // sharp | round: the whole shell's corners
  readonly property int cornerRadius: state.cornerRadius          // px, a popup's corner while round (Theme scales the rest)
  readonly property bool cornerSplit: state.cornerSplit            // each part on its own slider (cornerRadii)
  readonly property var cornerRadii: state.cornerRadii              // part (windows | cards | controls | bar) -> its R, px
  readonly property string barStyle: state.barStyle               // solid | island: one strip, or one live island
  // the look of the bar, kept apart for each shape: switching solid <-> island brings its own back
  readonly property var looks: state.looks                        // shape -> { key: value }
  readonly property int barIconGrow: look("barIconGrow")          // px added to the bar's icons: 0 | 2 | 4
  readonly property bool barSeparators: look("barSeparators")     // "|" between the bar's modules
  readonly property int barGap: look("barGap")                    // px each side of a separator (Theme.separatorMargin)
  readonly property string clockOpens: look("clockOpens")         // hover | click: how the island's hub opens from the clock
  readonly property int pillHeight: look("pillHeight", "island")   // px: 0 follows the control style
  readonly property bool hubPlayer: look("hubPlayer")             // the track (the player) shows in the island's hub
  // the island's live activities (Bar › Live): each kind on or off, the order
  // inside its section (the priority), how long a flash stays
  readonly property int liveNoticeMs: look("liveNoticeMs", "island")  // a notification's line stays this long (0: until read)
  readonly property int liveFlashMs: look("liveFlashMs", "island")          // a flash stays this long
  readonly property bool liveFocusClick: look("liveFocusClick", "island")  // a click on the Focus activity ends the mode
  readonly property bool liveFront: look("liveFront", "island")    // an activity that starts takes the pill
  readonly property bool liveWheel: look("liveWheel", "island")
  readonly property bool liveRightSettings: look("liveRightSettings", "island")  // a right click on an activity opens its options
  readonly property int liveBatteryBelow: look("liveBatteryBelow", "island") // %, low battery interrupts below this
  readonly property string liveBatteryStay: look("liveBatteryStay", "island") // fixed | 5s
  readonly property bool liveRadioAlways: look("liveRadioAlways", "island")  // the radio stays in the live slot even when it is off
  readonly property bool liveRadioPaused: look("liveRadioPaused", "island")  // the radio stays in the live slot on pause
  readonly property bool liveMediaPaused: look("liveMediaPaused", "island")  // another app's media stays in the live slot on pause
  readonly property bool liveMusicPaused: look("liveMusicPaused", "island")  // the music stays in the live slot on pause
  readonly property string liveNoticeMark: look("liveNoticeMark", "island")  // avatar | dot: what marks a message in the live slot
  readonly property bool liveMusicAlways: look("liveMusicAlways", "island")  // the music stays in the live slot with no player at all
  readonly property var liveSections: ({
    asks:  ["notice", "battery", "bluetooth"],
    held:  ["recording", "update", "backup", "timer", "vpn", "focus", "radio", "music", "media"],
    flash: ["volume", "mic", "layout", "plugged"]
  })
  readonly property bool liveEnabled: look("liveEnabled", "island")  // the master switch: off, nothing shows in the live slot
  // one kind's own switch, and whether it is in effect (the master switch too)
  // (the messages are Notifications › Show new ones as: Live activity — one setting, two doors)
  function liveKind(kind) {
    if (kind === "notice") return ModuleSettings.get("notifications", "appear", "card") === "live";
    return look("live" + kind.charAt(0).toUpperCase() + kind.slice(1), "island");
  }
  function liveOn(kind) { return liveEnabled && liveKind(kind); }
  // a section's kinds in the owner's order (what is not listed keeps its place at the end)
  function liveOrdered(section) {
    const base = liveSections[section] ?? [];
    const saved = (look("liveOrder", "island") ?? {})[section] ?? [];
    return saved.filter(k => base.includes(k)).concat(base.filter(k => !saved.includes(k)));
  }
  function liveSetOrder(section, list) {
    setLook("liveOrder", Object.assign({}, look("liveOrder", "island") ?? {}, { [section]: list }), "island");
  }
  readonly property var lookDefaults: ({ barIconGrow: 0, barSeparators: true, barGap: 5, clockOpens: "hover", hubPlayer: true, pillHeight: 0,
    liveEnabled: true, liveBattery: true, liveBluetooth: true,
    liveRecording: true, liveUpdate: true, liveBackup: true, liveTimer: true, liveRadio: true, liveRadioPaused: true, liveRadioAlways: false, liveMedia: true, liveMediaPaused: false, liveVpn: false, liveFocus: true, liveMusic: true, liveMusicPaused: false, liveMusicAlways: false, liveNoticeMark: "avatar",
    liveVolume: true, liveMic: true, liveLayout: true, livePlugged: true,
    liveFront: true, liveFocusClick: true, liveFlashMs: 1500, liveNoticeMs: 5000, liveWheel: true, liveRightSettings: true,
    liveBatteryBelow: 20, liveBatteryStay: "fixed", liveOrder: ({}) })
  // animations (Shell Manager › Animations; Motion reads them)
  readonly property bool motion: state.motion                     // all of them on / off
  readonly property string motionSpeed: state.motionSpeed         // slow | normal | fast
  readonly property string motionPopups: state.motionPopups       // none | fade | slide | grow
  readonly property bool motionPanels: state.motionPanels         // launcher, keybinds, switcher, overview
  readonly property bool motionControls: state.motionControls     // buttons, switches, selects, level bars
  readonly property bool motionBar: state.motionBar               // workspaces, bar values
  readonly property bool motionPages: state.motionPages           // Shell Manager pages and sidebar
  readonly property bool motionTabs: state.motionTabs             // the sections of a page (Interface / Colours / Glow)
  readonly property bool motionIsland: state.motionIsland         // the island morphing between its views
  readonly property bool motionLock: state.motionLock             // the lock screen coming in, a wrong password

  // Whether the Shell Manager window is open (not saved).
  property bool managerOpen: false

  function set(key, value) { state[key] = value; }

  // keys back to their defaults; managerTab is not an option
  readonly property var keys: Object.keys(defaults).filter(k => typeof defaults[k] !== "function"
    && !["objectName", "version", "managerTab"].includes(k))
  function reset(list) { for (const k of list) state[k] = JSON.parse(JSON.stringify(defaults[k])); }
  function changed(list) { return list.some(k => JSON.stringify(state[k]) !== JSON.stringify(defaults[k])); }
  ShellState { id: defaults }

  // the current shape's value of a look option, else its default
  function look(key, shape) {
    const v = (looks[shape ?? barStyle] ?? {})[key];
    return v === undefined ? lookDefaults[key] : v;
  }

  // looks saved for a shape under these keys (any key given: was it ever changed) and the way back
  function looksTouched(keys, shape) { return keys.some(k => ((looks[shape ?? "island"] ?? {})[k]) !== undefined); }
  function looksReset(keys, shape) {
    const target = shape ?? "island";
    const all = Object.assign({}, looks);
    const mine = Object.assign({}, all[target] ?? {});
    for (const k of Object.keys(mine)) if (keys.includes(k)) delete mine[k];
    all[target] = mine;
    state.looks = all;
  }
  // the island's live-activity keys: every look key that starts with `live`
  readonly property bool liveChanged: Object.keys(looks.island ?? {}).some(k => k.startsWith("live"))
  function liveReset() { looksReset(Object.keys(looks.island ?? {}).filter(k => k.startsWith("live"))); }

  function setLook(key, value, shape) {
    const target = shape ?? barStyle;
    const all = Object.assign({}, looks);
    all[target] = Object.assign({}, all[target] ?? {}, { [key]: value });
    state.looks = all;
  }

  // until the file is read the options are their defaults (barStyle solid):
  // the bars wait for it (shell.qml), or the island window starts as a strip
  property bool loaded: false
  // no settings.json yet: the shell's very first start (a hint toast, shell.qml); not saved
  property bool firstRun: false

  FileView {
    path: Quickshell.statePath("settings.json")
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    onLoaded: root.loaded = true
    onLoadFailed: error => {
      root.firstRun = error === FileViewError.FileNotFound;
      writeAdapter();
      root.loaded = true;
    }

    ShellState { id: state }
  }
}
