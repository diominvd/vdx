# UI/UX audit and implementation plan

This document is the working checklist for the shell-wide UI/UX pass. It deliberately separates verified observations from changes that need runtime testing.

## Progress

- [x] Clamp settings group label, row, and divider widths to zero or greater when a settings column becomes narrower than its horizontal insets.

- [x] Add the audit and acceptance criteria.
- [x] Add keyboard activation, Tab focus, visible focus styling, and accessibility metadata to the shared `KitButton`.
- [x] Add keyboard activation and a visible focus ring to `KitSwitch`; expose its accessible checked state.
- [x] Give `KitSwitch` pressed feedback for keyboard input and ignore Enter/Space auto-repeat to prevent accidental repeated toggles.
- [x] Mirror the switch's custom disabled state to Qt's built-in `enabled` state so disabled controls cannot retain keyboard focus and are exposed as disabled to accessibility clients.
- [x] Mirror `KitButton.disabled` to Qt's built-in `enabled` state while keeping busy buttons focusable and exposing their waiting description.
- [x] Remove the hover highlight from busy `KitButton` instances so controls that ignore activation do not retain a clickable hover affordance.
- [x] Add a distinct pressed-state fill/frame to `KitButton` so mouse and touch activation receive immediate visual feedback; busy/disabled controls do not show it.
- [x] Ensure already-selected buttons also visibly change fill while pressed instead of looking inert.
- [x] Show the same pressed feedback during keyboard activation and ignore key auto-repeat so holding Enter/Space cannot repeatedly trigger a button action.
- [x] Give shared Island icon buttons the same keyboard-held pressed feedback as their pointer scale/highlight.
- [x] Guard notification-card activation against keyboard auto-repeat while keeping the dismiss button independent.
- [x] Guard the Island notification overflow action and global power/media actions against held-key repeats; power-menu arrow navigation remains repeatable, while media track skips fire once per key press.
- [x] Avoid emitting a redundant `picked` signal when right-arrow navigation lands on the already-selected `KitSegments` option.
- [x] Expose the selected state of shared choice buttons through their accessible description, without overriding the busy/waiting announcement.
- [x] Keep `KitSegments` delegate widths finite when its model is temporarily empty.
- [x] Clamp stretched `KitChoices` widths to zero or greater when a narrow layout cannot fit all options.
- [x] Clamp the segmented-control label container and text width to zero or greater when a segment is narrower than its internal spacing.
- [x] Clamp backup path entry, package selection label, Shell Manager navigation, and search empty-state dimensions to zero or greater for compact windows.
- [x] Clamp Bluetooth and Wi-Fi connected-device name widths when status/battery labels consume the remaining row space.
- [x] Clamp package-list rows and gradient accent colour fields so subtractive width calculations cannot become negative.
- [x] Clamp colour-palette tile height when a compact popup cannot fit the normal two-row palette.
- [x] Clamp three-column folder-module tile widths when the popup is narrower than its padding and gutters.
- [x] Clamp `KitFrame` content width to zero or greater when a popup is temporarily narrower than its padding.
- [x] Clamp the `KitHeader` title/subtitle column to zero or greater when actions leave insufficient room in a compact popup.
- [x] Keep Files' parent/child columns proportional to the available viewport and reserve space for the central file list when saved widths would otherwise crowd it out.
- [x] Constrain and wrap Files empty/error/search-result messages to the list viewport so long search terms and status text do not spill past narrow windows.
- [x] Clamp the inline `KitSliderRow` value width to the row viewport so a narrow popup cannot let the reading extend beyond its parent.
- [x] Keep native Qt `enabled` state aligned with `disabled` in `KitSelect` and each `KitSegments` option; busy selects remain focusable to announce loading.
- [x] Connect setting labels to switches rendered by `KitToggleRow` and several standalone settings/module switches.
- [x] Inherit the visible `KitRow` label as the accessible name for a single switch when no explicit name is set.
- [x] Provide fallback accessible names for standalone `KitSwitch` and `KitSlider` instances when callers omit explicit labels.
- [x] Step `KitSlider` keyboard input from its currently displayed position so repeated keys work while external value updates are delayed.
- [x] Ignore non-finite slider input coordinates and guard pointer calculations when the slider has zero width.
- [x] Make package-list checkboxes keyboard operable and expose checkbox names, checked/partial state, and selection descriptions.
- [x] Reset the package list scroll position when switching tabs or changing installed-package filters/sort/cache view.
- [x] Reset the Shell Manager content scroll and clear stale group highlighting when changing main settings pages.
- [x] Add keyboard activation, arrow-key navigation, focus indication, and radio-button semantics to `KitSegments`.
- [x] Complete segmented-control keyboard activation with Enter and provide Home/End shortcuts to select and focus the first/last option.
- [x] Avoid emitting redundant `KitSegments.picked` events when keyboard navigation lands on the already-current value, while still moving keyboard focus.
- [x] Give segmented choice groups an accessible name inherited from their setting row, while keeping each segment's radio-button semantics.
- [x] Prevent Enter/Return from activating a colour swatch after it becomes disabled.
- [x] Add pressed feedback to the colour-field picker chip for pointer and held keyboard activation.
- [x] Add keyboard operation, highlight navigation, and accessibility metadata to `KitSelect`.
- [x] Make the `KitSliderRow` icon action keyboard reachable, visibly focused, and accessibly named; label the audio mute action.
- [x] Give the `KitSliderRow` icon action matching pressed-state feedback for mouse and held keyboard activation.
- [x] Allow `KitSliderRow` to provide a distinct accessible name for its slider without reusing the optional icon-action label.
- [x] Make the animation preview keyboard accessible, with focus feedback and a disabled state when animations are off.
- [x] Make Shell Manager sidebar sections, group jumps, and search results keyboard reachable with accessible names and visible focus.
- [x] Keep settings-search keyboard selection valid with zero matches, guard Enter on an empty result list, and center the no-match message.
- [x] Reset settings-search result scrolling on each query update and position the empty state in the ListView's content coordinates.
- [x] Expose the settings-search field's purpose and dynamic result-count/keyboard guidance to assistive technology through the shared input component.
- [x] Keep keyboard focus on sidebar sections and group links scrolled into the visible navigation viewport.
- [x] Make colour swatches and cross-page settings links keyboard accessible, with selected-state semantics and visible focus.
- [x] Give colour swatches roving Tab focus and left/right arrow-key selection in their visual direction, respecting left-to-right and right-to-left layout.
- [x] Guard swatch arrow navigation when a repeater delegate is temporarily unavailable during dynamic model updates.
- [x] Add keyboard activation and accessible labels to app sidebar rows and their separate action buttons.
- [x] Give settings cross-page links and app sidebar rows/actions distinct pressed feedback for pointer and keyboard activation.
- [x] Limit sidebar row hints to a fraction of the available width and elide both hint and main label so they cannot overlap in compact sidebars.
- [x] Elide Shell Manager section labels within a width budget that reserves space for the expand chevron, preventing long labels from colliding in compact sidebars.
- [x] Make the Island hub's Launcher and Keys chips keyboard reachable, focus-visible, and exposed as named buttons.
- [x] Give the Island hub's Launcher and Keys chips a pressed state for pointer and keyboard activation.
- [x] Make shared Island icon buttons keyboard reachable, focus-visible, and exposed as named buttons (including media, power, Shell Manager, and notification dismissal).
- [x] Make the Island clock keyboard accessible when configured to open the hub on click, with button semantics and visible focus.
- [x] Add matching pressed feedback to the Island clock when it is configured as a click target.
- [x] Make notification cards keyboard reachable with button semantics, an accessible name/description, visible focus, and Enter/Space activation while preserving the separate dismiss button.
- [x] Add hover and pressed feedback to Island notification cards without covering their content or merging the separate dismiss action.
- [x] Make the Island notification overflow action keyboard reachable with a visible focus ring and an accessible button name.
- [x] Expose Island power tiles as named, focus-visible buttons with keyboard activation and confirmation guidance.
- [x] Make Island media seeking keyboard accessible, with slider semantics, playback-time description, and left/right seeking.
- [x] Make the Shell Manager button in the regular bar keyboard reachable, accessibly named, and visibly focused.
- [x] Complete Island media seek keyboard controls with Up/Down and Home/End in addition to Left/Right.
- [x] Make the regular bar clock's full-date toggle keyboard reachable, accessibly named, and visibly focused.
- [x] Make the regular Bar network, AI usage, audio, battery, brightness, and chat popup triggers keyboard reachable with button semantics and visible focus.
- [x] Make the regular Bar screen-capture, overflow-folder, and Mihomo proxy triggers keyboard reachable with accessible button names and visible focus.
- [x] Make each overflow-folder popup tile a named, keyboard-activatable button with visible focus.
- [x] Make regular Bar music, themes, wallpapers, Bluetooth, notifications, clipboard, and task-manager triggers keyboard reachable with accessible button names and visible focus.
- [x] Make regular Bar system metrics, cleaner, backups, VirusTotal, package updates, display settings, and window-layout triggers keyboard reachable with accessible names and visible focus.
- [x] Make the collapsible system tray control keyboard reachable and give tray items accessible names, activation keys, and visible focus.
- [x] Add left/right arrow navigation between visible system tray items, skipping hidden passive items.
- [x] Make Hyprland workspace switching keyboard reachable with roving Tab focus, arrow navigation, Home/End, and accessible workspace names.
- [x] Make the regular Bar light/dark mode toggle keyboard reachable, accessibly named, and visibly focused; disable activation while the theme is busy.
- [x] Make both colour-picker triggers keyboard accessible and visibly focused.
- [x] Keep the colour picker's inner layout, hue strip, palette grid, and tiles at nonnegative widths when the popup is narrow; reduce gaps to fit the available space.
- [x] Ignore colour-picker pointer input when the saturation square or hue strip has zero dimensions, preventing invalid values from entering the HSV state.
- [x] Give the editable hexadecimal colour field an accessible name and announce valid/invalid input guidance.
- [x] Give the shared text input an explicit accessible name derived from its placeholder and announce password fields as such.
- [x] Allow a semantic accessible label to override the placeholder; apply it to the lock-screen password, authentication prompt and backup repository field.
- [x] Give the reset button a descriptive accessible name during its confirmation step and stop the confirmation timer when the reset becomes unavailable or is confirmed.
- [x] Keep the select's pointer feedback consistent while busy and support Enter as a switch activation key.
- [x] Keep the select's Home/End keyboard highlight visible by scrolling to the first/last option.
- [x] Prevent select arrow-key navigation from over-scrolling past the highlighted option.
- [x] Expose the select's current value and loading state in its accessible description.
- [x] Show an explicit empty state when a select has no options, and allow Escape to propagate when the select is already closed.
- [x] Include the currently highlighted option in the select's accessible description while navigating the open list.
- [x] Expose each `KitSelect` popup option as an accessible list item with its label, optional note, and committed selected state.
- [x] Close an open `KitSelect` popup when the control itself becomes hidden, preventing a stale expanded state when conditional settings rows disappear.
- [x] Clamp the select popup and scroller heights to non-negative values for extremely compact layouts or a non-positive `maxRows` setting.
- [x] Reconcile the highlighted select option when its model or current value changes while the popup is open, so keyboard activation cannot target a stale index.
- [x] Prevent select option labels from colliding with long notes in compact lists: labels and notes now elide within separate width budgets, and the inner list viewport never receives a negative width.
- [ ] Finish the inventory of standalone switches and test focus behavior in both control styles.
  - [x] Static inventory of the 87 changed QML files found all `KitSwitch` uses named explicitly or inheriting the visible `KitRow` label; the focus matrix still needs runtime testing.
- [x] Bundle local Phosphor Regular/Fill SVG pairs for all 95 legacy icon keys and add an explicit alias map.
- [x] Preserve explicitly filled semantic state icons (`heart-filled`) when the global Phosphor weight is Regular; verify its music-player and liked-track callers.
- [x] Keep battery level glyphs distinct across the available Phosphor levels: `battery-4` uses Medium and `battery-5` uses Full, preserving a visible change between those adjacent levels instead of collapsing both into Medium. The Phosphor set has fewer battery levels than Material, so the upper levels share Full.
- [x] Add an installer check that verifies both Phosphor variants exist for every declared alias.
- [x] Include the Phosphor MIT license with the bundled assets.
- [ ] Run repository checks and verify behavior in a live Quickshell session.

These changes are source edits only so far. No local Quickshell runtime or repository test run has been performed in this session; treat the controls as awaiting runtime verification.

## Scope

The shell exposes several independent choices that must continue to work together:

- Bar and Island presentation modes.
- Terminal and Material control styles.
- Light/dark themes, accent colours, corner geometry and motion settings.
- Shell Manager navigation, searchable settings, module/app settings and popups.
- A user-selectable icon weight.

A visual change is not complete until these combinations are checked; testing only one theme and one bar mode is insufficient.

## Audit findings from source

### Icons

- `kit/KitIcon.qml` is the shared icon renderer, so it is the correct migration boundary. Replacing assets in individual screens would create inconsistent naming and rendering rules.
- Baseline finding (addressed in this branch): the old renderer built asset paths from `Theme.round` and `ShellSettings.solidIcons`, coupling icon appearance to corner geometry. The shared renderer now prefers explicit Phosphor aliases and keeps Material only as a fallback.
- `kit/icons/material.txt` remains the legacy-key catalogue. The installer validates callers against that catalogue and separately verifies every Phosphor alias has both local variants.
- Phosphor has named weights (Thin, Light, Regular, Bold, Fill, Duotone), not Material's Rounded geometry axis. Icon weight must therefore be independent from the shell's corner setting.
- The explicit legacy-name → Phosphor-name map now covers all 95 keys in `material.txt`, including battery and network states. Direct string substitutions would be unsafe because names like `sun`, `text`, `grid`, `file`, and stateful icons are semantic aliases rather than guaranteed package filenames.
- Keep icons bundled locally. Runtime network fetching or a CDN would make the shell fragile offline and on first launch.

### Settings / navigation

- `ShellManager.qml` uses a left navigation rail and a separate page pane; the page structure and searchable index are central navigation contracts.
- The Packages app had fixed source/size/name column budgets and a fixed-width installed toolbar. At narrower window widths, the version column could become negative and the search field could be squeezed out. This branch now scales those column budgets with the list width and adapts the filter selectors; the narrowest supported runtime widths still need visual verification.
- The cache tab also used a fixed 260px version column and fixed 150px filter, with a fixed-width size label beside rollback actions. Those now clamp to the available row width, and size labels elide instead of competing with the action; verify the narrowest supported window at runtime.
- Shell Manager's page pane previously used a fixed 24px inset on both sides regardless of its width. The inset now scales down on compact panes (with an 8px floor), preserving more room for controls; verify actual minimum window sizes and page headers in Quickshell.
- `KitRow` now clamps the label/hint column to a nonnegative width when a trailing control is wider than a compact row, avoiding negative anchor geometry before wide rows switch to their stacked layout.
- The Installed Packages toolbar now uses a wrapping `Flow`; the search field retains a usable minimum width and filter selectors move to another line instead of clipping when the window is narrow.
- The Updates tab's select-all label now clamps its calculated width at zero, matching the Installed tab and avoiding negative text geometry in unusually narrow popups.
- Package name/source/size columns now scale down without hard minimum widths, and the version column receives only the remaining space; the list no longer exceeds its viewport solely because the window is narrower than the desktop column minimums.
- The package manager footer now stacks status text above a wrapping action flow, so the action buttons no longer force the status column to a negative width in compact windows.
- The file manager's path/search row clamps the breadcrumb width, and picker footer text fields cannot receive negative widths when Cancel/Accept controls consume the available space.
- The file preview now shrinks to preserve a minimum strip for the file list and collapses with its splitter when the body is too narrow, rather than extending beyond the window. The effective preview width also clamps invalid negative saved values.
- The file table now treats saved date/size/type widths as preferences: each visible column shrinks to the remaining viewport width and clamps its origin/separator, so narrow windows cannot push the table columns off-screen.
- The Wi-Fi speed-test view clamps path-leg and metric widths in compact popups; its throughput text now yields space to the Run again button and elides rather than overlapping it.
- The file context menu caps itself to the parent window width, clamps its inner column, and gives item labels and shortcut hints separate width budgets with elision.
- Cache-row size and rollback controls clamp to nonnegative widths, and the Installed tab's filter selectors cap themselves to the available pane width even below their normal minimum.
- `KitSliderRow` now clamps its inline slider width when the icon and value consume a narrow popup row, while preserving the full-width captioned layout.
- `KitSideRow` now separates the icon key from the accessible action name; removable USB rows announce the concrete Mount/Unmount action and device name instead of an icon identifier.
- Sidebar keyboard focus now scrolls its own `Flickable` to keep focused section/group links visible during Tab navigation; verify keyboard traversal at a short window height.
- `KitInput` now explicitly names its `TextInput` from the field placeholder and identifies masked inputs in its accessible description; confirm announcements with the screen reader available in the target desktop session.
- `KitHeader` now keeps a minimum 24px height to contain its fixed-height icon even when compact font settings make the title/action row shorter; verify popup headers with the smallest supported font and window sizes.
- `KitSwitch` now mirrors its custom `disabled` flag to Qt's built-in `enabled` state, aligning focus and accessibility semantics with the visual disabled state; verify disabled/focus behavior in a running session.
- `KitSwatches` now uses a single Tab stop for the selected (or first fallback) colour and supports left/right arrow navigation in the visual direction; verify keyboard focus and selection with both layout directions in a live session.
- `KitButton` now mirrors `disabled` to native `enabled`; `busy` remains focusable so assistive technology can receive its waiting description, while click and keyboard handlers continue to ignore activation. `KitSegments` guards delegate width division for an empty model. Verify both in a running session.
- The shared input also accepts `accessibleName`, used for the unlock password, authentication response and backup repository location so long or changing placeholders are not the only labels; verify these announcements in a live session.
- Search indexing is generated from page labels/hints. Any new or renamed settings row must regenerate the index and be checked for stale entries.
- Settings persist through `ShellSettings` / `ModuleSettings`; changing the shape or meaning of a stored key requires a migration and tests, not just a renamed control.
- The shell is a single Quickshell process. Shared controls and popup/service lifecycle changes have a wide blast radius and should be introduced in small, reviewable commits.

## Acceptance criteria

### Icon system

- [x] All 95 legacy icon keys have explicit Phosphor aliases, with local Regular and Fill variants.
- [ ] Verify no missing icons at runtime and check the visual result across themes/styles.
- [x] Phosphor weights are independent of theme corners, bar style and control style in the shared renderer's source.
- [x] Weight selection has a clear Regular default and preserves the existing `solidIcons` boolean preference without a settings migration.
- [x] Preserve the explicitly filled `heart-filled` state icon even when the global icon weight is set to Regular.
- [x] Give battery glyphs extra horizontal room without increasing their overall height.
- [ ] Legacy names are mapped explicitly; dynamic icons (battery, network, audio, OSD, playback) are covered.
- [ ] Tinting works in light/dark themes and with accent colours.
- [ ] Asset sizes and aspect ratios are respected; no layout shifts when an icon changes.
  - [x] `KitIcon` now uses `Image.PreserveAspectFit` so local SVG glyphs are not stretched to fill the icon box; runtime layout and tint checks remain pending.
- [x] The installer checks every alias has Regular/Fill assets and that every legacy catalogue key is mapped.
- [x] Static inventory of the PR branch confirms all 95 aliases resolve to both local Phosphor weights (89 distinct glyphs, 178 SVG assets; no missing pairs).
- [x] Phosphor MIT license is included with the bundled assets.

### UX consistency

- [ ] Every interactive control has a visible hover, pressed, focused, disabled and (where relevant) busy state.
  - [x] Shared buttons and switches give keyboard-press feedback, clear stuck press state on focus loss, and ignore activation-key auto-repeat.
  - [x] Select menus and search-result rows ignore Enter/Space auto-repeat so a held key cannot repeatedly open or activate them.
  - [x] Colour swatches ignore Enter/Space auto-repeat to avoid repeated selection callbacks.
  - [x] Island player buttons, hub chips, power-action tiles and the Shell Manager bar item ignore activation-key auto-repeat; this is especially important for destructive power actions.
  - [x] Colour picker triggers, settings cross-links and app sidebar rows/actions also ignore Enter/Space auto-repeat.
  - [x] Segmented choices ignore activation-key auto-repeat while preserving arrow-key navigation.
  - [x] Authentication confirmation, package checklist toggles and animation previews ignore activation-key auto-repeat.
  - [x] Slider-row icon actions also ignore activation-key auto-repeat.
- [x] Static sweep of the 87 changed QML files found no remaining unguarded legacy Enter/Return/Space activation handlers; segmented controls retain their guarded handlers and repeatable arrow navigation.
  - [x] Shell Manager section headers, in-page group jumps and both colour-field picker triggers use the same guard.
  - [x] Bar-module entry points for AI, audio, backup, battery, Bluetooth, brightness, capture, chat, cleaner, clipboard, clock, display, folder, Mihomo, mode, music and notifications ignore activation-key auto-repeat.
  - [x] Packages, system monitor, task manager, themes, tray, VirusTotal, wallpapers and Wi-Fi module entry points also guard activation; tray item actions are guarded separately while arrow-key navigation remains repeatable.
- [ ] Keyboard focus is visible and navigation does not depend on pointer hover.
- [ ] Search results are actionable, use meaningful labels, and never lead to empty or stale sections.
  - [x] Static review confirms label matches rank before hint/location matches, empty results have a centered state, Enter on zero results is guarded, keyboard selection is clamped, and `install.py check` validates the generated index; runtime and test execution remain pending.
- [ ] Long settings pages remain scrollable at smaller window sizes and do not hide their last row behind footers.
- [x] Reset confirmation uses an explicit action label (`Reset now?`), a distinct selected-state appearance and a two-step guard instead of an ambiguous prompt.
- [x] Expose the reset confirmation window and two-step requirement through the button's accessible description.
- [x] Use explicit `Confirm?` wording for Island power actions that require a second activation.
- [ ] Destructive/reset actions are distinct from normal actions and explain their scope.
- [ ] Toggles and selectors communicate whether changes apply immediately or require Apply/Enter.
- [ ] Loading, empty, error and permission-denied states are consistent across popups/apps.
- [ ] Bar and Island modes, Terminal and Material styles, light/dark themes, and sharp/round corners are checked separately.

## Implementation sequence

1. **Inventory and baseline:** catalogue icon names and usage; record current behavior and keep the existing check command green.
2. **Icon infrastructure (assets + aliases landed):** keep Phosphor assets local, preserve the existing icon-weight preference, and validate every alias. Remaining: inspect actual rendering/tinting and verify the full theme/style matrix in a running session.
3. **Shared controls:** audit the reusable `Kit*` controls first (buttons, rows, fields, toggles, headers, frames). Fix state/keyboard/spacing inconsistencies at the source rather than patching every screen.
4. **Shell Manager:** review information architecture, section labels, search, page headers, reset/apply behavior and narrow-window scrolling.
5. **Bar, Island and popups:** verify both presentation modes, icon alignment, focus/click behavior, notification lifecycle and transition states.
6. **Apps and modules:** apply the shared patterns to app windows and module popups; prioritize repeated patterns and visible errors.
7. **Verification:** run `./install.py check`, relevant Python tests and `qmllint` where available; manually exercise the acceptance matrix on a running session. Record checks that cannot be run in CI.

## Non-goals

- Do not change the shell's visual identity merely to imitate a generic desktop.
- Do not remove existing customization options without a migration or an explicit replacement.
- Do not claim a runtime interaction is verified based only on static source inspection.

- `IslandHub.qml`: Launcher and Keys chips now expose button semantics, visible keyboard focus, and Enter/Space activation; still requires a live Quickshell check.
