# Shell design system

The shell's UI rules: tokens, controls, wording, colour, motion. Binding for
every face, popup, window and Settings page of `packages/quickshell/shell/`
(paths below are relative to it). Code rules: `packages/quickshell/shell/CLAUDE.md`.
Rules without a keyword are MUST; new rules say MUST / SHOULD / MAY.

## Basics

Minimal, monospace, near-monochrome. Two visual languages share the same
components and settings: Strict uses outlines and quiet surfaces; Material 3
uses tonal layers and more spacious controls.

- Corners: Appearance › Shape › Corners (sharp | round + one radius). A radius is
  always a token: `Theme.radiusSurface` (popups, windows, panels),
  `radiusCard` (tiles, previews, cards), `radiusControl` (buttons, fields,
  rows, checkboxes), `Theme.pill(h)` / `radiusFor(h)` (tracks, knobs, switches, the
  resting island); all 0 when sharp. One slider (R) sets them all in proportion:
  surface R, card 0.6 R, a thing h high h × R / 48 (pills only at the top stop).
  Separately: a slider per part (windows, cards, controls, the bar), each R read the
  same way (`Theme.cornerOf(part)`), so one tick looks alike on every part; the
  one slider hides while they show.
  No literal `height / 2` for a corner.
  An image in a rounded tile sits in a `ClippingRectangle`.
- Controls: Appearance › Style (Strict | Material, a select). A control's frame is
  `Theme.frameWidth` (0 in material) in `Theme.controlLineRest` (`controlLineHover`
  under the pointer, focused or open), its fill `Theme.controlFill` /
  `controlHover`, a popup's frame `Theme.popupFrame`. Never a literal 1.
  Picked (a choice, a segment, a nav row): `Theme.pickFill` + `Theme.pickWeight`.
  Strict: a Settings box is a raised card (`groupFill`, a faint `controlLineRest` frame) and the controls in it are plates one step above it (`fillOn(boxed)`, a faint 1 px frame); `KitSegments` is an outlined track
  with the picked segment a plate inset 3 px, no check; `KitSwitch` off is an
  outlined dark track with a grey knob, on a light track with a dark knob; a
  field has no prompt, a thin cursor, an optional `icon` (search); a Settings
  group's box is a raised card; a window's sidebar
  is `Theme.sideFill`. In both styles a Shell Manager page header
  (`KitHeader { page: true }`) is a large title with no icon.
  An outline drawn in either style (a well, a preview, a card at rest) is
  `Theme.hairline`, a picked card's or tile's `Theme.ring`.
  Material follows Material 3 (primary = `foreground0`, or the accent where it
  applies). A button is tonal. `KitSegments` is an outlined track split by
  hairlines, the picked segment filled with a check. `KitSwitch` is an outlined
  track with a small handle; on: filled with a large handle and a check.
  A field or select is filled with square lower corners and a bottom line, thick
  while focused (`KitFieldLine`). The slider is below.

- Spacing: the gaps and edge insets are `Theme.gapHair` (4), `gapTight` (2),
  `gapSmall` (6), `gapMedium` (8), `gapLoose` (10), `gapWide` (12) and `gapGroup`
  (14); a value that is used once stays a literal.
- MUST — dividers: use `KitLine`, horizontally or with `vertical: true`.
  The stroke is `Theme.dividerThickness` (1 px), in `Theme.dividerColor`
  (`outlineVariant`) in both styles. The line owns no margins. A surrounding
  section Column uses `Theme.sectionGap` (8 px) on both sides; a fixed header
  uses the same gap above its line and below it. Do not add spacer Items after
  a divider. Anchored pane edges and table rules use the same stroke with the
  pane/table's existing inset. The bar's `Separator` also uses this stroke;
  `separatorMargin` remains the user's horizontal module spacing.
  In grouped settings, a default `KitLine` is a semantic card boundary:
  KitGrouper suppresses its stroke and collapses redundant space before a
  heading. `KitLine { sectionBreak: false }` is an actual header/table rule,
  remains unboxed and visible, and requires no wrapper. Grouping MUST preserve
  the caller's `visible` binding. Physical dividers in grouped forms are centred
  between the rendered header caption and the following card surface, including
  the card's row inset. Headers expose `kitCaption` for this measurement;
  font descender space and taller trailing actions do not count as caption ink. Settings card row insets are separately
  `Theme.settingsRowInset` (6 px); they are not header separator spacing.
- Popup: `KitHeader` → `KitLine` → groups separated by `KitLine` → footer.
  No backgrounds under groups.
- Sidebar: an app window with several pages (Backups, Cleaner, Packages, Task Manager,
  Files, Music) shows them in a sidebar, not as tabs in the header: `KitSidebar` (brand
  header, a line level with the page header's, rows of `KitSideRow`) at the left, the page
  at `side.right` with its own `KitHeader` (the page's icon and name). Rows are 4 px apart
  (`gapHair`), their icon is `KitIconTile` (bare or framed by Appearance › Icons, off with
  Shell Manager's menu icons), the picked row `pickFill`. A window with one page and no
  tabs has none.
- Window: the frame is `Theme.windowPadding` (24) on every side and nothing else:
  the header sits at `windowPadding - Theme.headerInset`, a footer at
  `bottomMargin: Theme.windowPadding`. A `KitFrame` window sets `headerInset`
  instead of offsets. Popups keep 16.
- Header: icon, title in normal case, subtitle in caps joined by ` · `. Tabs are `KitChoices` on its right; a Shell Manager page lists them as `tabs` + `tab`.
- Group: `KitLabel` in caps (a noun, current value on the right), then rows.
- Row: `KitRow` — label (capitalised) and hint (sentence case, no full stop)
  left, control right. A hint in a wide row ≤ 29 chars (the Modules page
  leaves ~32); elsewhere ≤ ~40. A hint adds something (effect, caveat,
  off-state) or is left out; it never repeats the label.
- Control by the job: a feature on/off → `KitSwitch` (one row per item of a
  set, under a caps label with the count: `APPLIES TO` `3 OF 7`). 2–5 named equal
  alternatives (24h | 12h too) → `KitChoices { stretch: true }` in `KitRow
  { wide: true }`. A size judged by eye with a live result (gaps, radius,
  shares, blur) → `KitSliderRow`, value on the right, snapped to its step.
  A list over 5 or one that changes (monitors, models, tabs) → `KitSelect`.
  An exact number or text → `KitInput` (Enter). A folder or file → `KitInput` + a
  `Choose…` button (`FilesService.pickFolder` / `pick`, the file picker's own window's
  A password → `KitInput { echoMode: TextInput.Password }`: it carries its own eye, and where text
  stands (left, centre) is the user's (Text › Input text), never set per field.
  picker). A long list to preview + Apply → a searchable list and a preview, as
  on Themes. A slider of 3–4 stops is chips.
  On a Settings page the choices are `KitSegments` (one track, the picked segment
  raised); `KitChoices` stays for popups and header tabs.
- Wording: visibility toggles `Show …` (hint `Off: icon only`); `Close after …`
  / `Close when its window opens`; `Opens on`; `<Things> shown`. Off / None is
  the first chip; time units in each chip (`5 s`, `30 min`). British spelling.
- Group names: `BAR` (the module's face), `POPUP`, `WINDOW` / `LIST`,
  `OPENING`, `SAFETY` (the "Ask before …" toggles); a row shown only with
  another option sits under it and hides with it.
- Selected = `Theme.pickFill` + `pickWeight`; its text takes the accent only when
  Choices is on (rule 2). Hover =
  `background1` (one step up from the surface).
- Colour rules (the look has one exception, the accent):
  1. Default: colour is state only. Green ok, yellow / orange attention, red error.
     Everything else is shades of the theme (`Theme.foreground*`, `background*`, `gray`).
  2. Accent: the user's palette colour (Appearance › Colours: one named colour,
     `Theme.accent` / `Theme.accentEnd`). Off by default. It takes only the
     places of APPLIES TO (`Theme.accentOn(key)` / `accentFor(key, fallback)`); a new place gets a key there, never a literal colour.
  3. A warning colour is never replaced by the accent: a load, a low battery, an error, a mute keep theirs.
     The active state of a module (on, playing, charging, connected) is the accent's place
     `modules` (APPLIES TO › Bar modules): `Theme.accentFor("modules", <its colour>)`. Its colour
     options then show a note and are disabled (`KitSwatches { disabled }`).
  4. Legacy imported gradients remain readable: a `Gradient` runs from `accent`
     to `accentEnd`; text, dots and outlines take `accent` alone.
  Glow (Appearance › Glow) is separate: a bright element gets a `KitGlow` in its own
  colour, keyed by a Glow target (`Theme.glowOn(key)`); never a hand-made shadow.
  No hex in QML — `Theme.*` only. Legacy custom colours remain in settings.
  Dimmed screens use `Theme.scrim`.
- Text: secondary text (hints, captions, times) is `Theme.muted`, lifted to
  4.5:1 on the highest normal control surface in every theme; `gray` is for frames, ticks, icons and
  inactive text only. Sizes are `Theme.fontSize ± n` (Fonts › Text size,
  12–15), never a literal. Display figures are fixed sizes: the lock's
  clock, Overview's workspace numbers, the Fonts page's specimen.
- Bar: one colour per item; a missing value shows `--`.
- Key hints: `Super + S`; footers `key action · key action`, lowercase.
- Icons: Material Symbols SVG in `kit/icons`, `fill="#ffffff"`; every icon
  has a filled twin of the same name in `solid/` and Rounded twins in
  `round/` and `round/solid/` (Material names: `icons/material.txt`), Phosphor
  twins in `phosphor/` and `phosphor/solid/` (`icons/phosphor.txt`, one set for
  both corners), and a Lucide twin in `lucide/`, outline only,
  `stroke="#ffffff"` (`icons/lucide.txt`).
  Icons picks the set; Lucide has no solid, so a state an icon shows
  by `solid` also needs a tint.
- Refactors keep the look; a new look is prototyped on one popup first.
- Motion: every animation goes through `config/Motion.qml` — a Behavior takes
  `enabled: Motion.<part>` (popups, panels, controls, bar, pages, lock, island) and a
  duration from it (`quick`, `normal`, `slow`, `ms()`), easing `Motion.easing` (`morph` for a shape that resizes, `tint` for a colour);
  set in Shell Manager › Motion. Rows that show and hide sit in a
  `KitColumn` (KitFrame's column is one): they fade in at their final positions; group geometry settles immediately. A
  list's new row (a Repeater remakes them all): `KitAppear` keyed in the list's
  `KitSeen`. A hover / selected fill fades (`Motion.controls`, `quick`) from
  `Theme.clear`, never `"transparent"` (black: it flashes dark); rows in a
  filled box hover with `Theme.controlHover`, the whole row lit, not the text.

## Settings pages

Pages by the user's area; the look follows macOS System Settings.

- MUST — groups: every settings Column (page, section, `<Name>Settings.qml`) ends
  with `KitGrouper {}`. A `KitLabel` starts a group, a `KitLine` ends it; the rows
  between sit inset in one box (`Theme.groupFill`, `radiusCard`) with a
  hairline between rows. A title that is not a KitLabel declares
  `readonly property bool isKitLabel: true`; a visual that stands on the page
  (a preview, a board of chips, theme cards) declares `property bool kitUnboxed: true`.
  No page width cap: the box links a label to its control.
- MUST — controls in a box take their fill one step up (`Theme.fillOn(boxed)`,
  `hoverOn`); a well inside a box (list, preview, sample) is `background0`.
- MUST — Themes, Fonts and Cursor are pages of their own in the sidebar. There
  are no links to them from Appearance.
  Themes: a theme picker as in a terminal. The list on the left shows a small
  desktop in its colours (`ThemeMock`), name, light or dark and its cast, and a
  check on the active one. A large preview in the picked theme's colours sits on
  the right (code, a prompt, controls, the colours and tones as named pills).
  A search over the list works on one mode (Themes › Dark / Light) at a time. ↑/↓
  previews, Enter / Apply switches, Esc goes back.
  Apps, Bar modules and Themes fill the window and scroll their panes, not the page.
  Fonts: a card per font written in itself, with its state (in use, installed,
  not installed: a second click downloads).
  Cursor: its shapes large, colour and size, a card per cursor theme; a pick waits
  for Apply.
- MUST — a page's side list (Apps, Bar modules, Themes) is one look: a search
  field, then the entries in one box (`Theme.groupFill`, `radiusCard`) to the
  pane's foot; rows `radiusControl`, picked `Theme.pickFill` + `Theme.pickWeight`, hover
  `Theme.controlHover`. Apps and Bar modules use `EntryList`; a new list copies it.
- A pick list longer than a few rows is a page of cards, not a long select; a
  `KitSelect` shows `maxRows` and scrolls, a choice's `note` says its state.
- MUST — colour: every colour choice starts with `Theme.colourSet` (the theme's
  own colour first, then red … purple), as small dots. A choice that takes the
  user's own colours is `KitColourRow`: they sit right of a divider, at most the Own colours limit, a
  cross over one on hover removes it, the plus dot (last on the right) turns the row
  into a strip (hue plate, shade plate, preview, tick). Custom values and gradients
  from older settings remain readable. Window frames (off | theme | accent) are
  in Windows › Look.
- A caption over a slider (an app's name, a device) sits `gapMedium` above it;
  never `gapTight`.
- Sliders in a box use the row layout (label left, value right). Strict can choose
  the classic plate or the split two-segment plate in Appearance › Interface. A snapped slider
  always shows its stops, at most 11 (every n-th of a long run). Controls ›
  Material draws Material 3's slider (thick track split by a bar handle, stops as
  dots); Strict can use the classic thin track or the split plate with rounded
  active and remainder segments. A captioned Settings slider keeps its label
  beside the track; colour ramps stay thin.

- MUST: one pattern for a setting that waits for something (`KitRow.needs`). The row
  stays in sight, its control is out of reach, and the phrase where the hint was says
  what it waits for, with one button that fixes it: `Island style only` · `Use Island`;
  `Needs <Row> on` · `Turn on`; `Put <Module> in the Hub row` · `Arrange`;
  `Not installed: <component>`. A child of a switch in the same block hides with its
  parent instead (the parent's hint says what it opens). Hardware that cannot change
  (no battery) hides the row and the block says so once. A whole page waiting for the
  style opens with a `KitNotice` banner. The search reads the phrase as the row's hint.
- MUST: where a setting lives follows the user's area, not the code: every bar
  module's options in Bar modules (an app's module too), an app's own options in
  Apps, Lock screen and Notifications on their own pages.
- MUST — link row: a setting kept on another page shows a row where it is also
  looked for: `KitLinkRow` — label = the setting, hint `In <Page> › <Group>`;
  the whole row is the button, a chevron on the right.
- MUST — overridden: a row another setting overrides stays visible and
  `disabled`, hint `Set by <Page> › <Row>`; a row meaningless without its parent
  hides with it (above).
- MUST — reset: two-step, `KitResetButton` (`Reset` → `Sure?` for 3 s, then
  back), right of the page's or item's header; disabled while nothing differs
  from the defaults.
- MUST — colour choice: named colours → `KitSwatches`; named plus the user's
  own → `KitColourRow`.
- MUST — error: a failed apply shows red `KitText` under the group that failed,
  wrapped, `Theme.fontSize - 1`; it clears on the next success.
- MUST — pending: an apply that runs (install, reload) shows `busy` on its
  button or a `KitSpinner`; the rest of the page stays usable.
- MUST — focus: `Theme.focusRing` with `Theme.focusWidth` outlines focused
  controls. Buttons accept Space / Enter, switches Space / Enter, segments
  Left / Right / Home / End, sliders Left / Right. Selects accept Space to open,
  Up / Down to highlight, Enter to commit, Escape to cancel. Disabled / busy
  controls cannot activate. Switches inherit `Accessible.name` from their row;
  icon buttons fall back to their icon's name. Lists and custom app actions
  should supply descriptive names and keyboard handling as they adopt the kit.
- SHOULD — no "Advanced" fold: rarely used groups go last on their page.
- SHOULD — a page header's subtitle holds at most three parts; group labels
  carry their own values.
- MUST — search: every row's label and hint is a literal string where it can be
  (the search index reads them, `scripts/settings_index.py`).

## Shared roles and density

- MUST — semantic surfaces are derived in Theme from the active palette:
  `surfaceContainer`, `surfaceHigh`, `surfaceHighest`, `onSurfaceVariant`,
  `outline`, `outlineVariant`, `secondaryContainer`. This adapts the M3 role
  hierarchy to existing palettes; it is not a generated HCT tonal palette.
- MUST — body text uses Normal, action labels Medium, selected items DemiBold.
  Large page titles use Medium. Avoid ExtraBold for routine selection.
- MUST — shared control height is 34 in Strict, 36 in Material; setting rows
  at least 40, navigation 34 / 36. Wide settings stack below `Theme.rowStackBelow` (420 px) of
  available row width. Use `Theme.rowHeight` / `navigationHeight` instead of
  copying these values into pages.
- MUST — Material settings groups use `Theme.groupFill` without outlines;
  Strict groups are raised cards in a faint outline. Nested controls use
  `fillOn` / `hoverOn`; lines use `outlineVariant`.
- MUST — text/handles placed on a custom solid accent use `Theme.inkOn(fill)`;
  gradient handles use `Theme.inkOnGradient(first, last)`. The latter chooses
  the better minimum contrast at the endpoints; arbitrary gradients can still
  have poor contrast between their endpoints.
- Shape remains an independent user preference in both styles. Material does
  not force rounded windows when the user has chosen sharp corners.

## Settings navigation and previews

- Appearance separates Interface, Accent and Glow. Interface includes corners;
  Wallpaper has its own page.
- Bar separates Layout, Look and Monitors. Layout selects Solid / Island and
  arranges modules; the module inspector offers destination and order controls
  as an alternative to drag. Available modules are searchable.
- Hub and Live activities have their own pages. Hub appearance
  options always address the Island settings, even when Solid is active.
- Fonts and Cursor use searchable rows and one preview. Picking a row does
  not apply it. Downloads and changes use an explicit action. Themes applies
  the variant currently shown by its preview, including Light / Dark.
- Password fields always use dots. The old key remains readable for settings
  import compatibility but is no longer an appearance choice.
- Scrollbars use a 2 px thumb, hidden at rest, in a separate gutter.
- A `kitUnboxed` pane is a grouping boundary: a nested KitGrouper owns its own
  boxes rather than joining groups across unrelated columns.

## Strict reference direction

- Dense instrument-panel typography, quiet thin frames and low-contrast tonal
  steps. Preserve the selected theme palette rather than hardcoding black.
- Layers: page, a raised card per group, a control plate in the card; each a
  small tonal step, rows divided by hairlines. Hover adds a neutral lift,
  selection a stronger one. Material retains its tonal containers.
- Accent marks selection and meaningful readings, never a whole decorative
  panel. Normal status colours remain semantic.
- Every KitSelect expands inline and reserves space before the next item;
  lists never float over following controls. Popup and settings hosts share
  this behaviour, keyboard interaction and scrolling limits.
