# Recipes

Every recipe ends with `./install.py check` all green.

## Change a config

Edit the file in `packages/<pkg>/` (it is what `~/.config` points to).
Colours never go there: see [themes.md](themes.md). Hardware-bound values never go there:
see "A setting that differs per machine".

## Add a config file

1. Put it in `packages/<pkg>/…` (or `home/` for `~`).
2. `./install.py link` — a new file is invisible until linked.
3. A new package needs a component (below), or its path in an existing
   component's `links`; `check components` names any file nobody owns.
4. A non-default target: `packages/<pkg>/package.toml` —
   `dir = "~/.config"`, `skip = ["notes.txt"]`, `[files] "a.toml" = "~/x.toml"`.

## Add a program a config uses

Its real package name (`mihomo-bin`, not `mihomo`) goes in `pacman` or `aur`
of the component that needs it; a name may repeat across components.
`check components` asks pacman whether it exists and is in the right list.

## Add a component

```toml
[name]
group = "apps"                 # core desktop terminal editor apps music network ai personal hardware
about = "One line for the wizard"
default = false                # personal or heavy things stay off for a new machine
requires = ["quickshell"]      # on with it, can't be switched off
suggests = ["mako"]            # ticked along, can be unticked
pacman = ["pkg"]
aur = ["pkg-bin"]
links = ["pkg"]                # paths under packages/, or "home/<file>"
submodules = ["packages/scripts/x"]
modules = ["x"]                # bar modules it brings, or music sections (BarLayout.sections)
system = ["etc/…"]             # files under system/
services = ["x.service"]       # system units to enable; user_services for --user
user_units = ["packages/…/x.service"]   # unit files copied into ~/.config/systemd/user
masks = ["rival.service"]      # system units that fight this one
secrets = ["x/token"]          # keys of private/manifest.json
hint = "a manual step, printed, never done"
```

Hardware is `group = "hardware"` with `auto = [...]` instead of `default`.
Unknown fields, missing paths, loops in `requires` and bar modules (or sections) that no
component brings all fail `check components`.

## Add a file in /etc

1. `system/etc/…` mirrors `/`; list it in a component's `system`.
2. `@KEY@` is a text value of the machine profile (`@BATTERY@` → `BAT0`);
   `check` rejects unknown keys. A placeholder is replaced everywhere in the
   file, comments included.
3. Hardware registers (codec pins, …) are a quirk: an entry in `QUIRKS` of
   `installer/detect.py` with every condition (board, codec at its address)
   and a hardware component with `auto = ["quirk:<name>"]`.
4. Agents don't run sudo: give the owner `./install.py system install`.
5. What runs after a copy: `SYSTEM_APPLY` (tmpfiles, tlp, udev) and pacman hooks
   in `installer/system.py`; modprobe applies after a reboot.
6. Boot changes (kernel cmdline, mkinitcpio) are never automated: a `hint`.

## A setting that differs per machine

Never in the repo's config. Hyprland: a key in `[hypr]`, rendered by
`installer/hypr.py` into `machine/<name>.lua` and loaded with
`require("components.machine").load("<name>")` after the repo's default; a
test in `tests/test_hypr.py`. `check hypr` runs `Hyprland --verify-config`
on copies of the config with and without `machine/`: a configured and a new
machine must both parse.

## Add a bar module or a shell app

Follow `packages/quickshell/shell/AGENTS.md`, then put the module id in
`modules` of the component it depends on (`quickshell` for core ones).
`link` writes `~/.local/state/dotfiles/components.json` (`installer/shell.py`):
the modules whose components are all off. `BarLayout` keeps them off every
bar (their saved place stays); the Shell Manager lists them as not installed.

## Add a secret

1. A template `templates/secrets/<name>.example` when someone else can fill it.
2. A `.gitignore` line for its path, if it lives in the repo.
3. The file in `private/` and an entry in `private/manifest.json`
   (`"dir/file": "~/target"`); `private/secrets.py collect` copies it in.
4. Its key in `secrets` of the component using it.
5. A row in the README's Secrets table.

Keys live in `~/.config/secrets/env` (from `templates/secrets/env.example`).
Never committed: tokens, keys, passwords, `hosts.yml`, the rendered
`mihomo/config.yaml`, `providers/`, personal data. `setup` clones `private/`
over SSH or `gh` and restores only files that are missing (a restore
overwrites, and a local edit not yet collected would be lost).

## Add a theme

Its colours in `themes/mktheme.py`, then `python3 themes/mktheme.py <name>`.
Generated themes are never edited by hand; `check themes` finds stale ones.
