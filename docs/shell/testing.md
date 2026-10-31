# Shell testing and release checks

What can be checked, how, and what stays manual. Commit rules ("Before a
commit", "Before a push"): [repo/commits.md](../repo/commits.md) — not repeated here.

## Automated

| Command | Covers |
|---|---|
| `./install.py check` | all groups below |
| `./install.py check syntax` | py compile, json/jsonc, toml, xml, `bash -n`, `zsh -n`, `luac -p`, qmllint **syntax only** (`/usr/lib/qt6/bin/qmllint`) |
| `./install.py check shell` | icons and their solid / rounded twins, module ids registered in `ModuleFaces` and `components.toml`, the settings search index current |
| `./install.py check tests` | `tests/` (unittest): installer and doctor, `files.py`, `display.py`, `backup.py`, shell gating, portal config, settings migrate / export-import / search index, `supervise.sh` (a kill, a config error, a crash loop, its toasts dismissed) |
| `./install.py check hypr` | `Hyprland --verify-config` with and without `machine/` |
| `./install.py check components` | the catalog against the repo and pacman |
| `ruff check` | Python lint (`ruff.toml`) |
| `python tests/check_shell_ui.py` | offscreen QML behaviour: shared controls, keyboard, disabled/busy states, inline selects, grouping, layout copies and backend reply parsing |
| `python -m unittest tests.test_overview` | Overview: workspace gaps, wide/narrow insertion slots, shared placement, Lua width policy and focus restoration, production QML drag/cancel/drop/failure and card lifetime with an isolated compositor stub |
| `python -m unittest tests.test_files_actions` | production FilesActions with real Quickshell child processes, an isolated runtime and a fake backend: FIFO, reply isolation, failure, cancellation and completion reentrancy |
| `python -m unittest tests.test_capture_recorder` | production recorder lifecycle offscreen, with a fake recorder: delayed cancellation, request snapshots, overlap guards, output verification, pause/resume and restart |
| `python -m unittest tests.test_capture_save tests.test_capture_saver tests.test_capture_clipboard` | Save as backend, production model and clipboard phase: retry, replacement confirmation, queued requests, discard, cross-filesystem copies and partial-output cleanup, all in temporary directories |
| `git ls-files '*.sh' \| grep -v ^packages/nvim \| xargs shellcheck -S warning` | shell scripts |
| `tests/fresh-machine.sh [defaults \| component…]` | clean Arch in podman: setup, doctor, verify, second setup, uninstall (slow) |

The QML harness uses an isolated, memory-only settings store and substitutes
Quickshell's clipping rectangle. It does not verify GPU rendering, compositor
focus, hardware, or real system actions. It runs separately from unittest.
Logic that can live in a backend script or a pure JS file SHOULD go there so
it can be tested independently.

## Shell runtime checks (manual)

- Log: `qs log -c shell | grep -E 'ERROR|WARN'` — empty after the change.
- Restart (new files, IPC changes): see `packages/quickshell/shell/CLAUDE.md` › Work. From a terminal
  opened before Hyprland restarted, `HYPRLAND_INSTANCE_SIGNATURE` is stale: a shell
  started from it has no Hyprland (start it through `hyprctl -i <instance> eval …`,
  the instance from `hyprctl instances -j`).
- Open a surface: `qs -c shell ipc call <target> toggle`.
- Screenshot: `grim -g "X,Y WxH" out.png`.
- Notifications: `notify-send -a Test "title" "body"`; mako state `makoctl list -j`, `makoctl history -j`, `makoctl mode`.
- Audio: `pactl list sources`, `pactl -f json list sinks`.
- Wallpaper: `awww query`; cache `~/.cache/awww/<version>/`.
- Settings state: stop the shell before editing `modules.json` by hand (it is written on exit).

## Regression scenarios by area

Each area lists the scenarios it touches; these are the shared base.

| Area | Scenarios |
|---|---|
| Bar styles | Solid and Island; one and two monitors; child bars; open each touched popup; hub from the clock |
| Appearance | sharp / round corners; outlined / material controls; accent off / on; one non-gruvbox theme |
| Settings | value persists across a shell restart; applies without restart; reopen the page; default when the key is absent |
| Optional parts | the feature's component off (`./install.py components remove <c>`, `link`): no QML errors, module "not installed" |
| Missing hardware / service | binary absent, service stopped, no device: the UI shows a state, the log stays clean |
| Files: USB | plug a stick: a USB row appears (unmounted: size shown, power button); its button mounts it (eject then); the eject button unmounts; unplug: the row goes. Only a real stick tests this |
| Lock | lock, wrong password, right password, every monitor, after a theme switch |
| UI states | default, hover, focus (keyboard), active / selected, disabled, loading, error, empty, unavailable — each that applies to the touched control or view |
| Settings lifecycle | reset to default; migration from an old state file (copy of `by-shell/<id>/`); two settings that affect one feature changed in both orders |

## Known limits

### Audit checkpoint (2026-10-30)

Current validation: 291 Python tests and 102 QML cases. Full repository checks
and Python lint pass.
These counts include baseline tests; they do not imply
that every shell function or desktop scenario has been reviewed.

| Reviewed area | Automated coverage |
|---|---|
| Live device smoke check (2026-10-30) | Read-only backend status succeeded for battery, PipeWire, Wi-Fi, Bluetooth and Hyprland displays; Wi-Fi scan populated three networks and the Bluetooth popup rendered the paired AirPods state. No connection, volume, power or display settings were changed |
| List reply compatibility | Eight production consumer handlers with populated/empty arrays, error objects, null and malformed JSON; separate object/list parser contracts |
| Shared controls / Launcher | Object-only backend replies; select activation and pending states; literal search, query cancellation and navigation bounds |
| Files | Production selection model: Shift extension/contraction, visible-row pruning and single picker selection; FIFO mutations and cancellation; history changes only after success and creation redo without duplicate entries; folder-list process-start failure clears loading and reports an error |
| Packages | Update-check and installed-list process-start failures clear busy state and report an error |
| Backup | Status-query process-start failure replaces the loading label with an unavailable state and reports the error |
| Capture | Recorder lifecycle with real child processes; late callbacks and countdown cancellation; save/discard backend and failures, replacement confirmation, busy/error/edit panel states and tracked clipboard completion; file-operation process-start failures preserve the request and clear busy state |
| Clipboard | History and action process-start failures are reported in the popup |
| Popup hosting | Repeated attachment, switching popups, restoration of borrowed items, unrelated host children, leaving Island style, host and source destruction |
| Popup arbitration | Production manager with isolated monitor/settings: reactive ownership, fallback, disconnected screens, duplicate registration, teardown, module close preference and capture hold |
| Root actions | Six process tests: pending cancellation, overlap rejection, backend/authorization errors, error reset and listeners starting or cancelling the next request during completion |
| Lock preparation | Six fake-grim process tests: parallel capture, overlap rejection, failure, timeout, TERM-resistant children, launch failure and completion reentry; production lock routing and screen-selection fallback in a lightweight fixture |
| Lock lifecycle | Production controller with fake storage: restore match/miss, marker repair for a reloaded locked surface, obsolete startup reads, cleanup before a new lock, write/cleanup before unlock, cleanup failure/retry and duplicate callbacks |
| Brightness | Four fake-backend process tests for slider/wheel ordering, startup overlap and latest gamma/temperature; schedule boundary, manual override and disable/re-enable tests |
| Task manager | Production grouping/tree functions with synthetic rows: prototype-name collisions, resource aggregation, user/kernel/PID filters and cyclic process trees |
| Timer | Production state/functions with a fake notification receiver: pause/lap between ticks, pause after expiry and duplicate completion |
| Wi-Fi credentials | Three production completion handlers clear the process password environment before publishing idle, for successful and failed replies; connection and hidden-network process-start failures also clear credentials and busy state |
| Wi-Fi speedtest | Real child-process test cancels a TERM-resistant old request, immediately starts a replacement, and verifies that the late old reply cannot overwrite the newer result; failed process starts clear busy state immediately; repeated active requests are rejected |
| Wi-Fi saved settings | Production action guard rejects overlapping edits, preserves the backend error, and permits a retry after completion; refreshes requested during an older list query are retried after it ends; page controls disable during the write; failed saved-profile queries preserve rows and show an error |
| Wi-Fi connection actions | Nearby, saved, password and hidden-network joins share one busy guard; disconnect backend and process-start failures are visible; overlapping join requests are rejected in both directions and controls reflect pending work; failed access-point detail queries clear stale details |
| Wi-Fi scan UX | Duplicate scans are rejected while active; production completion handler sets and clears error/busy state and allows another scan |
| Bluetooth scan backend | Fake `bluetoothctl` confirms discovery-start replies succeed, backend rejections remain visible as errors, and scan uses the intended 8-second timeout |
| Device service first pass | Battery sysfs profile writes succeed and threshold write failures return JSON errors; production battery actions reject startup overlap without changing saved limit/profile, restore the prior profile after saver mode, expose backend rejection and permit retry, and clear busy state on process-start failure; battery status errors and query-start failures leave loading state; audio live state with missing/muted devices, failed port changes and successful re-selection after failure; display query/action process-start recovery, malformed status/action replies and retained action failures; Wi-Fi status and network-list queries recover from process-start/malformed replies while preserving the last valid data, plus scan, radio, DNS, saved-network, Ethernet and hotspot action process-start recovery; radio backend rejection restores the previous state and is visible; Bluetooth scan reply errors, malformed status-list recovery, removed devices disappear on the next valid snapshot, adapter action FIFO/failure handling, serialized adapter/device commands and all four action-process start failures. Five regressions reproduced against the previous code |
| Device UX first pass | Production Bluetooth and Wi-Fi rows: Space, Return and mouse activation, accessible names, visible focus and action guards. Settings expose Bluetooth action errors; power/audio switches reflect pending/unavailable state; Wi-Fi popup distinguishes scan, empty and error states. Ethernet and hotspot controls reflect pending writes |
| Wi-Fi connection feedback | Failed connections from open/saved networks now show the service error in both the Wi-Fi popup overview and Network settings; password-entry view continues to show it too |
| Wi-Fi network row | Production row activates by Space, Return and mouse; exposes the SSID/security to accessibility, highlights keyboard focus and blocks the current, in-flight or unavailable network |
| Battery empty state | Popup distinguishes initial loading from no battery, suppresses fabricated zero charge/health readings and keeps the power profile control available; capacity label tested against absent/present hardware |
| Battery detail availability | Health, energy and cycle count show an unknown marker when the backend lacks their source data; real zero cycles remain distinguishable from unavailable data |
| Lock authentication | Production state model with fake PAM: start/empty/busy/locked guards, password consumption and clearing, start failure, success/failure/error, abort and callbacks after completion |

Process fixtures use temporary runtime/state directories and fake backends.
RootService's fake `pkexec` never executes the supplied command. Capture tests
start no desktop recording or keyboard-grabbing overlay. The production
`BarPopup` destruction handler runs in a lightweight fixture because
Quickshell's offscreen platform cannot instantiate a real `PanelWindow`.
The UI harness uses memory-only settings and production named-look accessors.

Manual checks completed: Shell Manager Bar and Appearance at the existing
window size; navigation to Themes, Fonts, Cursor, Files settings, Network,
Sound, Notifications, Hub, Live and About without new QML errors. This checks
page loading, not every action. New production types were linked and the
supervised shell restarted; subsequent edits loaded without QML errors.

Still manual: compositor focus and monitor hotplug, rendering during a style
switch, real GPU capture and screen-copy rendering, save overlays, real
polkit, PAM and Wayland lock-screen lifecycles, and real devices. Passing
the automated checks does not cover these scenarios.

Current remaining audit map (baseline tests are not a per-function review):

| Area | Status / remaining work |
|---|---|
| Shared controls and Launcher | Reviewed paths covered; complete action and focus review remains |
| Files | Selection, mutation queue, history and folder-list startup recovery covered; real portal routing and USB attach/eject remain manual |
| Capture | Recorder, saving and clipboard lifecycles reviewed; real GPU capture and overlays |
| Bar and Island | Content hosting and popup arbitration reviewed; compositor focus, layout changes and multiple monitors |
| Lock and authentication | Root completion, password attempts, marker ordering and marker-write failure reporting covered; real PAM, polkit and Wayland crash/reload scenarios remain manual |
| Device services | First pass of all six services completed; Bluetooth adapter/device commands and Wi-Fi saved edits/connection requests are serialized. Bluetooth power, scan, adapter and device actions recover from process-start failure; malformed Bluetooth device lists preserve the last valid state and valid snapshots remove absent devices; audio port changes report process and command failures; battery status and action process starts recover, status backend errors are visible, sysfs writes return success/failure replies, and saver restores the prior profile; display query/action starts and malformed replies recover. Bluetooth discovery timing and real adapter/device removal behavior, battery permission/hardware behavior, listener launch failures in other services, remaining backend/schema failures and hardware edge cases remain |
| Other apps and background services | Task grouping, tree traversal, Packages queries, Backup status, and Clipboard process starts reviewed; other app actions and failure states remain |
| Final verification | Both bar styles, theme/settings combinations and measured performance |

### Resume here

Continue on `redesign/strict-style`; inspect status and recent commits before
editing. Automated code review now covers the shared UI harness and focused
recovery paths across Files, Packages, Backup, Capture, Clipboard and Lock.
Remaining work is bounded to the manual environment checks below and a focused
pass over other app actions; do not reopen the completed Wi-Fi recovery pass.

Manual checks that need the owner's actual devices/session: real portal chooser
routing and USB attach/eject; GPU capture and overlays; PAM, polkit and Wayland
lock crash/reload; compositor focus, style transitions and monitor hotplug;
Bluetooth discovery/device removal and battery hardware/permissions. The
current environment has no reachable Hyprland control socket and no removable
USB block device, so those checks could not be run here. The remaining code
review is app actions/failure states and a final performance/theme matrix.

Do not open keyboard-grabbing overlays while the owner is typing or run real
root/device/network mutations merely to exercise a test. New production files
must be linked before consumers reference them. Use the existing fake-backend
fixtures and `tests/qml_runtime.py`; QML case totals include harness lifecycle
cases. Run `./install.py check`, `ruff check`, inspect the staged diff for
secrets, update these coverage notes, and report those results before committing.

- The agent cannot see the screen unless it takes a screenshot; visual checks
  are the owner's unless asked (token cost).
- Overlays that grab the keyboard are not tested while the owner types.
- `sudo` steps (`system install`) are run by the owner.
