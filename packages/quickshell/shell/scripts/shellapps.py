#!/usr/bin/env python3
"""How the shell's own windows open, for the Shell Manager › Shell apps.
One JSON object per command.

    shellapps.py list            {"ok", "presets", "apps": [{id, title, icon, width, height, settings}]}
    shellapps.py set <id> <json> saves one app's settings, rewrites the rules, reloads Hyprland
    shellapps.py ensure          writes the rules when they are missing or an app has none yet, and reloads

Settings: {mode: floating | tiled, size: default | preset | custom, preset:
small | medium | large, width, height, position, x, y}; position is one of
the nine spots of the screen (top-left … bottom-right, center), cursor or custom.
Kept in ~/.local/state/dotfiles/shell-apps.json; the Hyprland rules they make
go to shell-apps.lua next to it, which hypr/components/rules.lua loads. Errors:
{"ok": false, "error": "..."}."""
import json, sys
from pathlib import Path
from backend import fail, out, run

STATE = Path.home() / ".local/state/dotfiles/shell-apps.json"
RULES = STATE.with_suffix(".lua")

# the shell's apps with a window of their own (apps/apps.json): the rule
# name, the window title, its own size, its icon and IPC target
REGISTRY = Path(__file__).resolve().parent.parent / "apps/apps.json"
APPS = [{**a["window"], "icon": a["icon"], "ipc": a["ipc"]}
        for a in json.loads(REGISTRY.read_text()) if "window" in a]
# share of the monitor
PRESETS = {"small": [0.5, 0.55], "medium": [0.65, 0.7], "large": [0.8, 0.85]}
DEFAULT = {"mode": "floating", "size": "default", "preset": "medium", "width": 0, "height": 0,
           "position": "center", "x": 0, "y": 0}
MIN_W, MIN_H = 480, 360
# the nine spots: where along x and y (0 start, 0.5 middle, 1 end)
SPOTS = {"top-left": (0, 0), "top": (0.5, 0), "top-right": (1, 0),
         "left": (0, 0.5), "center": (0.5, 0.5), "right": (1, 0.5),
         "bottom-left": (0, 1), "bottom": (0.5, 1), "bottom-right": (1, 1)}
GAP = 12            # from the screen's edges
TOP = 34 + GAP      # under the bar (Theme.barHeight)


def load():
    try:
        saved = json.loads(STATE.read_text())
    except (OSError, ValueError):
        saved = {}
    if not isinstance(saved, dict):
        saved = {}
    settings = {}
    for app in APPS:
        defaults = {**DEFAULT, "width": app["width"], "height": app["height"]}
        stored = saved.get(app["id"])
        merged = {**defaults, **{k: v for k, v in stored.items() if k in DEFAULT}} if isinstance(stored, dict) else defaults
        settings[app["id"]] = defaults if valid(merged) else merged
    return settings


def rule(app, s):
    """The Lua table of one window rule. The move expressions hold the final
    size (window_w there is still the window's own one) and keep the window on
    the monitor; Hyprland splits x and y at the space, so no spaces inside."""
    if s["mode"] == "tiled":
        return "{ float = false }"
    if s["size"] == "preset":
        fw, fh = PRESETS[s["preset"]]
        w, h = f"monitor_w*{fw}", f"monitor_h*{fh}"
    elif s["size"] == "custom":
        w, h = str(s["width"]), str(s["height"])
    else:
        w, h = str(app["width"]), str(app["height"])
    clamp = lambda want, room, size: f"max(0,min({room}-({size}),{want}))"
    if s["position"] in SPOTS and s["position"] != "center":
        fx, fy = SPOTS[s["position"]]
        along = lambda f, room, size, start: (str(start) if f == 0 else f"{room}-({size})-{GAP}" if f == 1
                                              else f"({room}-({size}))*0.5")
        place = f'move = "{along(fx, "monitor_w", w, GAP)} {along(fy, "monitor_h", h, TOP)}"'
    elif s["position"] == "cursor":
        place = f'move = "{clamp(f"cursor_x-({w})*0.5", "monitor_w", w)} {clamp(f"cursor_y-({h})*0.5", "monitor_h", h)}"'
    elif s["position"] == "custom":
        place = f'move = "{clamp(s["x"], "monitor_w", w)} {clamp(s["y"], "monitor_h", h)}"'
    else:
        place = "center = true"
    return f'{{ float = true, size = "{w} {h}", {place} }}'


def write(all_settings):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(all_settings, indent=2) + "\n")
    lines = ["-- written by the Shell Manager (scripts/shellapps.py) — Shell apps", "return {"]
    for app in APPS:
        body = rule(app, all_settings[app["id"]])[1:].strip()
        lines.append(f'  {{ name = "{app["id"]}", match = {{ title = "^({app["title"]})$" }}, {body},')
    lines.append("}")
    RULES.write_text("\n".join(lines) + "\n")


def valid(s):
    for key in ("mode", "size", "preset", "position"):
        if not isinstance(s[key], str):
            return f"bad {key}"
    checks = [
        (s["mode"] in ("floating", "tiled"), "mode"),
        (s["size"] in ("default", "preset", "custom"), "size"),
        (s["preset"] in PRESETS, "preset"),
        (s["position"] in SPOTS or s["position"] in ("cursor", "custom"), "position"),
        (type(s["width"]) is int and type(s["height"]) is int, "size must be whole pixels"),
        (type(s["x"]) is int and type(s["y"]) is int, "position must be whole pixels"),
    ]
    bad = [what for ok, what in checks if not ok]
    if bad:
        return f"bad {bad[0]}"
    if s["size"] == "custom" and (s["width"] < MIN_W or s["height"] < MIN_H):
        return f"at least {MIN_W} × {MIN_H}"
    if s["position"] == "custom" and (s["x"] < 0 or s["y"] < 0):
        return "the position can't be negative"
    return ""


def reload_rules():
    result = run(["hyprctl", "reload"])
    if result is None:
        fail("hyprctl reload is unavailable or timed out")
    if result.returncode:
        fail("hyprctl reload: " + (result.stderr.strip() or "failed"))


def cmd_set(app_id, raw):
    all_settings = load()
    if app_id not in all_settings:
        out({"ok": False, "error": f"unknown app: {app_id}"})
    try:
        change = json.loads(raw)
    except ValueError:
        out({"ok": False, "error": "bad settings"})
    if not isinstance(change, dict):
        fail("bad settings")
    s = {**all_settings[app_id], **{k: v for k, v in change.items() if k in DEFAULT}}
    error = valid(s)
    if error:
        out({"ok": False, "error": error})
    all_settings[app_id] = s
    write(all_settings)
    reload_rules()
    out({"ok": True})


def main(args):
    try:
        if args == ["list"]:
            settings = load()
            out({"ok": True, "presets": PRESETS, "minWidth": MIN_W, "minHeight": MIN_H, "spots": SPOTS,
                 "gap": GAP, "top": TOP,
                 "apps": [{**a, "settings": settings[a["id"]]} for a in APPS]})
        elif args == ["ensure"]:
            # an app added to the registry since the last write has no rule yet
            existing = RULES.read_text() if RULES.exists() else ""
            if any(f'name = "{a["id"]}"' not in existing for a in APPS):
                write(load())
                reload_rules()
            out({"ok": True})
        elif len(args) == 3 and args[0] == "set":
            cmd_set(args[1], args[2])
        out({"ok": False, "error": "usage: shellapps.py list | ensure | set <id> <json>"})
    except OSError as e:
        fail(str(e))


if __name__ == "__main__":
    main(sys.argv[1:])
