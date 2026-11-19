# Repo layout

Where every piece lives and what the installer does with it.

Arch Linux + Hyprland. `install.py` (Python ≥ 3.11, stdlib only, code in
`installer/`) puts the repo on a machine:

| Piece | Where | What happens to it |
|---|---|---|
| Config of a program | `packages/<pkg>/` | each file symlinked into `~/.config/<pkg>/` |
| A file in `~` | `home/` | symlinked into `~/` |
| Theme-dependent file | `themes/<theme>/<pkg>/` | shadows the package file of the same path |
| File in `/etc` | `system/<path>` | copied (never linked) with sudo, after a diff |
| What can be installed | `components.toml` | one entry, one checkbox: packages, links, `/etc` files, units, bar modules |
| This machine | `.machine.toml` (local) | detected hardware, `[override]`, `[hypr]`, the chosen components |
| Active theme | `.theme` (local) | gruvbox when absent |
| Secrets | `private/` (private repo, gitignored) | copied to `$HOME` by `private/secrets.py` |
| Secret templates | `templates/secrets/*.example` | seeded by `setup` (`bootstrap`) |
| Wallpapers | `wallpapers/<theme>/`, `wallpapers/common/` (optional, not shipped); the user's own in `~/.local/share/dotfiles/wallpapers/` | read by the Shell Manager |
| Installer state | `~/.local/state/dotfiles/` | logs, the setup journal, backups, what the shell reads |
| Installer tests | `tests/` | `./install.py check tests`; run before every install |
| Docs: one topic per file | `docs/` | index: `docs/README.md` |
| Owned AI skills and preferences | `ai/` | explicit `python3 ai/manage.py link`; [workspace guide](../agent/workspace.md) |

Dotfile cleanup preserves symlinks inside the checkout and destinations owned
by `ai/links.json`; AI links are maintained by `ai/manage.py`.
