#!/usr/bin/env python3
"""Cursor theme for the Shell Manager. One JSON object per command.

    cursors.py list                     {"ok", "base", "size", "mode", "fill", "outline",
                                         "cursors": [{id, name, installed}]}
    cursors.py install <id>             into ~/.local/share/icons                  {"ok", "name"}
    cursors.py preview <base> [<fill> <outline>]
                                        PNGs of the main shapes, tinted when colours are given
                                        {"ok", "shapes": [{name, path, width, height}]}
    cursors.py set <base> <size> <mode> [<fill> <outline>]
                                        mode original | theme | custom; applies now and at login
    cursors.py restore                  re-applies the saved choice (Hyprland start)

A tinted cursor is a copy of <base> with every pixel moved from black–white
to <fill>–<outline> (rrggbb), alpha kept: ~/.local/share/icons/dotfiles-cursor-
<fill>-<outline>, the one before it removed. The choice is the XDG default
cursor (~/.local/share/icons/default/index.theme, which GTK's `default` and
Xcursor follow), Hyprland's `setcursor` and the GNOME interface keys (GTK 4);
kept in ~/.local/state/dotfiles/cursor.json. Errors: {"ok": false, "error": "..."}."""
import configparser, json, shutil, struct, subprocess, sys, tarfile, tempfile, urllib.request, zlib
from array import array
from pathlib import Path
from backend import out

ICONS = Path.home() / ".local/share/icons"
STATE = Path.home() / ".local/state/dotfiles/cursor.json"
PREVIEWS = Path.home() / ".cache/dotfiles/cursor-preview"
SEARCH = [ICONS, Path.home() / ".icons", Path("/usr/share/icons")]
TINTED = "dotfiles-cursor-"
BIBATA = "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/{}.tar.xz"
PHINGER = "https://github.com/phisch/phinger-cursors/releases/latest/download/phinger-cursors-variants.tar.bz2"

# theme name -> where it comes from
CURATED = {
    "Bibata-Modern-Classic": BIBATA.format("Bibata-Modern-Classic"),
    "Bibata-Modern-Ice": BIBATA.format("Bibata-Modern-Ice"),
    "Bibata-Modern-Amber": BIBATA.format("Bibata-Modern-Amber"),
    "Bibata-Original-Classic": BIBATA.format("Bibata-Original-Classic"),
    "phinger-cursors-dark": PHINGER,
    "phinger-cursors-light": PHINGER,
}
DEFAULT = {"base": "Adwaita", "size": 24, "mode": "original", "fill": "", "outline": ""}

# preview shape -> the file names themes use for it, in order of preference
SHAPES = {
    "default": ["left_ptr", "default", "arrow"],
    "pointer": ["pointer", "hand2", "hand1", "pointing_hand"],
    "text": ["text", "xterm", "ibeam"],
    "wait": ["wait", "watch", "left_ptr_watch"],
    "crosshair": ["crosshair", "cross", "tcross"],
    "grab": ["grabbing", "closedhand", "fleur", "move"],
    "not-allowed": ["not-allowed", "crossed_circle", "forbidden", "circle"],
}


def theme_dir(name):
    for base in SEARCH:
        if (base / name / "cursors").is_dir():
            return base / name
    return None


def installed():
    """Themes with a cursors/ dir anywhere on the search path (not our tinted copies)."""
    names = set()
    for base in SEARCH:
        if base.is_dir():
            names |= {d.name for d in base.iterdir() if (d / "cursors").is_dir()
                      and d.name != "default" and not d.name.startswith(TINTED)}
    return names


def saved():
    try:
        return {**DEFAULT, **json.loads(STATE.read_text())}
    except (OSError, ValueError):
        return dict(DEFAULT)


# ---- xcursor ---------------------------------------------------------------------
# File: "Xcur", header size, version, ntoc, then ntoc × (type, subtype, position).
# An image chunk (type 0xfffd0002): header size, type, nominal size, version,
# width, height, xhot, yhot, delay, then width × height premultiplied ARGB.

IMAGE = 0xFFFD0002


def chunks(data):
    """(nominal size, offset of the pixels, width, height) of every image."""
    ntoc = struct.unpack_from("<I", data, 12)[0]
    for i in range(ntoc):
        kind, size, pos = struct.unpack_from("<III", data, 16 + 12 * i)
        if kind == IMAGE:
            width, height = struct.unpack_from("<II", data, pos + 16)
            yield size, pos + 36, width, height


def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def tinter(fill, outline):
    """Maps premultiplied ARGB pixels (little-endian uint32 bytes): black → fill,
    white → outline. Cursors have few distinct pixels, so each is worked out once."""
    f, o = hex_rgb(fill), hex_rgb(outline)
    cache = {}

    def one(px):
        a, r, g, b = px >> 24, (px >> 16) & 255, (px >> 8) & 255, px & 255
        if a == 0:
            return px
        lum = min(1.0, (0.299 * r + 0.587 * g + 0.114 * b) / a)
        nr, ng, nb = (round((fc + (oc - fc) * lum) * a / 255) for fc, oc in zip(f, o, strict=True))
        return a << 24 | nr << 16 | ng << 8 | nb

    def tint(raw):
        px = array("I", raw)
        for i, v in enumerate(px):
            got = cache.get(v)
            if got is None:
                got = cache[v] = one(v)
            px[i] = got
        return px.tobytes()
    return tint


def tint_file(data, tint):
    if not data.startswith(b"Xcur"):
        return data
    buf = bytearray(data)
    for _, off, w, h in chunks(data):
        end = off + 4 * w * h
        buf[off:end] = tint(bytes(buf[off:end]))
    return bytes(buf)


def unpremultiply(c, a):
    """One premultiplied channel back to straight alpha."""
    return min(255, c * 255 // a) if a else 0


def write_png(path, w, h, bgra):
    """Straight-alpha RGBA PNG from premultiplied BGRA."""
    rows = bytearray()
    for y in range(h):
        rows.append(0)
        for x in range(w):
            b, g, r, a = bgra[4 * (y * w + x):4 * (y * w + x) + 4]
            rows += bytes((unpremultiply(r, a), unpremultiply(g, a), unpremultiply(b, a), a))
    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(bytes(rows))) + chunk(b"IEND", b""))


# ---- commands --------------------------------------------------------------------

def cmd_list():
    have = installed()
    cursors = [{"id": n, "name": n, "installed": n in have} for n in CURATED]
    cursors += [{"id": n, "name": n, "installed": True} for n in sorted(have - set(CURATED), key=str.lower)]
    cursors.sort(key=lambda c: not c["installed"])   # stable: installed first, order kept
    out({"ok": True, **saved(), "cursors": cursors})


def cmd_install(name):
    url = CURATED.get(name)
    if not url:
        out({"ok": False, "error": f"unknown cursor: {name}"})
    ICONS.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        archive = Path(tmp) / "cursor.tar"
        try:
            urllib.request.urlretrieve(url, archive)
            with tarfile.open(archive) as tar:
                tar.extractall(Path(tmp) / "x", filter="data")
        except Exception as e:
            out({"ok": False, "error": f"download failed: {e}"})
        # every listed theme in the archive (phinger ships dark and light at once)
        for index in (Path(tmp) / "x").rglob("index.theme"):
            theme = index.parent
            if theme.name in CURATED and (theme / "cursors").is_dir():
                dst = ICONS / theme.name
                if dst.exists():
                    shutil.rmtree(dst)
                shutil.move(str(theme), dst)
    if name not in installed():
        out({"ok": False, "error": f"{name} not found in the download"})
    out({"ok": True, "name": name})


def cmd_preview(base, fill=None, outline=None):
    src = theme_dir(base)
    if not src:
        out({"ok": False, "error": f"not installed: {base}"})
    dst = PREVIEWS / (base + (f"-{fill}-{outline}" if fill else ""))
    dst.mkdir(parents=True, exist_ok=True)
    tint = tinter(fill, outline) if fill else None
    shapes = []
    for shape, names in SHAPES.items():
        f = next((src / "cursors" / n for n in names if (src / "cursors" / n).exists()), None)
        if not f:
            continue
        data = f.read_bytes()
        images = list(chunks(data))
        if not images:
            continue
        # the nominal size closest to 48: crisp at the preview's 32px
        size, off, w, h = min(images, key=lambda c: abs(c[0] - 48))
        px = data[off:off + 4 * w * h]
        if tint:
            px = tint(px)
        path = dst / f"{shape}.png"
        write_png(path, w, h, px)
        shapes.append({"name": shape, "path": str(path), "width": w, "height": h})
    out({"ok": True, "shapes": shapes})


def build_tinted(base, fill, outline):
    """A complete tinted copy of `base`, including shapes inherited from parents."""
    name = f"{TINTED}{fill}-{outline}"
    dst = ICONS / name
    for old in ICONS.glob(TINTED + "*"):
        if old != dst:
            shutil.rmtree(old, ignore_errors=True)
    if dst.exists():
        shutil.rmtree(dst)
    (dst / "cursors").mkdir(parents=True)
    tint = tinter(fill, outline)

    def cursor_files(theme, seen=()):
        """Return the effective cursor files, with child themes taking precedence."""
        if theme in seen:
            return {}
        folder = theme_dir(theme)
        if not folder:
            return {}

        parents = []
        index = folder / "index.theme"
        if index.is_file():
            metadata = configparser.ConfigParser(interpolation=None)
            try:
                metadata.read(index)
                parents = [item.strip() for item in metadata.get("Icon Theme", "Inherits", fallback="").split(",") if item.strip()]
            except configparser.Error:
                pass

        files = {}
        # The first listed parent has priority over later fallbacks.
        for parent in reversed(parents):
            files.update(cursor_files(parent, (*seen, theme)))

        cursors = folder / "cursors"
        if cursors.is_dir():
            for entry in cursors.iterdir():
                if entry.is_file():
                    files[entry.name] = entry.read_bytes()
                elif entry.is_symlink():
                    # A dangling alias can point to a shape supplied by an inherited theme.
                    files[entry.name] = Path(entry.readlink()).name

        # Resolve aliases after merging parents so dangling child aliases can
        # target an inherited shape. Cyclic or unresolved aliases are omitted.
        resolved = {}

        def resolve(key, trail=()):
            if key in resolved:
                return resolved[key]
            value = files.get(key)
            if isinstance(value, bytes):
                resolved[key] = value
            elif isinstance(value, str) and key not in trail and value != key:
                return resolve(value, (*trail, key))
            return resolved.get(key)

        for key in files:
            data = resolve(key)
            if data is not None:
                resolved[key] = data
        return resolved

    for filename, data in cursor_files(base).items():
        (dst / "cursors" / filename).write_bytes(tint_file(data, tint))
    (dst / "index.theme").write_text(f"[Icon Theme]\nName={name}\nComment={base} tinted by the Shell Manager\n")
    return name


def apply(name, size):
    subprocess.run(["hyprctl", "setcursor", name, str(size)], capture_output=True)
    for key, value in (("cursor-theme", name), ("cursor-size", str(size))):
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", key, value], capture_output=True)


def cmd_set(base, size, mode, fill="", outline=""):
    if base not in installed():
        out({"ok": False, "error": f"not installed: {base}"})
    if not size.isdigit() or not 12 <= int(size) <= 96:
        out({"ok": False, "error": f"bad size: {size}"})
    if mode not in ("original", "theme", "custom"):
        out({"ok": False, "error": f"bad mode: {mode}"})
    tinted = mode != "original"
    if tinted and not all(len(c) == 6 and all(ch in "0123456789abcdef" for ch in c) for c in (fill, outline)):
        out({"ok": False, "error": "colours must be rrggbb"})
    name = build_tinted(base, fill, outline) if tinted else base
    if not tinted:
        for old in ICONS.glob(TINTED + "*"):
            shutil.rmtree(old, ignore_errors=True)
    default = ICONS / "default"
    default.mkdir(parents=True, exist_ok=True)
    (default / "index.theme").write_text(f"[Icon Theme]\n# written by the Shell Manager (cursors.py set)\nInherits={name}\n")
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps({"base": base, "size": int(size), "mode": mode, "fill": fill, "outline": outline, "name": name}) + "\n")
    apply(name, int(size))
    out({"ok": True})


if __name__ == "__main__":
    args = [a.lower().lstrip("#") if i >= 3 else a for i, a in enumerate(sys.argv[1:])]
    if args == ["list"]:
        cmd_list()
    elif args == ["restore"]:
        s = saved()
        if STATE.exists():
            apply(s.get("name", s["base"]), s["size"])
        out({"ok": True})
    elif len(args) == 2 and args[0] == "install":
        cmd_install(args[1])
    elif len(args) in (2, 4) and args[0] == "preview":
        cmd_preview(*args[1:])
    elif len(args) in (4, 6) and args[0] == "set":
        cmd_set(*args[1:])
    out({"ok": False, "error": "usage: cursors.py list | install <name> | preview <base> [<fill> <outline>]"
                               " | set <base> <size> <mode> [<fill> <outline>] | restore"})
