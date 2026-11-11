# Themes

- One theme for the whole desktop; colours by role
  ([themes/gruvbox/README.md](../../themes/gruvbox/README.md)). A hex outside a theme
  is a bug (imported themes of btop may keep their own shades).
- A package holds the config; a theme only what depends on its colours. The
  colour files themselves (hypr `colors.lua`, kitty `colors.conf`, Zellij `themes/vdx.kdl`, …) live in
  the themes alone, so a theme is always active. Two exceptions are gruvbox's
  own: `packages/tmux/colors.conf` and `packages/btop/themes/current.theme`
  are its colours and the source the other themes are recoloured from
  (`FROM_PACKAGES` in `themes/mktheme.py`).
- Switch: `./install.py theme set <name>` or the Shell Manager.
- Light and dark: every theme has a light twin `<name>-light` (`LIGHT` in
  `themes/mktheme.py`; gruvbox's too). A light twin keeps the roles' jobs
  (background0 the window, 1–3 a step deeper, accents darkened to read on light)
  and gives GTK Adwaita's light variant. Appearance › Mode and the bar's Mode
  module switch to the twin (`ThemeService.setLight`); lists show one mode.
