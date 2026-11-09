# shell — rules for agents

Quickshell config, `qs -c shell`. What exists: [README.md](README.md).
Interaction routes, lifetime budgets, and recovery: [architecture](../../../docs/shell/architecture.md).

## Layout

```
shell.qml      bars per monitor and every app
apps/          the shell's apps; apps.json is their registry
bar/           Bar (zones, child bars), ModuleFaces (the modules' Components), BarLayout
               (module registry, layouts, child bars), BarPopup;
               island/ — Bar › Look › Shape island: the bar as one morphing pill, popups inside;
               IslandChild — a child bar's own island (Bar.popupHost picks one)
modules/<id>/  bar modules: <Name>.qml, <Name>Popup.qml, <Name>Service.qml
kit/           UI components, icons/ (Material outline, solid/, round/; phosphor/,
               mingcute/, lucide/, tabler/), reply.js (a backend's JSON reply), markup.js (an app's markup as plain text), colour.js (hex / HSV)
components/    Hypr (helpers), ShellIpc (the shell's own IPC from inside it), ScrimWindow,
               PopupManager, PopupCatcher, Separator, ThemeCurtain
config/        Theme (the look only), Colors (from the active theme), Format (text of
               numbers), Paths, ShellSettings, ModuleSettings, Motion
scripts/       backends: one JSON object per command, commands in the header;
               out / fail / run come from backend.py (the folder is on sys.path);
               not backends: supervise.sh (runs qs, starts it again after a crash),
               listen.sh (sourced by a backend's --listen: it ends with the shell),
               settings_*.py (tools with their own main and tests), files_portal.py
               (a D-Bus service), themes.sh (lines, not JSON)
```

Imports: `import qs.<dir>` from the config root. Singletons: `pragma Singleton`
+ `Singleton {}`.

## A module

1. Script `scripts/<id>.sh|py` — the only code that talks to the system. Errors:
   `{"ok": false, "error": "..."}`. None when Quickshell has the data.
2. Service (singleton) — state and actions, owns every `Process` / `Timer`;
   sections `// ---- name ----`; one `run()`, `parse()` through kit/reply.js; `popupShown()` /
   `popupHidden()` for work done only while open; `busy`, `status`, `error`.
   Its numbers (polls, limits, thresholds) and `script: Paths.scriptsDir + "/<id>.sh"`
   are readonly properties under `// ---- tuning ----`, not in Theme.
3. Bar face — `KitBarItem`, a `MouseArea` (click toggles, wheel = quick action),
   `BarPopup` with `ipcTarget`, `function openPopup()` (for the Folder).
   Its text is `BarLayout.faceText(id, content, name?)` (the module's name under
   `Bar text › Name` or `Icon`, from `BarTextRow` at the top of its BAR settings); a module
   with no content takes `BarLayout.faceText(id, BarLayout.label(id))` and `hasContent: false`.
   Options that only shape the content show under Content.
   Open a module from elsewhere (a live activity, a tile) with `BarLayout.openModule(id)`,
   never by its IPC target; a module whose popup target differs from its id goes in
   `BarLayout.popupTargets`.
4. Popup — root `KitFrame`; reads the service, calls its functions. Another app or
   window opens by `ShellIpc.call(<target>, <fn>)`, never a `qs` spawned by hand.
5. Register: `BarLayout.modules` (id, label, zone, icon, about, settings) and a
   `Component` in `bar/ModuleFaces.qml` (every screen's bar makes its own set). A
   renamed id goes to `BarLayout.renamed`.
6. Its id in `modules` of a component in `components.toml` (`quickshell` for
   core ones): a module whose components are all off is "not installed". The user can also
   switch a module off (`BarLayout.enabled`, Bar modules): every place that lists modules
   asks `BarLayout.usable(id)` (installed and enabled), not `installed(id)`.

JSON replies use `kit/reply.js`: `Reply.parse(text, script, fallback)` accepts
objects only; `Reply.parseList(text, fallback)` accepts arrays only (default
`[]`). Legacy shell list commands and array-shaped config files use the list
parser explicitly. Never pass their replies through an object-only wrapper.

## An app

Entry in `apps/apps.json`: id, label, icon, about, bind (Hyprland bind
description), ipc + open, `window` {id, title, width, height} for a window of
its own, `settings`, `module` + `moduleSettings` when it has a bar module,
`desktop` (the id of its `.desktop` file, when it ships one: the launcher lists the
app once, not twice).
A bar module of an app is set in Bar modules like any other (its `moduleSettings`).
Settings of a module or an app carry no links to other pages.

## UI

The design system — tokens, controls, wording, colour, motion, Settings
pages — is [docs/shell/design.md](../../../docs/shell/design.md).
Read it before any visual work.
How to write a page, a module's options, a service, and the review checklist:
[docs/shell/writing-code.md](../../../docs/shell/writing-code.md).

## Settings

- Shell options: `ShellSettings` (`settings.json`) — property + alias + control.
- Module / app options: `<Name>Settings.qml` of `KitToggleRow` / `KitOptionRow`;
  values `ModuleSettings.get("<id>", "<key>", default)` (`modules.json`). The
  default lives in the module.
- Applied at once, except pickers with a preview (Apply) and fields (Enter).
- Schema: `settings.json`, `modules.json`, `layout.json` carry `version`. A change
  to a stored shape (a key renamed, moved, a value's meaning) adds a step to
  `scripts/settings_migrate.py` (`MIGRATIONS`, `VERSION`) with a test in
  `tests/test_settings_migrate.py`; the QML still reads the old shape (a live reload runs no migration).
- Search (the sidebar's): `config/settings-index.json`, built from the pages'
  literal `label:` / `hint:` by `scripts/settings_index.py`; after a row changes run
  it (`check` fails on a stale index). A new page or settings file goes in its `PAGES` / registry walk.
  `where` names the page as the sidebar does: a section of a shared form goes in `SECTIONS`, a
  group that is a sidebar page of its own (`pageTab`) in `GROUP_PAGES`, a page with no file in `SIDEBAR`.
  It also writes `config/settings-keys.json` (each app / app-module settings file's keys):
  an app and its bar module share a ModuleSettings id and reset apart by it.
- A right click on a bar module opens its options page (Bar › Behaviour › Right
  click opens options, `bar/Bar.qml` `openSettings`); the destination unfolds and
  scrolls into view (a page with `jump` and `rowOf`).

## Work

- Every feature MUST account for CPU, memory and startup cost. Load hidden UI on
  demand; run timers, processes and listeners only while their work is needed.
  Measure expensive paths before and after changes.
- New file: `./install.py link`, then restart. Edits reload live, except
  `IpcHandler` functions.
- Restart: `kill <pid>` (`qs list --all`; a TERM also ends its supervisor), then
  `hyprctl eval 'hl.exec_cmd("~/.config/quickshell/shell/scripts/supervise.sh")'`;
  exactly one instance (the supervisor runs `qs -n`). A bare `qs -c shell` has no
  restart after a crash. A config that does not load is not a crash: the supervisor
  toasts the error once and starts qs again when a `.qml` / `.js` file changes.
- Check: `~/.dotfiles/install.py check shell syntax`; `qs log -c shell | grep -E 'ERROR|WARN'`; popups
  `qs -c shell ipc call <id> toggle`; screenshots `grim -g "X,Y WxH"`.
- Don't test overlays that grab the keyboard while the user is typing.

## QML pitfalls

- Old JS engine: no `Array.flatMap`.
- `console.log` is hidden — use `console.warn`.
- `sed -i` replaces the file and breaks live reload — write in place.
- Reserved names: `eval` (method), `state`, `signal`, `status`, `padding`.
- `Column` / `Row` skip zero-size children; no anchors along their axis.
- A `Grid`'s own `columns` / `spacing` in its bindings give NaN.
- A Flickable with `bottomMargin`: `interactive: contentHeight + bottomMargin > height`,
  or a page just taller than the pane does not scroll.
- No `parent: parent.parent` rebinding — it loops and has frozen the session.
- `Behavior` on a readonly property is not allowed.
- A component whose root is `Behavior` does not load (`KitFade is not a type`) and takes the
  whole config down: a repeated `Behavior` stays written out.
- A page a `Loader` makes is already visible: `onVisibleChanged` never sees its first show.
  A page that loads data when shown adds `Component.onCompleted: visibleChanged()`.
- A config error drops the whole bar — restart and read the log at once.
