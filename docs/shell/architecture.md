# Shell architecture

How the shell is built and where its responsibilities end. Code rules:
[packages/quickshell/shell/CLAUDE.md](../../packages/quickshell/shell/CLAUDE.md);
repo and installer: [docs/](../README.md); what exists for a
user: [shell/README.md](../../packages/quickshell/shell/README.md). Paths below are under
`packages/quickshell/shell/` unless they start with the repo root.

## Runtime

```
Hyprland ── autostart.lua (hyprland.start)
   ├─ awww-daemon            wallpaper surface (`--no-cache`: starts empty; the shell sets the picture)
   ├─ shellapps.py ensure    window rules for the shell's apps (repo hypr config)
   ├─ supervise.sh           runs settings_migrate.py, then qs; starts it again when it ends by a crash (not a kill);
   │                         a config that does not load (exit 255): one toast, a new start when a file changes;
   │                         most crashes Quickshell restarts in place itself (crash report window)
   │   └─ qs -c shell        ONE process: bars, island, popups, apps, lock, polkit agent
   ├─ mako                   the notification server (toasts in Solid style, history)
   ├─ cursors.py restore
   └─ display.py restore     monitor scales/positions saved in Shell Manager › Displays
```

Everything in the shell is one Quickshell process: a QML error in a shared
file can drop the whole bar; a crash also takes the lock screen
(`WlSessionLock`; Hyprland keeps the session locked, `allow_session_lock_restore`)
until the supervisor's new `qs` locks again (marker in
`$XDG_RUNTIME_DIR/shell-lock/locked`, this session's signature).

## Layers inside the shell

| Layer | Where | Owns | Must not |
|---|---|---|---|
| Backend scripts | `scripts/*.sh\|py` (`backend.py`) | every system call; one JSON object per command | hold UI state |
| Services | `modules/<id>/<Name>Service.qml`, `apps/<id>/<Name>Service.qml` (singletons) | state, `Process` / `Timer`, actions | draw |
| Faces & popups | `modules/<id>/<Name>.qml`, `<Name>Popup.qml` | look; call service functions | talk to the system |
| Apps | `apps/<id>/`, registry `apps/apps.json` | own windows or overlays, IPC targets | — |
| Bar | `bar/` (`Bar`, `BarLayout`, `BarPopup`, `ModuleFaces`), `bar/island/` | zones, child bars, island views, popup hosting | module logic |
| Kit | `kit/` (`Kit*.qml`, icons, `reply.js`, `markup.js`) | shared controls and parsing | feature logic |
| Config | `config/` (`Theme`, `Colors`, `Motion`, `Format`, `Paths`, `ShellSettings`, `ModuleSettings`) | tokens and settings stores | — |
| Components | `components/` (`Hypr`, `ShellIpc`, `PopupManager`, `PopupCatcher`, `ScrimWindow`, …) | Hyprland helpers, the shell's own IPC, popup arbitration | — |

Island and child bars borrow popup items through
`components/PopupContentHost.qml`. It restores only the items it moved, keeps
other host children in place, and returns the content and closes the popup
when the host is destroyed or Island hosting is disabled by a style change.

`PopupManager` selects one IPC owner per target, preferring the focused
monitor and skipping bars without a screen. Registry updates replace the map
so owner bindings react directly. `BarPopup` closes before destruction and
unregisters regardless of whether it has an IPC target; removal also clears
its active-popup state and cached underline on the same bar.

`apps/auth/RootService.qml` captures a completed action's tag, cancellation
and error before publishing idle, then resets its state before `finished`.
Listeners may submit or cancel another action immediately; the old completion
must not modify that request's state or report its tag as the old result.

`apps/lock/LockAuthentication.qml` owns the shared password fields and PAM
attempt state. Lock supplies the real PAM context and responds to verification;
the QtQuick-only model checks start failure, consumes the pending password
before responding, clears password strings on completion/error or lock-state
change, and aborts an attempt when leaving its lock state. Callbacks without
an active attempt cannot verify or change the error. Tests use a fake context.

`LockPreparation.qml` owns the optional parallel `grim` processes before a
blurred-background lock. A shared one-second deadline and 200 ms kill grace
bound the process group, including children that ignore TERM. A separate
1.3-second QML fallback covers launch failure. Completion always requests the
session lock; repeated requests while preparing are ignored. An old worker
still stopping causes the next request to lock immediately without waiting.

`LockLifecycle.qml` orders marker writes, cleanup and unlock. Startup reads
carry a generation so a new lock request or verification supersedes an old
result. An already-locked surface after reload repairs its marker instead
of clearing it. New locks wait for any existing cleanup; verification waits for a
pending marker write and successful cleanup before releasing the Wayland lock.
Cleanup failure leaves the screen locked and allows another unlock attempt.
There is no detached cleanup that can remove the next lock's marker.

Brightness queues mark work busy before starting a process. Slider values
supersede older queued wheel steps; wheel input after a queued slider value
adjusts that value. Night-light application coalesces updates until completion.
Disabling its schedule resets boundary tracking so re-enabling evaluates the
current window again, while manual overrides hold within an enabled window.

Task Manager groups processes in a dictionary without a prototype: process
names such as `constructor`, `toString` and `__proto__` remain ordinary keys.
Descendant traversal tracks visited PIDs with a Set to handle cycles and
avoid repeatedly scanning the accumulated result.

Backend reply shapes are explicit: `kit/reply.js` parses objects with `parse`
and arrays with `parseList`. Wi-Fi networks/DNS providers, Mihomo providers
and nodes, MPD queues/radio stations, Claude sessions and notification lists
use the array parser. Error objects and malformed replies cannot become list
models; consumers either clear their list or retain it with a null fallback.

Timer pause and lap actions sample the clock at the action, rather than use
the previous display tick. Pausing an already-expired countdown completes it;
completion is guarded so a second callback cannot notify again.

`FilesState` is one window's file state; `FilesService` is the singleton holding the browser's
(Files, Super+E, and what settings pages read). The file picker is `FilePickerWindow` with a
`FilesState` of its own: it opens with the file manager up or not, and neither takes the other's
folder or selection. Requests (the portal's `ipc call files choose`, a "Choose…") reach it as
`FilesService.pickAsked`. The Files UI reads the state it is given (`svc`), never the singleton.

Files selection lives in `apps/files/FilesSelection.qml`, a QtQuick-only
model tested without the filesystem or portal. FilesState supplies visible
rows and the picker's single-selection constraint and exposes the existing
selection API. `anchor` is the current row used for scrolling; `rangeStart`
keeps the original row while Shift extends or shrinks a range. Filtering or
removing rows prunes their selection so file actions target visible items.

`apps/files/FilesActions.qml` owns file mutations, their progress and replies.
It queues every submitted action in FIFO order; FilesState's latest-request
queue is reserved for replaceable reads. Each mutation clears its reply before
starting, and the completion callback runs before the next action starts.
Undo/redo stays disabled until the mutation queue has drained. Portal replies
use a second FIFO instance so answering one picker never replaces another
picker's cancellation and does not wait for a long file copy.
`FilesHistory.qml` owns the undo/redo stacks and their pending transaction.
An entry moves between stacks only on successful completion; failure or
cancellation keeps it in its original stack. Redo never records a new entry.

Capture recording lives in `apps/capture/CaptureRecorder.qml`: one immutable
request spans the start delay, recorder process and output verification.
The service snapshots the command, output destination, notifications and
displayed recording parameters. The session rejects overlapping starts and
can cancel before launching; a non-empty output determines success even when
the recorder exits with an interrupt code. The service retains overlay and
countdown coordination.

`CaptureSaver.qml` owns pending Save as requests and replacement confirmation;
`CaptureSavePanel.qml` draws its contents without depending on layer-shell or
the capture singleton. `scripts/capture.py` moves or discards the temporary
output. A failed save retains the request and source, and a destination is
replaced only after confirmation for that exact path. Cross-filesystem copies
keep the source until success; a failed replacement copy keeps the old target.
`CaptureClipboard.qml` tracks clipboard delivery before the Save as request
is offered, so moving or discarding a screenshot cannot race wl-copy opening
its source. Clipboard failures are reported with the temporary path; skipping
Save as after such a failure retains that cached source for normal cleanup.

## Themes

`themes/gruvbox/` is the source; `themes/mktheme.py <name>` generates every
other theme (never edited by hand). A theme holds the colour files of each
package (`hypr` colours, `kitty`, `mako/config`, `quickshell` colours …),
linked over the package files by `./install.py link`; `.theme` names the
active one. The shell reads colours through `config/Colors.qml` → `Theme`.
Runtime-written theme-ish state goes to `~/.local/state/dotfiles/`
(`accent.lua`, read by `packages/hypr/components/appearance.lua`). mako modes
(`island`, `round`) are switched by the shell with `makoctl mode`.

## Install flow

`./install.py setup`: preflight → plan → steps (packages, AUR, submodules,
links, secrets, `/etc`, units, services). `link` also writes
`~/.local/state/dotfiles/components.json` (modules not installed) and
`hypr/machine/*.lua`. `doctor` checks the machine. Details: [repo/installer.md](../repo/installer.md).

## Settings and state

| Store | File (`~/.local/state/quickshell/by-shell/<id>/`) | API | Notes |
|---|---|---|---|
| Shell options | `settings.json` | `ShellSettings` property + `set()` | keys and defaults in `config/ShellState.qml`; `version` (schema, below) |
| Module / app options | `modules.json` › `values.<id>` | `ModuleSettings.get(id, key, default)` / `set` | default lives in the module; written on each change, external edits reloaded |
| Bar layout | `layout.json` | `BarLayout` | renames via `BarLayout.renamed` (live fallback); not watched |
| Notifications history | `notifications.json` (statePath) | `NotificationsService` | — |
| Schema | `version` in the three files above | `scripts/settings_migrate.py` (`VERSION`, `MIGRATIONS`), run by `supervise.sh` before qs | a file is written only when changed, old one as `.bak`; `tests/test_settings_migrate.py` |
| Search index | `config/settings-index.json` | `scripts/settings_index.py` (from the pages' QML), the sidebar's search, `shell search <words>` | loaded on demand; normalized once, duplicate destinations collapsed; `check` fails when stale; `tests/test_settings_index.py` |
| Export / import / reset | one bundle of the three files and the Windows page's (`windows.json`, `window-mode`) | `scripts/settings_io.py`, About › Settings | import migrates; import and reset stop the shell, write (old files `.bak`), start it again; `tests/test_settings_io.py` |
| Dotfiles state | `~/.local/state/dotfiles/` | installer + shell | `components.json` (modules not installed), `accent.lua`, `window-mode`, `shell-apps.json` |

Settings UI = **Shell Manager** (`apps/shellmanager/`, Super+S). The sidebar is a rail of group
buttons (LOOK, BAR, DESKTOP, CONNECT, DEVICES, SYSTEM) with the shell's own pages (`foot: true`: Profile, System, Settings, About) at its foot, and a list of the open group's pages beside it. Groups, by what the user is after; in a group the most used page first, pages that share one page (`pageTab`) side by side, the rare ones last: LOOK Interface (style, density, input text, corners), Themes (also Dark / Light), Colours, Glow (Interface, Colours and Glow are one page: `pageTab`), Wallpaper, Fonts (typeface, text size), Icons, Cursor, Motion ·
BAR Bar, Bar look (the Solid / Island style first), Bar modules, in the Island style only Hub and Live activities, Bar monitors (Bar, Bar look and Bar monitors are one page: `pageTab`) ·
DESKTOP Windows, Notifications, Lock screen · CONNECT Network (with Hotspot), Bluetooth, VPN · DEVICES Sound,
Displays (with the night light), Power · SYSTEM Apps, Updates (checking, installing, removal safety: the Packages app keeps only what it opens on and lists) · foot: Profile, System, Settings, About (the last three one page, `pageTab`). Windows, Network (Wi-Fi, Ethernet, Hotspot) and Fonts are each one page with groups. A page has no tab strip: a section that shares a page with others sets `page` + `pageTab` in `allSections`.
A page header has its group, a
state line and one or two lines on what the page does; a block has an `about` line (`KitLabel`).
One home per setting; a setting that waits for something (a style, a switch, a module in the Hub
row) says so with `KitRow.needs` and one fixing button (design.md). An app's or module's options are its
`<Name>Settings.qml`, shown under Apps or Bar modules (Lock screen, Notifications: own pages).
Applied at once (pickers with preview: Apply; fields: Enter). A page with its own options has Reset in
the header (two steps: Reset, Sure?) that resets only that page's keys (`ShellSettings.reset(keys)`,
`looksReset`, `ModuleSettings.reset(module, keys)`; defaults in `config/ShellState.qml`). The old page
names still open the new places (`resolve()` in ShellManager.qml).

## Feature map

| Feature | Code | Depends on | Notes |
|---|---|---|---|
| Notifications | `modules/notifications/`, `scripts/notifications.sh`, `bar/island/IslandNotice.qml`, `IslandService` › notice | mako (server), `dbus-monitor`, `makoctl` | Solid: mako toasts; Island: island toasts, mako `island` mode invisible |
| Wallpaper | `apps/shellmanager/Wallpaper.qml` (in `shell.qml`), `WallpaperService.qml` | `awww`, `wallpapers/` in the repo | modes theme / custom / image (`ShellSettings.wallpaperMode`) |
| Displays | Shell Manager › Displays (`DisplaysPage`), `apps/display/` (service, layout), `scripts/display.py` | `hyprctl` | restore at login |
| Audio | `modules/audio/`, `scripts/audio.sh` | Quickshell Pipewire, `pactl` (ports) | one list entry per port |
| Bluetooth | `modules/bluetooth/`, `apps/shellmanager/BluetoothPage.qml`, `scripts/bluetooth.sh` | BlueZ | — |
| VPN | `modules/mihomo/`, `apps/shellmanager/VpnPage.qml`, `scripts/mihomo.sh` | Mihomo | — |
| Files + picker | `apps/files/`, `scripts/files.py`, `scripts/files_portal.py`, `packages/xdg-portal/` | `xdg-desktop-portal`, `python-gobject`, `udisks2` | the shell's FileChooser portal and `FileManager1` |
| Lock | `apps/lock/` | Quickshell `WlSessionLock`, PAM | options in `modules.json` › `lock` |
| Island / hub | `bar/island/` | `ShellSettings.barStyle` | hub = island view from the clock; the Launcher and Keys chips open the launcher and the keybinds (their panels `apps/launcher/LauncherPanel.qml`, `apps/keybinds/KeybindsPanel.qml`) as island views |
| Music (bar module), Music app | `modules/music/` (bar face, popup, Settings); `modules/player/PlayerService` = three players: `music` (MPD's music), `radioView`, `media` (MPRIS), and `view` for the keys; app `apps/music/` (bar module `music`) | MPRIS players; the island's media and the Music window read `PlayerService` | `AudioPause` reads MPRIS too; the window's tabs read `YandexLibrary` / `YandexService`, `music_files.py`, `RadioService` only while `BarLayout.installed` |
| Music (Yandex) | `modules/yandex/`, `modules/mpd/`, `scripts/music.sh`, `scripts/yandex.py`, `modules/yandex/YandexLibrary.qml` | component `yandex-music` (+ `mpd`, submodule; owns `scripts/yandex.py`); a music section `yandex` (BarLayout.sections), not a bar module | `YandexService` feeds `PlayerService` (the MPD source) and `AudioPause`; the Music app's Yandex section reads `YandexLibrary` |
| Radio | `modules/radio/` | component `radio` (+ `mpd`); a music section `radio` | shares `MpdService` |
| Files (local music) | `scripts/music_files.py`, `music.sh --files-play` | component `mpd`; a music section `files` (`MpdService.needed`) | `MpdService.playFolder`; the folders are `music.folders` |
| Capture | `apps/capture/`, `modules/capture/` | `grim`, `gpu-screen-recorder`, `wl-copy`, `notify-send` | the only "camera" in the repo: screen capture |
| Launcher, Keybinds | `apps/launcher/`, `apps/keybinds/` | Hyprland binds | a window (Alt+Space, Super+B) and the island's Launcher / Keys chips: the same panels |
| Commands palette | `apps/launcher/LauncherService.qml`, `LauncherPanel.qml` | app registry, `BarLayout`, settings index, power actions | Commands is the shared action route; focused Apps, Files and Power tabs remain available |

## Optional parts

`components.toml` decides what is installed; a bar module whose components
are all off is "not installed" (hidden from bars, greyed in Shell Manager,
`installer/shell.py` → `components.json`). QML files of every module are
linked with `quickshell` regardless — a service of an absent integration
still loads, so it must tolerate missing binaries.

## Boundaries (current rules)

- Only scripts touch the system; services never shell out with untrusted text.
- Colours only through `Theme.*`; tokens per [design.md](design.md).
- Repo-linked files (theme configs) are never written at runtime; runtime state
  goes to the state dirs.
- `/etc` only via `system/` and `./install.py system install`.

## Interaction, performance and recovery

`PopupManager` owns the one active bar popup and routes its IPC to the bar on
the focused monitor. `BarPopup` owns outside-click and default Escape closing;
nested module views may handle Escape first. Island owns its local view stack:
Escape returns to the Hub when a view came from there, otherwise to compact.
Repeated attachment of the same popup preserves its existing Hub return route.
While the Hub is open, module popups stay in its island even if the module's
face belongs to a child bar, preserving the back bubble and return route.
The Hub player passes its island explicitly to `BarLayout.openModule`; the
origin is preserved through both existing popups and modules loaded on demand,
so return navigation does not depend on the Hub remaining visible until IPC finishes.
`BarLayout.openModule(id)` is the shared route to a module popup or its options:
a module drawn somewhere answers through its popup's IPC; one drawn nowhere (a hub
tile, a live activity's target) is made on demand by the focused monitor's bar
(`Bar.hosted`), which calls its `openPopup()` and lets it go once no popup is open.
A module with a popup has `openPopup()` (a click on it does the same); without it,
its options open. No component keeps hosts of other modules for their popups.
`KitInput` owns text focus; pages pass navigation keys explicitly so typing,
selection and parent-level Escape do not compete.

The launcher Commands tab searches shell actions, applications, bar modules,
settings and safe entry points. It invokes existing services/routes instead
of implementing module actions again. Settings search data is normalized once
after its lazy load and duplicate label/target pairs are shown once.

Recurring timers and processes belong to services and should run only while
their data is needed. UI pages with expensive content are loaded only while
visible. For performance-sensitive edits, sample the live process from Shell
Manager › About › System › Shell resources in representative idle and active
states; RSS/VSZ are KiB and CPU is the process's lifetime average. Do not add
permanent profiling timers.

Shell Manager › About › System can run `./install.py doctor` on demand. The
session supervisor restarts crashes and waits for config edits after a failed
load; inspect `qs log -c shell` before restarting manually. `./install.py
rollback` restores backed-up managed files without replacing newer files.
Export settings before risky preference changes; import and Reset everything
preserve the previous option files as backups.

## Update rule

A change to a flow or a boundary above updates this file in the same
commit; a new boundary or store is agreed with the owner first.
