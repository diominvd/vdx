# Components

`components.toml` lists everything that can go on a machine: dotfiles
packages (`kitty`, `quickshell`), features (`vpn`, `yandex-music`) and
hardware (`gpu-nvidia`, `laptop`). Its header documents every field.

- `link`, `deps`, `system` and `setup` act on the **selected** components:
  `[components] selected` in `.machine.toml`, set by the wizard or
  `./install.py components add|remove|set <name>…`.
- With nothing chosen: a machine already set up keeps everything (but
  hardware that wasn't detected); a fresh one gets the catalog's defaults,
  which `setup` previews and saves only after confirmation.
- Every non-core component can be deselected unless a selected component
  requires it. `./install.py components set <name>…` starts from only those
  choices and their requirements; packages for deselected components stay
  installed but are not removed.
- A file belongs to the component whose `links` path matches it longest:
  `zsh` owns `zsh/`, `vpn` owns `zsh/functions/vpn`. Theme overlays follow
  their package. A file nobody owns is linked everywhere and fails `check`.
- `requires` can't be switched off; `suggests` is ticked along, can be
  unticked; `default = false` keeps personal things off for a new machine;
  hardware turns on by `auto` terms (`gpu:nvidia`, `hybrid`, `laptop`,
  `asus`, `quirk:<name>`; `!term` negates).
- Packages count as installed when anything provides them (`pacman -T`:
  `yay-bin` is `yay`).
- A part split off a component (`split_from`, e.g. `shell-backups` off
  `quickshell`) is on wherever its parent is, unless `[components] off`
  names it; leaving it out (wizard, `components remove|set`) writes `off`.
  A selection saved before the split keeps what it had.

The installer offers tmux, Zellij or a plain shell on its multiplexer page.
`link` records the selection in `components.json`; kitty honours it even
when both programs remain installed. Shell Manager › Session › Terminal
can override that choice for new windows; Reset restores the installer
selection. The override is in `$XDG_STATE_HOME/dotfiles/terminal.json`.

Zellij opens numbered session `1`; new sessions receive the next number.
Its native tab bar sits above the terminal, with a two-line classic status
bar below (modes and contextual hints) and standard pane frames. A one-line showy-quota strip displays AI quota through CodexBar (120-second
refresh, one shared local serve). Autolock 0.3.0 starts headless and locks
interactive editors, pagers, pickers and agent CLIs; Ctrl+A stays available
while locked. Forgot 0.4.2 opens on demand with Alt+F and reads the actual
keybindings. showy-quota is pinned to 0.9.0; CodexBar CLI to 0.84.0.
WASM assets live in `~/.config/zellij/plugins/`, CodexBar in `~/.local/bin/`;
they are workstation installs, not tracked binaries. Accept plugin permission
prompts on first use. New tabs use the quota layout; Ctrl+A then r reapplies
it to the active tab. CodexBar uses existing provider authentication. Native mode entries retain familiar tmux action keys:

- `Alt+Z`: toggle Zen mode (focused pane fills the terminal, without UI bars);
  available in every mode, including Locked. Press again to restore the layout.
  Shell Manager › Terminal › Zen mode saves the default and applies it to the
  focused pane of each open session. New/resumed sessions use it on attachment;
  Alt+Z temporarily overrides it. Startup reconciliation stops after readiness
  or an eight-second deadline (individual CLI calls have two-second timeouts).
  No process remains afterwards. The preference is in
  `$XDG_STATE_HOME/dotfiles/zellij.json`.
- `Ctrl+P`: `|` right split, `-` down split, `P` close pane, `z` zoom,
  `hjkl` focus.
- `Ctrl+T`: `w` new tab, `W` close tab.
- `Ctrl+N`: `HJKL` resize repeatedly. Both cases grow in that direction;
  native `-` shrinks.
- `Ctrl+O`: `s` new numeric session, `t` session manager, `d` detach.
- `Ctrl+S`: scroll; `Esc` returns to Normal from a mode.

The old `Ctrl+A` prefix remains: `|`, `-`, `hjkl`, `HJKL`, `w`, `W`,
`P`, `z`, `s`, `t`, `d`, and `[` (scroll). `Alt+1…9` selects tabs;
`Alt+h/l` reorders them. Native aliases remain available. Closing through
the tmux overrides is immediate: confirmation prompts, `S` session
termination, repeat resize timing and resurrect/continuum are not ported.

Tmux also uses Alt+Z for a temporary Zen toggle: the current pane is zoomed,
with status and pane titles hidden. Shell Manager › Terminal › Zen mode is
shown for tmux and Zellij and fades with the control animation preference.
The tmux default is stored in `~/.config/tmux/zen.conf`, sourced by tmux.conf.
Changing it updates open sessions and global defaults; native new-session
and new-window hooks apply zoom without a helper process or polling.
Existing tmux servers need a config reload to acquire the new key and hooks.
