# vdx shell

The Quickshell config of vdx (`qs -c shell`): the bar or island, the shell's
apps and the Shell Manager, in one process. Code rules: [CLAUDE.md](CLAUDE.md).

Every app and popup answers IPC: `qs -c shell ipc call <target> <function>`.

## Apps

Registry: `apps/apps.json` (read by the Shell Manager, the launcher,
`scripts/shellapps.py` and the window rules).

| App | Key | IPC |
|---|---|---|
| Shell Manager | Super+S | `shell toggle`, `shell open <page>[:<group or app>]`, `shell search <words>` |
| Launcher (system menu) | Alt+Space | `launcher toggle` |
| Keybinds | Super+B | `keybinds toggle\|open\|close` |
| Files | Super+E | `files toggle\|open\|close`, `files go\|reveal\|inspect\|duplicates <path>`, `files choose <json>` |
| Capture | Super+Shift+S | `capture open\|stop\|close\|library\|shot <region\|window\|screen>` |
| Theme picker | Super+T | `themepicker toggle` |
| Task Manager | Ctrl+Shift+Esc | `taskmanager toggle` |
| Cleaner | Super+X | `cleaner toggle` |
| Lock screen | Super+Z | `lock lock` |
| Window switcher | Alt+Tab (floating mode) | `switcher toggle\|open\|close` |
| Music | — | `music toggle\|open\|close`, `music go <yandex\|files\|radio>` |
| Backups | — | `backup toggle\|open\|close` |
| Clipboard | — | `clipboard toggle` |
| Packages | — | `packages toggle` |
| VirusTotal | — | `virustotal toggle` |
| Display | — | `display toggle` |
| Taskbar | — | floating mode only |
| Root prompt | — | the polkit agent: asks before every root action |

Window mode: `windowmode set tiling|floating|scrolling`.

Overview is a function of the shell, not an app (no registry entry): Super+Tab in
every window mode, `overview toggle|open|close`; its options are in Shell Manager › Windows ›
Overview. Workspaces are rows on the dimmed wallpaper, including empty workspaces
between occupied ones. The wheel held down pans, the wheel turned scrolls (Shift:
sideways, Ctrl: zoom). Drag a window with the left button to another workspace;
near an edge the canvas scrolls by itself. In scrolling mode, a slot to the right
of each occupied workspace creates a new column and preserves the windows' widths.
Dropping inside a workspace with one tiled window shares its space between both
windows. The carried picture keeps its size until the drop is confirmed.
Floating has a task view instead (the workspaces as a strip, the chosen one's windows
in a grid).

Overview implementation: `apps/overview/Overview.qml` owns the session, stable
window cards, capture lifecycle and drag phases; `overview.js` calculates drop
geometry and builds the compositor transaction. Hovering never changes compositor
geometry. During a commit the overview releases its exclusive keyboard focus before
dispatching: scrolling layout commands act on the focused column, and Hyprland
rejects window focus while an exclusive layer holds the keyboard. Geometry polling
and auto-pan run only during their respective drag phases; cards unload on close.

### Files

- Sidebar sections: PLACES (drag to reorder, right click to hide), PINNED
  (your folders: a folder's right click › Pin to sidebar), USB (removable
  drives with a mount / eject button), DEVICES (other drives mounted for you),
  Recent and Starred (Ctrl+S). "This computer" shows the storage; an
  unmounted drive mounts on a click.
- The list: folders as tiles above a table of files (checkboxes, ⋮ menu,
  Type / Size / Modified), the path as crumbs (Ctrl+L types one); typing a
  letter jumps to a name.
- Shift-click and Shift-arrow extend or shrink a range from its original
  row. Filtering clears selections of rows no longer shown.
- File operations run in the order submitted. Cancel stops the current
  operation; queued operations still run. Undo/redo waits until the queue is done
  and changes history only after success.
- Keys: F1 lists them; Ctrl+G list, grid, columns; Ctrl+T terminal here; F2
  on several files renames them by a pattern.
- The file chooser of every app (`xdg-desktop-portal`): Save lists the
  folder's files, Open the files of the app's filter. A setting's Choose…
  opens the same picker.
- Look and columns: Shell Manager › Apps › Files.

### Capture

The screens freeze as they are (popups and the island included); a toolbar at
the bottom picks what (R region, W window or popup, S screen), how (Tab: shot
or recording), the sound, the pointer (C) and a delay. The same key again
cancels or stops a recording. The
bar module is a button for the same and shows a recording; `capture library`
opens the saved captures.

A stop during the recording's start delay cancels it before the recorder
launches. The output folder, notification choice and displayed audio/FPS are
kept from that recording's start. Capture names include milliseconds so
successive captures within one second use different names.

Save as accepts an absolute file path or `~/…`. A failed save leaves the
window and temporary capture available for retry. An existing destination
requires a second press of Replace; editing the path clears that confirmation.
Esc keeps a screenshot on the clipboard only; a recording goes to the default
folder, with the same replacement confirmation if a file already exists.
Repeated Esc never confirms replacement. Save as opens after clipboard
delivery finishes; a clipboard failure shows the temporary file's path, and
Skip retains that cached screenshot for recovery until normal cache cleanup.

### Music

A window tabbed by source, each tab only while its component is installed:
Yandex Music (likes, search, playlists), Files (the folders of
`music.folders`: a track plays its folder from there; ⋮ Play, Play next, Add
to queue) and Radio (a star marks a favourite). The player sits at the foot
of every tab.

Three players, each with its own bar module, popup and live activity: the music
(`music`: MPD playing the likes or the local files), the radio (`tuner`: MPD
playing a station) and the media of other apps (`media`: MPRIS). The music's popup:
Now playing (an empty player when nothing plays), its Queue and the Library (likes, folders). MPD
has one queue: a station and the music replace each other, nothing is kept. Sound › One source at
a time: a player that starts pauses the others. Options: Shell Manager › Bar modules › Music.

### Backups

Encrypted restic snapshots of home, `/etc` and the package list. The bar module
`backup` shows the last backup, Back up and a link to the restore guide; in a terminal:
`backup status|run|snapshots|restore|guide …` (`scripts/backup.py`).

## Bar modules

Each lives in `modules/<id>/`; its popup opens with
`qs -c shell ipc call <id> toggle` (except clipboard `clip`, taskmanager
`tasks`, cleaner `clean`, virustotal `scan`, packages `updates`, music
`player`: `music` is its window).

Workspaces, Music, Themes, Tray, Mode, Wallpapers, Equalizer, Clock,
Brightness, Audio, Wi-Fi, Bluetooth, Mihomo, Radio, Media, Timer, Battery, Language, AI, Shell,
Notifications, Capture, Clipboard, System, Task Manager, Cleaner, Backups,
VirusTotal, Packages, Display, Windows, Chat, Folder.

- Order, zones and visibility: Shell Manager › Bar › Modules. Options:
  Shell Manager › Bar modules (an app's module too; Notifications has its own
  page). A right click on a module opens its options.
- A new layout shows workspaces, the clock, audio, Wi-Fi, Bluetooth, battery,
  notifications, Shell and the Folder; the rest start in the Folder, one drag
  from the bar.
- In the strip, modules of LEFT / RIGHT that don't fit beside the centre fold
  into the Folder, nearest the centre first, and come back when there is room.

## Island

Shell Manager › Bar, mode selector › Island: no strip, one pill at the top
centre is the whole bar (`bar/island/`). Solid and island keep their own icon
size, gap, separators and hub opening.

- At rest: LEFT · clock · RIGHT (by default the workspaces and the
  equalizer).
- **The live slot** (`IslandLive`, between the clock and RIGHT) shows what
  runs, only while it does, in three kinds: Asks (low battery, a connected
  device), Held (recording, update, backup, timer, VPN, Focus, radio, music, media) and Flash (the mic, the
  layout, the cable). The wheel over it pages through them with a
  slide, and it stays on the one paged to (nothing pages back by itself; Bar › Live › New one comes forward lets an activity that starts take the pill first); one shows whole in the pill (activities never fold);
  a click on the music opens the
  Music popup (a middle click plays / pauses). Bar › Live: each activity on or
  off, the row order in its kind is the priority (drag a row), the low battery
  line, how long a flash stays and the wheel. The notification toast is the island's own view and only
  follows its switch there.
- **The hub** opens from the clock on a hover or a click (Hub › Opens on). Under the
  clock and day it holds blocks — Toggles (tiles), Calendar (week or month), Sliders,
  Player (card or compact), Module chips — in the order and with the visibility set in
  Hub › Blocks (`config/HubBlocks.qml`): the date, settings and power, the week (a click opens the month), the **tiles** (their own zone of Bar › Layout, "Hub tiles":
  the modules that can be one — Wi-Fi, Bluetooth, VPN, Focus, Timer, Dark mode — two or four to a row, Bar › Hub ›
  Tiles per row; the icon switches, the rest opens the module's popup), the player card (a click opens the
  Music popup, the Music module is on no bar; the card shows with nothing playing
  too), the **Launcher** and
  **Keys** chips, then the modules of the "Hub chips" zone as chips (Hub › Fill each row stretches the chips of a row to the whole width). A chip opens its module's
  popup inside the island, with a bubble back to the hub (the mouse's back
  button too). Right click on a chip: its options. Middle click: play / pause.
  The wheel belongs to the modules.
- The launcher and the keybinds open inside the island (their own option
  "Open from the island"); Escape goes back to the hub when they came from it.
- Volume and brightness show in the live slot as a flash (a ruler and the
  value; not when changed in the open volume popup); new notifications pass
  over the island as a toast — a click on one focuses its app's window, else
  opens the centre. Toast duration: Notifications › Toasts.
- Bar › Monitor › Island clock, per monitor: off with nothing beside it, the
  island hides there until it has something to show.

IPC: `qs -c shell ipc call island hub|media|power|launcher|keybinds|collapse`.

## Child bars

Shell Manager › Bar › Modules: the empty framed bar on the preview adds a
child bar — a small bar beside the monitor's main one, one empty child bar at
a time. Drag it to one of four spots (either edge, either side of the
centre); its corner cross removes it. In the island style each child is an
island of its own, with its modules' popups inside it.

- A module is in one bar only; the Folder is never off the bar.
- Bar › Look › Module gap and Separators apply to every bar; Bar › Layout ›
  ADD › Separator adds a custom "|".
- The unseen-notifications dot shows while the notifications centre is tucked
  away (in the Folder, or in the hub); Notifications › UNSEEN DOT.

## Look

All in Shell Manager › Appearance.

- **Style**: Strict (quiet outlined controls) or Material 3 (tonal surfaces, spacious
  filled controls). Appearance shows both choices as cards; corners remain a
  separate preference. The shared kit supports keyboard focus and activation.
- **Accent**: off (monochrome), or one named colour from the theme's palette.
  It applies only where switched on: switches, sliders, choices,
  workspaces, dropdowns, bar modules, the window border (Hyprland's focused
  frame, via `~/.local/state/dotfiles/accent.lua`). Older custom colours and
  gradients remain readable from imported settings.
- **Glow**: off by default; a soft halo (`KitGlow`) behind bright elements, each
  in its own colour, with a strength. Targets: switches, sliders, workspaces,
  live activities, status dots; switch each off under Appearance › Glow.
- **Shape › Corners**: sharp, or round with one radius — popups, controls,
  the island, Hyprland's windows and mako follow, and the icons switch to
  Material Symbols Rounded.
- **Shape › Icons**: Material Symbols or Phosphor (outline or solid), or Lucide
  (outline only).
- Password fields use dots; there is no separate appearance option.

## Settings

Every page has Reset in its header. About › Settings exports every option to
one file, imports it (the shell restarts) and resets everything (the old set
kept as `settings-before-reset.json`).

State: `~/.local/state/quickshell/by-shell/<id>/` (`settings.json`,
`modules.json`, `layout.json`, …), `~/.local/state/dotfiles/`
(`window-mode`, `windows.json`, `shell-apps.json`).

Files you may edit by hand:

| File | What |
|---|---|
| `modules/brightness/night_light.json` | night light presets and schedule |
| `modules/wifi/dns_providers.json` | DNS providers: `{label, servers}` |
| `~/.config/scripts/radio/stations.json` | radio stations: `"key": {name, url}` |

## Requirements

| What | Needs |
|---|---|
| Battery limit | `system/etc/tmpfiles.d/quickshell-power.conf` |
| Power profile | `system/etc/udev/rules.d/90-quickshell-power.rules` |
| Headset mic | `system/etc/tmpfiles.d/headset-mic.conf` |
| Root actions without a password for 5 min | `system/etc/polkit-1/rules.d/50-pkexec-keep.rules` |
| Ollama service switch | `system/etc/polkit-1/rules.d/50-ollama.rules` |
| AI limits | Claude Code login (`~/.claude/.credentials.json`) |
| AI: Codex limits | Codex CLI session logs (`~/.codex/sessions`, as of its last answer) |
| File scans | `VIRUSTOTAL_API_KEY` (env or `~/.config/secrets/env`) |
| Music likes | Yandex Music token (`~/.config/scripts/yandex-music/token`) |
| Music | MPRIS players (Spotify, a browser, mpv with `mpv-mpris`); Yandex Music, local folders and radio through MPD (components `yandex-music`, `mpd`, `radio`) |
| Island wave | `cava` (without it the wave is made up) |
| Files: devices | `udisks2`; `findmnt` for "This computer" |
| Files: file chooser and links | `python-gobject`, `xdg-desktop-portal` (backend `scripts/files_portal.py`, config `packages/xdg-portal/`) |

System files: `./install.py system install`.

## When the shell is gone

After a crash Quickshell usually restarts the shell in place and opens its
crash report. When the process ends instead, `scripts/supervise.sh` (Hyprland
starts the shell through it) starts it again in a second; five crashes in a
minute and it stops with a toast. A kill or Restart (About, the launcher) is
not a crash. A config that does not load gets one toast with the error, and
the shell starts again once a `.qml` / `.js` file changes. Locked when it
crashed, the new shell locks again.

No bar and no terminal: switch to a tty (Ctrl+Alt+F2), log in, then

```bash
HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/$UID/hypr | tail -1) \
  hyprctl eval 'hl.exec_cmd("~/.config/quickshell/shell/scripts/supervise.sh")'
```

UI validation: `python tests/check_shell_ui.py` from the repo root runs the
kit's keyboard, disabled-state, contrast and responsive-row checks offscreen.
Its Quickshell clipping substitute does not verify GPU rendering; check the
live shell too.

Bar settings separate Layout, Look and Monitors; Hub and Live activities have
their own pages. Layout selects Solid / Island and arranges modules. Click a module to choose its destination and order, or
drag it between zones. Available modules have their own searchable bank.
The main layouts and appearance values are kept independently for Solid and
Island; child bars retain the existing shared model.

Hub settings include opening/player options, width
and the blocks list, where each quick slider (volume, microphone, brightness, night-light warmth, software dimming) is a block of its own with its own switch (warmth shows with night mode, or always).
Volume and brightness are shown by default unless overridden. Sliders sit
above a divider. Module layout offers compact semantic groups (the default), equal two-column
grid tiles and content-sized chips. The profile
shows the user's initial or chosen image and current system uptime.

Appearance has Interface, Accent and Glow tabs; Interface includes corners.
Wallpaper is a separate page. Fonts
and Cursor use searchable lists and a single preview, with explicit Apply.
The colour picker offers named palette choices with keyboard activation.
Scrollbars hide while idle.
