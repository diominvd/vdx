# gruvbox-material

The source theme: `themes/mktheme.py` derives every other one from it role by
role. Values: `quickshell/shell/config/Colors.qml`.

| Role | Hex | Use |
|---|---|---|
| background0 | `#202020` | surfaces: bar, popups, terminal, editor |
| background1 | `#32302f` | raised: hover, fields |
| background2 | `#3c3836` | tmux cells |
| background3 | `#45403d` | selection, quiet frames, lines |
| foreground0 | `#d4be98` | text |
| foreground1 | `#ddc7a1` | emphasis |
| foreground2 | `#bdae93` | secondary text, focused frames |
| gray | `#7c6f64` | frames at rest |
| muted | `#928374` | hints, inactive labels |
| dim | `#665c54` | disabled |
| red | `#ea6962` | error |
| orange | `#e78a4e` | special mode, pending |
| yellow | `#d8a657` | warning, prompt |
| green | `#a9b665` | ok, on |
| aqua, blue, purple | `#89b482`, `#7daea3`, `#d3869b` | terminal palette |

Rules: surfaces step up `background0 → 1 → 3`; frames 1px in controls, 2px for
windows and popups (`gray` at rest, `foreground2` focused); selection is a fill
plus bold, not a colour; colour carries meaning only.

Files: hypr `components/colors.lua`, kitty `colors.conf`, mako `config`, gtk
`gtk.css`, Zellij `themes/vdx.kdl`, tmux and btop (from the packages).
