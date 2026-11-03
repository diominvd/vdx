# Writing shell code

The how-to for `packages/quickshell/shell/` (paths are relative to it). Rules
live elsewhere and are not repeated here: code rules in `CLAUDE.md`, visual
rules in [design.md](design.md), structure in [architecture.md](architecture.md).
This file is the recipes: copy the nearest existing file, then run the checklist.

## The principle: components, not copies

- A piece of UI or logic used twice becomes a component in `kit/` (UI) or a
  function in a singleton (logic). Three copies is already a defect.
- A page contains rows and nothing else: no drawing code, no `Rectangle` that
  mimics a control. If the kit lacks a control, add it to `kit/` first, then use it.
- Properties are the component's API. Callers set data (`label`, `model`,
  `current`); the component owns look, hover, focus, motion and accessibility.
  A caller never reaches into a component's children.
- A value comes from one place: a token (`Theme.*`), a setting, or a service.
  A literal that appears in two files is a missing token.
- State has one owner. The service owns it; faces and popups read it and call
  its functions. Never copy a service value into a local property that is
  written back later.
- A component that is only used by one page lives next to that page, not in `kit/`.

## The kit: use these before writing anything

Every Settings surface is built from these. Read a component's header comment
before using it; its properties are its whole API.

| Need | Component | Notes |
|---|---|---|
| a row: label + hint left, control right | `KitRow` | `wide` for segments / fields; `needs` + `needsAction` for a waiting row; `tip` for an info mark |
| a switch bound to a module option | `KitToggleRow` | `module`, `key`, `fallback`, `label`, `hint` |
| choices bound to a module option | `KitOptionRow` | `KitSegments` inside a wide row |
| a list over 5 / one that changes | `KitSelect` | stacks under its text in a narrow row, as `KitRow` |
| a size judged by eye | `KitSliderRow` | snapped, its stops shown |
| text or a number | `KitInput` | applies on Enter; `icon: "search"` for a search |
| a group caption | `KitLabel` | caps noun, `value` on the right, `about` for an info mark |
| a group end / a real rule | `KitLine` | `sectionBreak: false` for a header rule that stays visible |
| the grouping itself | `KitGrouper` | last child of every settings Column |
| a setting kept on another page | `KitLinkRow` | `target: "<page>:<group>"` |
| Reset with a confirmation | `KitResetButton` | `changed`, `onReset` |
| an empty pane | `KitEmptyState` | `title` + `hint` that says the next step |
| a page that waits for something | `KitNotice` | one line + the fixing button |
| an icon on a plate (an entry's face) | `KitIconPlate` | `size` is the plate |
| a list row's icon | `KitIconTile` | follows Appearance › Icons › Framed |
| a panel app's dim / island / layout | `KitPanelOptions` | `module` |
| a search panel's two toggles | `KitClearSearchRow`, `KitEnglishRow` | `module` |
| a picker popup's cards or list | `KitPickerViewRow` | `module` |
| an index of entries + one entry's page | `EntryBrowser` (`apps/shellmanager`) | Apps and Bar modules; see the recipe below |

A block of rows that two settings files share is a component like the last four:
a `KitToggleRow` / `KitOptionRow` / `Column` with the fixed parts written in it
and `module` left to the caller. Its labels are literals, so the search index can
read them (see "Recipe: a shared option block").

## Tokens: what to use instead of a literal

| Instead of | Use |
|---|---|
| `spacing: 8`, `margins: 4` | `Theme.gapTight` 2, `gapHair` 4, `gapSmall` 6, `gapMedium` 8, `gapLoose` 10, `gapWide` 12, `gapGroup` 14 |
| gap between page sections | `Theme.sectionGap` |
| `radius: height / 2` | `Theme.pill(height)`; boxes `radiusSurface` / `radiusCard` / `radiusControl` |
| `color: "transparent"` | `Theme.clear` (black flashes on fade) |
| `border.width: 1` | `Theme.frameWidth`; dividers `KitLine` |
| `font.pixelSize: 13` | `Theme.fontSize ± n` (display figures excepted, see design.md) |
| hex colour | a `Theme.*` role; semantic: `Theme.red`, `green`, `muted`, `foreground0` |
| `duration: 150` | `Motion.quick` / `normal` / `slow`, `enabled: Motion.<part>` |
| `n + " DEVICES"` | `Format.count(n, "DEVICE")` (one noun, the `s` in its case; `many` for irregular ones) |
| control height `34` | `Theme.controlHeight`, `rowHeight`, `navigationHeight` |

A value used once, and no one else would want, may stay a literal. A hex that is
a mix target or a parse fallback is not a colour in the UI and may stay.

## Recipe: a Settings page

A page is a `Column` that ends the grouping with `KitGrouper {}`. Its header is
read from its own properties.

```qml
import QtQuick
import qs.config
import qs.kit

// Short page note: what it holds, group by group.
Column {
  id: root

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "curve"
  readonly property string title: "Motion"
  readonly property string description: "How the shell moves. Off, everything snaps in place."

  // the header's Reset: these ShellSettings keys back to their defaults
  readonly property var resetKeys: ["motion", "motionSpeed"]
  readonly property bool changed: ShellSettings.changed(resetKeys)
  function reset() { ShellSettings.reset(resetKeys); }

  // groups for the Shell Manager's sidebar: a click scrolls to `y`
  readonly property var jumps: [
    { key: "general", label: "General", y: generalGroup.y }
  ]

  spacing: Theme.sectionGap

  // ---- general ----
  KitLabel { id: generalGroup; text: "GENERAL" }

  KitRow {
    label: "Animations"
    hint: "Off: everything snaps in place"
    KitSwitch { checked: ShellSettings.motion; onToggled: ShellSettings.set("motion", !checked) }
  }

  KitRow {
    wide: true
    label: "Speed"
    hint: "How long every move takes"
    KitSegments {
      model: [{ label: "Slow", value: "slow" }, { label: "Normal", value: "normal" }, { label: "Fast", value: "fast" }]
      current: ShellSettings.motionSpeed
      onPicked: value => ShellSettings.set("motionSpeed", value)
    }
  }

  KitGrouper {}
}
```

Steps:

1. File in `apps/shellmanager/<Name>Page.qml`.
2. Register: an entry in `allSections` (`value`, `label`, `icon`, `caption` to open
   a sidebar group, `page` + `pageTab` to be a tab of another page) and a
   `Component { id: …Component; <Name>Page { width: pages.width } }` in `ShellManager.qml`.
3. A new `ShellSettings` key: declare its default in `ShellState`, add the
   `readonly property` in `ShellSettings.qml` with a comment of its values.
   A changed stored shape also needs a migration (CLAUDE.md › Settings).
4. Add the page to `PAGES` in `scripts/settings_index.py` and run it: the search
   index (`config/settings-index.json`) must match, `check` fails on a stale one.
5. `./install.py link`, restart, open the page in both styles (Strict, Material)
   and both corners (sharp, round).

## Recipe: a browser page (Apps, Bar modules)

A page over many entries, each with its own options, is an `EntryBrowser`: an
index of cards (a search, then a titled grid per section) and, once one is
picked, that entry across the whole pane (its heading, then its options). The
way back is the crumb in the window's header, `‹ All modules / AI`: the page gives
`backLabel` ("" on the index), `here` and `back()`. Never a third column of navigation beside the sidebar: it
leaves the options too narrow and every wide row stacks.

```qml
Item {
  id: root
  readonly property string icon: "puzzle"
  readonly property string title: "Bar modules"
  readonly property string description: "What each bar module shows and how its popup behaves."
  readonly property var jumps: []                 // the index does the sidebar's job

  // another page or `shell open modules:<id>` opens one
  function jump(id) { selected = id; }

  property string selected: ""                    // "" is the index
  // the header's crumb: "‹ All modules / AI"
  readonly property string backLabel: selected !== "" ? "All modules" : ""
  readonly property string here: entries.find(e => e.id === selected)?.label ?? ""
  function back() { selected = ""; }
  readonly property var entries: BarLayout.modules.map(p => ({
    id: p.id, label: p.label, icon: p.icon, about: p.about,
    state: "Hub chip",                            // a card's few words
    note: "In the hub, as a chip",                // the heading's, when longer; "" for none
    ok: true,                                     // the state is good news: a green dot
    off: false,                                   // not installed: muted
    section: "on"                                 // a key of `sections`
  }))

  EntryBrowser {
    anchors.fill: parent
    model: root.entries
    sections: [{ key: "on", label: "ON THE BAR" }, { key: "off", label: "OFF THE BAR" }]
    selected: root.selected
    searchHint: "Search modules…"
    onPicked: id => root.selected = id
    trailing: KitResetButton { /* … */ }          // keys, Reset: right of the heading

    // the options: rows as on any page, ending with their own grouper
    KitLinkRow { label: "Move on the bar"; hint: "In Bar › Layout"; target: "bar:layout" }
    KitLine {}
    Loader { width: parent.width; source: /* the entry's <Name>Settings.qml */ "" }
    KitGrouper {}
  }
}
```

- The page is an `Item` (it fills the window; `ShellManager` lists the tab in its
  full-height pages).
- Card words are short (`Hub chip`, `Right`); the heading may say them in full (`note`).
- A state already shown below (the window's size on Apps) is not repeated in the
  heading: `note: ""`.
- Keys: Tab reaches each card, Enter / Space open it, Enter in the search opens the
  first match; the back and arrow buttons are ordinary `KitButton`s.

## Recipe: a shared option block

When two settings files have the same rows, write them once in `kit/` (or next to
the page that owns them) and give the caller only the module id:

```qml
// kit/KitEnglishRow.qml
KitToggleRow {
  key: "english"; fallback: true
  label: "English layout on open"
  hint: "Switches the keyboard when it opens"
}

// a caller
KitEnglishRow { module: "launcher" }
```

The search index reads literal `label:` / `hint:` from the settings files, so the
block's name goes into `INCLUDES` in `scripts/settings_index.py`: a file that uses
it is read with the block's text in its place. Use it in one line with no nested
braces (`Block { module: "x" }`), keep row labels out of its comments, and run the
script: an unchanged index means no row was lost. `tests/test_settings_index.py`
checks a block's rows are found under each page that uses it.

A block that is a `Column` ends with its own `KitGrouper {}` and starts with a row
or a `KitLabel`: KitGrouper walks into it and its rows join the page's groups.

## Recipe: a module's options (`<Name>Settings.qml`)

Rows bound to `ModuleSettings`; the default is written at the row and in the
module, and they must agree.

```qml
KitColumn {
  spacing: Theme.sectionGap

  KitLabel { text: "POPUP"; about: "How the popup behaves" }

  KitToggleRow { module: "notifications"; key: "closeOnClear"; fallback: false
                 label: "Close after Clear all"; hint: "Off: the centre stays open" }

  KitOptionRow { module: "notifications"; key: "rows"; fallback: 6
                 label: "Notifications shown"; hint: "Before the list scrolls"
                 model: [{ label: "4", value: 4 }, { label: "6", value: 6 }, { label: "10", value: 10 }] }

  KitGrouper {}
}
```

## Recipe: choosing a control

Follow design.md › "Control by the job". Short version: on/off → `KitSwitch`;
2–5 named alternatives → `KitSegments` in `KitRow { wide: true }`; a size by eye
→ `KitSliderRow`; a long or changing list → `KitSelect`; exact text or number →
`KitInput`; a named colour → `KitSwatches`; named plus own colours → `KitColourRow`.

A setting that waits for something uses `KitRow.needs` + `needsAction`
(`needs: Theme.island ? "" : "Island style only"`, `needsAction: "Use Island"`,
`onNeedsActed: …`). It never hides the row and never explains itself in a hint.

A setting kept on another page: `KitLinkRow` (label = the setting, hint
`In <Page> › <Group>`).

## Recipe: a bar module

Follow CLAUDE.md › A module (script, service, face, popup, register, component).
Specifics that are easy to miss:

- The service owns every `Process` and `Timer`. A poll runs only while its data
  is shown (`popupShown()` / `popupHidden()`); a poll that must always run (the
  island reads it) is the exception, and gets a comment saying who needs it.
- A command whose result is guessed (an optimistic flip) re-reads the truth when
  the process exits: `Process { id: set; onExited: root.refresh() }`.
- Text on the face goes through `BarLayout.faceText(id, content)`.
- Opening a module from elsewhere: `BarLayout.openModule(id)`.

## Recipe: a service

```qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What it owns, who reads it, who writes it.
Singleton {
  id: root

  // ---- tuning ----
  readonly property int pollMs: 15000
  readonly property string script: Paths.scriptsDir + "/<id>.sh"

  // ---- state ----
  property bool busy: false
  property string status: ""
  property string error: ""

  // ---- actions ----
  function refresh() { if (!read.running) read.running = true; }

  Process {
    id: read
    command: [root.script, "--status"]
    stdout: StdioCollector { onStreamFinished: root.parse(text) }
  }
}
```

`parse()` goes through `kit/reply.js` (`Reply.parse` for objects, `Reply.parseList`
for arrays). A failure sets `error`, never a silent empty state. A `Process` is
guarded before it starts (`if (!p.running)`), so a double click cannot start two.

## Performance

- Hidden UI is created on demand (`Loader { active: shown }`), not hidden with
  `visible: false`.
- No timer, listener or process runs for a window that is closed.
- No binding that re-runs a loop over a big model on every frame; compute once
  in a property and read it.
- A `Repeater` over a model that changes remakes all its items: key it with
  `KitSeen` / `KitAppear` where rows appear.
- Measure a costly path before and after (`qs log`, `top -p $(pgrep -f 'qs -c shell')`).

## Review checklist (run before every commit)

1. Literals: `grep -rnE '(spacing|margins): *[0-9]+'`, `"transparent"`, `"#`,
   `pixelSize: *[0-9]`, `radius: .*(height|width) */ *2`, `border.width: *[0-9]`,
   `duration: *[0-9]`. Each hit is a token or a reason.
   One top-level `KitGrouper {}` per page column (`grep -c '^  KitGrouper {}'`): each extra one
   adds a second gap between groups; groups of a flat page are parted by `KitLine {}`.
2. Repeats: the same block twice → component. The same comment twice in a file
   → one of them is misplaced (it happened: a `jumps` comment above `resetKeys`).
3. Both styles (Strict, Material), both corners, a narrow window (rows stack
   under `Theme.rowStackBelow`: the control then spans the row under its text,
   never a short one at the right edge), light and dark theme.
4. Keyboard: Tab reaches every control, Space / Enter act, Escape cancels, focus
   ring visible. Accessible names on icon-only buttons and list rows.
5. States: empty, loading (`busy` / `KitSpinner`), error (red `KitText` under the
   group), disabled (`needs` or `Set by …`), the failure of the command.
6. Search: every `label:` / `hint:` is a literal; run `scripts/settings_index.py`.
7. Reset: the page's `resetKeys` lists every key the page writes.
8. `./install.py check` is green; `qs log -c shell | grep -E 'ERROR|WARN'` has
   nothing new from the QML.
9. Docs: a rule or fact found on the way goes into its topic file in the same commit.

## Pitfalls that cost time

See CLAUDE.md › QML pitfalls. Besides them:

- A comment is part of the code: move it with the line it describes.
- A `Behavior` fades a fill from `Theme.clear`; from `"transparent"` it flashes dark.
- `zsh` expands `--include=*.qml` itself: quote the glob when grepping.
- Editing a file with `sed -i` breaks live reload; use the editor in place.
- An optimistic UI flip needs a reconcile, or a failed command leaves it lying.
- A caption that hides while its row stays (a `needs` row) leaves the row in the
  previous group's box: keep the caption, the row says what it waits for.
- `qs list --all` prints `Process ID: <n>`: restart with
  `kill $(qs list --all | awk '/Process ID/{print $3}')`, then the supervisor.
- A component whose rows the search should find goes in `INCLUDES`
  (`scripts/settings_index.py`), or its rows vanish from the search.
