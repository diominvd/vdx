# Shell design system

The shell's UI rules: tokens, controls, wording, colour, motion. Binding for
every face, popup, window and Settings page of `packages/quickshell/shell/`
(paths below are relative to it). Code rules: `packages/quickshell/shell/CLAUDE.md`.
Rules without a keyword are MUST; new rules say MUST / SHOULD / MAY.

## Basics

Minimal, monospace, near-monochrome. Reference: the Wi-Fi popup.

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
- Controls: Appearance › Style (Terminal | Material). A control's frame is
  `Theme.frameWidth` (0 in material), its fill `Theme.controlFill` /
  `controlHover`, a popup's frame `Theme.popupFrame`. Never a literal 1.
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
- Popup: `KitHeader` → `KitLine` → groups separated by `KitLine` → footer.
  No backgrounds under groups.
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
  `Choose…` button (`FilesService.pickFolder` / `pick`, the Files window's
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
- Keyboard and accessibility: every shared action control MUST be reachable by Tab,
  expose a visible focus ring, and activate with Enter/Space where appropriate.
  Switches expose their setting label and checked state; icon-only buttons provide
  an explicit human-readable accessible name (the icon key is only a fallback).
  Disabled and busy controls MUST ignore activation from both pointer and keyboard.
  Do not rely on hover as the only state cue.
- Selected = `background3` fill + ExtraBold; its text takes the accent only when
  Choices is on (rule 2). Hover =
  `background1` (one step up from the surface).
- Colour rules (the look has one exception, the accent):
  1. Default: colour is state only. Green ok, yellow / orange attention, red error.
     Everything else is shades of the theme (`Theme.foreground*`, `background*`, `gray`).
  2. Accent: the user's own colour (Appearance › Accent: one colour or a
     gradient, `Theme.accent` / `Theme.accentEnd`). Off by default. It takes only the
     places of APPLIES TO (`Theme.accentOn(key)` / `accentFor(key, fallback)`); a new place gets a key there, never a literal colour.
  3. A warning colour is never replaced by the accent: a load, a low battery, an error, a mute keep theirs.
     The active state of a module (on, playing, charging, connected) is the accent's place
     `modules` (APPLIES TO › Bar modules): `Theme.accentFor("modules", <its colour>)`. Its colour
     options then show a note and are disabled (`KitSwatches { disabled }`).
  4. A gradient is a `Gradient` from `accent` to `accentEnd`; a text, a dot or an outline
     takes `accent` alone.
  No hex in QML — `Theme.*` only (a custom colour is picked on the spectrum or typed in Shell Manager and
  kept in settings). Dimmed screens use `Theme.scrim`.
- Text: secondary text (hints, captions, times) is `Theme.muted`, lifted to
  4.5:1 on `background0` in every theme; `gray` is for frames, ticks, icons and
  inactive text only. Sizes are `Theme.fontSize ± n` (Fonts › Text size,
  12–15), never a literal. Display figures are fixed sizes: the lock's
  clock, Overview's workspace numbers, the Fonts page's specimen.
- Bar: one colour per item; a missing value shows `--`.
- Key hints: `Super + S`; footers `key action · key action`, lowercase.
- Icons: Phosphor SVGs are the preferred local set in `kit/icons/phosphor/`.
  `KitIcon.solid` selects the matching `-fill.svg` variant; icon weight is
  independent of corner shape. Existing Material-era icon keys remain supported
  by the alias map in `KitIcon.qml`; unmapped keys use the legacy Material
  assets. The vendored Phosphor icons are MIT-licensed (see
  `kit/icons/phosphor/LICENSE`). `icons/material.txt` documents the legacy set.
- Refactors keep the look; a new look is prototyped on one popup first.
- Motion: every animation goes through `config/Motion.qml` — a Behavior takes
  `enabled: Motion.<part>` (popups, panels, controls, bar, pages, lock, island) and a
  duration from it (`quick`, `normal`, `slow`, `ms()`), easing `Motion.easing` (`morph` for a shape that resizes, `tint` for a colour);
  set in Shell Manager › Animations. Rows that show and hide sit in a
  `KitColumn` (KitFrame's column is one): they fade in, the rest glide. A
  list's new row (a Repeater remakes them all): `KitAppear` keyed in the list's
  `KitSeen`. A hover / selected fill fades (`Motion.controls`, `quick`) from
  `Theme.clear`, never `"transparent"` (black: it flashes dark); rows in a
  filled box hover with `Theme.controlHover`, the whole row lit, not the text.

## Settings pages

Pages by the user's area; the look follows macOS System Settings.

- MUST — groups: every settings Column (page, section, `<Name>Settings.qml`) ends
  with `KitGrouper {}`. A `KitLabel` starts a group, a `KitLine` ends it; the rows
  between sit inset in one raised box (`background1`, `radiusCard`) with a
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
  A search over the list works on one mode (Appearance › Mode) at a time. ↑/↓
  previews, Enter / Apply switches, Esc goes back.
  Apps, Bar modules and Themes fill the window and scroll their panes, not the page.
  Fonts: a card per font written in itself, with its state (in use, installed,
  not installed: a second click downloads).
  Cursor: its shapes large, colour and size, a card per cursor theme; a pick waits
  for Apply.
- MUST — a page's side list (Apps, Bar modules, Themes) is one look: a search
  field, then the entries in one raised box (`background1`, `radiusCard`) to the
  pane's foot; rows `radiusControl`, picked `background3` + ExtraBold, hover
  `background2`. Apps and Bar modules use `EntryList`; a new list copies it.
- A pick list longer than a few rows is a page of cards, not a long select; a
  `KitSelect` shows `maxRows` and scrolls, a choice's `note` says its state.
- MUST — colour: `KitColourPicker` is one low panel in a row: a saturation ×
  brightness square, a vertical hue strip, palette tiles in two rows filling its
  height (the picked one has a ring; a tile that is not a plain colour — the theme's,
  your own — has an icon, `icons`). Window frames (off | theme | accent) are
  in Windows › Look.
- A caption over a slider (an app's name, a device) sits `gapMedium` above it;
  never `gapTight`.
- Sliders in a box use the row layout (label left, value right). A snapped slider
  always shows its stops, at most 11 (every n-th of a long run). Controls ›
  Material draws Material 3's slider (thick track split by a bar handle, stops as
  dots); Terminal the thin one.

- MUST: where a setting lives follows the user's area, not the code: every bar
  module's options in Bar modules (an app's module too), an app's own options in
  Apps, Lock screen and Notifications on their own pages.
- MUST — link row: a setting kept on another page shows a row where it is also
  looked for: `KitLinkRow` — label = the setting, hint `In <Page> › <Group>`;
  the whole row is the button, a chevron on the right.
- MUST — overridden: a row another setting overrides stays visible and
  `disabled`, hint `Set by <Page> › <Row>`; a row meaningless without its parent
  hides with it (above).
- MUST — reset: two-step, `KitResetButton` (`Reset` → `Reset now?` for 3 s, then
  back), right of the page's or item's header; disabled while nothing differs
  from the defaults.
- MUST — colour choice: named colours → `KitSwatches`; a free colour →
  `KitColourField` + `KitColourPicker`.
- MUST — error: a failed apply shows red `KitText` under the group that failed,
  wrapped, `Theme.fontSize - 1`; it clears on the next success.
- MUST — pending: an apply that runs (install, reload) shows `busy` on its
  button or a `KitSpinner`; the rest of the page stays usable.
- IN PROGRESS — focus and keyboard access: `KitButton`, `KitSwitch`, `KitSegments` and `KitSelect` now have keyboard handling and/or visible focus indication plus accessibility metadata. Continue auditing standalone controls and unify the focus-ring token/style; verify behavior at runtime. The intended behavior is that Space toggles a switch, arrows navigate choices, Enter activates, and `Accessible.name` comes from the row's label. Current design details follow: one token `Theme.focusRing`, a 2 px `foreground2`
  outline at `radiusControl`, on keyboard focus only; Space toggles a switch,
  arrows move Choices, Enter activates; `Accessible.name` = the row's label.
- SHOULD — no "Advanced" fold: rarely used groups go last on their page.
- SHOULD — a page header's subtitle holds at most three parts; group labels
  carry their own values.
- MUST — search: every row's label and hint is a literal string where it can be
  (the search index reads them, `scripts/settings_index.py`).
