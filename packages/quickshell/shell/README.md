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
| Capture | Super+Shift+S · Super+P | `capture open\|stop\|close\|library\|shot <region\|window\|screen>` |
| Overview | Super+O | `overview toggle` |
| Task Manager | Ctrl+Shift+Esc | `taskmanager toggle` |
| Cleaner | Super+X | `cleaner toggle` |
| Lock screen | Super+Z | `lock lock` |
| Window switcher | Super+Tab (floating mode) | `switcher toggle\|open\|close` |
| Music | — | `music toggle\|open\|close`, `music go <yandex\|files\|radio>` |
| Backups | — | `backup toggle\|open\|close` |
| Clipboard | — | `clipboard toggle` |
| Packages | — | `packages toggle` |
| VirusTotal | — | `virustotal toggle` |
| Display | — | `display toggle` |
| Taskbar | — | floating mode only |
| Root prompt | — | the polkit agent: asks before every root action |

Window mode: `windowmode set tiling|floating|scrolling`.

### Files

- Sidebar sections: PLACES (drag to reorder, right click to hide), PINNED
  (your folders: a folder's right click › Pin to sidebar), USB (removable
  drives with a mount / eject button), DEVICES (other drives mounted for you),
  Recent and Starred (Ctrl+S). "This computer" shows the storage; an
  unmounted drive mounts on a click.
- The list: folders as tiles above a table of files (checkboxes, ⋮ menu,
  Type / Size / Modified), the path as crumbs (Ctrl+L types one); typing a
  letter jumps to a name.
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
cancels or stops a recording. Super+P shoots the focused screen at once. The
bar module is a button for the same and shows a recording; `capture library`
opens the saved captures.

### Music

A window tabbed by source, each tab only while its component is installed:
Yandex Music (likes, search, playlists), Files (the folders of
`music.folders`: a track plays its folder from there; ⋮ Play, Play next, Add
to queue) and Radio (a star marks a favourite). The player sits at the foot
of every tab.

The bar module `music` shows what plays from any source. Its popup: the music
service on or off, Now playing (a choice of players when several run), the
Queue (MPD) and the Library (likes, folders, favourite stations). Options:
Shell Manager › Bar modules › Music.

### Backups

Encrypted restic snapshots of home, `/etc` and the package list. The bar module
`backup` shows the last backup, Back up and the restore guide; in a terminal:
`backup status|run|snapshots|restore|guide …` (`scripts/backup.py`).

## Bar modules

Each lives in `modules/<id>/`; its popup opens with
`qs -c shell ipc call <id> toggle` (except clipboard `clip`, taskmanager
`tasks`, cleaner `clean`, virustotal `scan`, packages `updates`, music
`player`: `music` is its window).

Workspaces, Music, Themes, Tray, Mode, Wallpapers, Equalizer, Clock,
Brightness, Audio, Wi-Fi, Bluetooth, Mihomo, Battery, Language, AI, Shell,
Notifications, Capture, Clipboard, System, Task Manager, Cleaner, Backups,
VirusTotal, Packages, Display, Windows, Chat, Folder.

- Order, zones and visibility: Shell Manager › Bar › Layout. Options:
  Shell Manager › Bar modules (an app's module too; Notifications has its own
  page). A right click on a module opens its options.
- A new layout shows workspaces, the clock, audio, Wi-Fi, Bluetooth, battery,
  notifications, Shell and the Folder; the rest start in the Folder, one drag
  from the bar.
- In the strip, modules of LEFT / RIGHT that don't fit beside the centre fold
  into the Folder, nearest the centre first, and come back when there is room.

## Island

Shell Manager › Bar › Look › Shape › Island: no strip, one pill at the top
centre is the whole bar (`bar/island/`). Solid and island keep their own icon
size, gap, separators and hub opening.

- At rest: LEFT · clock · RIGHT (by default the workspaces and the
  equalizer).
- **The hub** opens from the clock on a hover or a click (Bar › Behaviour ›
  Open the hub): the date, settings and power, the track, the **Launcher** and
  **Keys** chips, then the HUB modules as chips. A chip opens its module's
  popup inside the island, with a bubble back to the hub (the mouse's back
  button too). Right click on a chip: its options. Middle click: play / pause.
  The wheel belongs to the modules.
- The launcher and the keybinds open inside the island (their own option
  "Open from the island"); Escape goes back to the hub when they came from it.
- Volume and brightness pass over the island as a flash (not when changed
  from the island itself or while the pointer rests on it); new notifications
  too — a click on one focuses its app's window, else opens the centre.
  Toast duration: Notifications › Toasts.
- Bar › Monitor › Island clock, per monitor: off with nothing beside it, the
  island hides there until it has something to show.

IPC: `qs -c shell ipc call island hub|media|power|launcher|keybinds|collapse`.

## Child bars

Shell Manager › Bar › Layout: the empty framed bar on the preview adds a
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

- **Style**: Terminal (framed controls) or Material (filled controls, no
  frames, a hairline round popups).
- **Accent**: off (monochrome), one colour or a gradient, typed as hex or
  picked. It applies only where switched on: switches, sliders, choices,
  workspaces, dropdowns, bar modules, the window border (Hyprland's focused
  frame, via `~/.local/state/dotfiles/accent.lua`). A gradient runs across
  fills; text and outlines take the first colour.
- **Shape › Corners**: sharp, or round with one radius — popups, controls,
  the island, Hyprland's windows and mako follow. Icons use Phosphor's
  Regular / Fill weights independently of corner shape.
- **Typed characters**: dots or squares in every password field.

## Settings

Every page has Reset in its header. About › Settings exports every option to
one file, imports it (the shell restarts) and resets everything (the old set
kept as `settings-before-reset.json`).

State: `~/.local/state/quickshell/by-shell/<id>/` (`settings.json`,
`modules.json`, `layout.json`, …) and `~/.local/state/dotfiles/`
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
