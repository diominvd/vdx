# UI/UX redesign status

Branch: `feat/phosphor-ui-ux`  
Pull request: [#2](https://github.com/diominvd/vdx/pull/2) — keep as Draft until implementation and runtime verification are complete.

This status separates source-level fixes from a completed visual redesign. A changed QML file or a passing static inventory is not proof that the screen's information architecture, visual hierarchy, or live behavior has been redesigned successfully.

## 1. Done in source; still needs runtime verification

- Shared controls have received extensive keyboard/accessibility work: focus indication, Enter/Space activation, repeat-key guards, accessible names/state, and disabled/busy handling.
- Many compact layouts now clamp widths/heights and adapt to narrow windows, including Shell Manager, Files, Packages, Task Manager, Launcher, popups, and module views.
- Phosphor Regular/Fill assets and explicit aliases are bundled for the 95 legacy icon keys.
- Several dynamic-state and navigation edge cases have been guarded.
- The detailed per-control checklist remains in [ui-ux-audit.md](ui-ux-audit.md).

**Important:** These are mostly interaction consistency, accessibility, asset migration, and defensive-layout improvements. They do not, by themselves, amount to a full visual redesign.

## 1.1 Focused fixes made during the ongoing pass

- Added shared focus-ring tokens and applied them across common controls, Shell Manager navigation, and text inputs. Text fields now retain a visible 2 px focus outline in Material style, where their resting frame is normally absent.
- Improved the settings search's accessible description so the idle, no-results, and results states are distinct; the empty state now suggests trying another name or keyword.
- Corrected Shell Manager group-jump target calculations to include the page content's top inset, avoiding a consistent scroll offset. This is source-level reasoning and still needs runtime confirmation.
- Made the currently selected settings group visibly distinct from hover-only group links, and removed a duplicate text-alignment assignment in the search empty state.
- Applied the shared focus-ring token to notification cards and the notification overflow action, plus hub chips, the clock, media slider, and power-menu tiles. The shared Island icon-button component still needs its own verification/fix if it does not inherit this styling.
- Made the Island clock keyboard-focusable when configured for hover-to-open as well as click-to-open; Enter/Space can now open the hub regardless of the pointer interaction preference.
- Added explicit accessible group names to the Bar shape, icon-size, module-gap, and Island hub-opening controls; Animation speed, popup animation, and underline animation controls; shell/GTK text-size controls; icon weight, accent fill, corner shape, and cursor colour/size controls; and the Music window opening-page selector.
- Added accessible names to the segmented controls in Files settings, including view, density, sorting, search limits, opening behavior, picker sizing, and recent-file limits.
- Made font and cursor theme cards reachable with Tab, named them for assistive technology, added Enter/Space activation, and applied the shared focus-ring styling to their keyboard focus state.
- Added a clear no-results message to the theme picker and described its search field and keyboard shortcuts for assistive technology. Theme cards are also keyboard reachable, announce their theme/selection state, support Space to preview and Enter to apply, and show the shared focus ring.
- Clarified the saved-Wi-Fi empty state and named the dynamic sidebar visibility and custom-action removal controls in Files settings.
- Made the shared app/module entry list keyboard navigable and accessible, with a visible focus ring and automatic scrolling to the selected entry. Added a helpful empty state when filtering returns no entries.

## 2. Partially done

- **Icon system:** asset/alias coverage is statically complete, but actual tinting, visual weight, alignment, and dynamic-state choices have not been verified in a live session. The alias map still needs a semantic review, not only a filename check.
- **Responsive behavior:** many negative-size and overflow cases have been guarded in code, but minimum supported window sizes and narrow popup layouts need visual checks.
- **Keyboard navigation:** many controls have source-level support, but the focus path and focus-ring contrast need to be exercised in Quickshell across both control styles.
- **Shell Manager:** source already has a grouped sidebar, searchable settings index, page headers, jump links, and reset affordances. The remaining task is to assess and improve the actual information architecture, page-level hierarchy, search/no-result behavior, and compact-window usability—not merely add more defensive width calculations.
- **Shared visual language:** design rules exist in `design.md`, but implementation must be checked for drift: row spacing, group surfaces, selected/hover/pressed/disabled states, typography, focus styling, and light/dark contrast.

## 3. Not yet demonstrated as done

- A screen-by-screen visual review and intentional redesign of Shell Manager, Bar, Island, popups, apps, and modules.
- A complete interaction-state matrix: idle, hover, pressed, focused, selected, disabled, busy, empty, loading, error, and permission-denied where applicable.
- The full presentation matrix: Bar and Island; Terminal and Material; light and dark; sharp and round corners; accent off/on.
- Live checks that Phosphor SVGs are correctly tinted and no legacy/Unicode icon paths remain where Phosphor is expected.
- Repository checks, QML lint/build checks where available, and manual regression testing in a running Quickshell session.

## 4. Implementation order

1. **Baseline and inventory:** compare the current PR diff against these criteria; record which items are source-complete, partial, or untouched. Do not count broad file churn as visual progress.
2. **Shell Manager:** review the sidebar taxonomy, search, page headings, group labels, reset/apply behavior, and compact-window scrolling. Make a focused change, then inspect its diff.
3. **Shared controls:** align the focus-ring token and state styling at the shared-component level; fix inconsistencies once in `Kit*` rather than per screen.
4. **Bar and Island:** review spacing, icon sizing, active states, popup transitions, notifications, and keyboard/pointer parity.
5. **Apps and modules:** work through repeated patterns and visible usability issues, then validate loading/empty/error/permission states.
6. **Icon completion:** inspect every alias semantically and verify tint/geometry in a live session.
7. **Verification:** run `./install.py check`, relevant tests and available QML lint/build checks; manually exercise the acceptance matrix. Record anything that cannot be run.

## 5. Guardrails

- Keep all work on `feat/phosphor-ui-ux`; do not merge into `main`.
- Preserve both Terminal and Material styles and all existing customization settings unless a replacement/migration is explicitly implemented.
- Keep the shell's distinctive minimal/monospace identity; do not replace it with a generic desktop template.
- Prefer focused, reviewable changes over sweeping rewrites.
- Never mark a live behavior as verified from static source inspection alone.
