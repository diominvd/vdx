#!/usr/bin/env python3
"""System monospace font for the Shell Manager. One JSON object per command.

    fonts.py list            {"ok", "current", "fonts": [{id, family, installed}]}
    fonts.py install <id>    Nerd Font <id> into ~/.local/share/fonts/<id>  {"ok", "family"}
    fonts.py set <family>    makes <family> the `monospace` font             {"ok"}

`monospace` is what mako and other programs ask for (kitty also gets the
name itself in ~/.config/kitty/font.conf, it reloads that live):
~/.config/fontconfig/fonts.conf (packages/fontconfig) includes the choice,
~/.local/state/dotfiles/font.conf, ahead of its own default. Errors:
{"ok": false, "error": "..."}."""
import shutil, sys, tarfile, tempfile, urllib.request
from pathlib import Path
from backend import fail, out, run, run_checked

FONTS = Path.home() / ".local/share/fonts"
CHOICE = Path.home() / ".local/state/dotfiles/font.conf"
KITTY = Path.home() / ".config/kitty/font.conf"   # local, not linked: kitty.conf globincludes it
RELEASE = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/{}.tar.xz"

# Nerd Fonts release asset -> the family it installs (all under ~120 MB;
# Iosevka and ZedMono ship every width and weigh close to a gigabyte)
CURATED = {
    "JetBrainsMono": "JetBrainsMono Nerd Font",
    "GeistMono": "GeistMono Nerd Font",
    "CommitMono": "CommitMono Nerd Font",
    "IBMPlexMono": "BlexMono Nerd Font",
    "MartianMono": "MartianMono Nerd Font",
    "FiraCode": "FiraCode Nerd Font",
    "CascadiaCode": "CaskaydiaCove Nerd Font",
    "SourceCodePro": "SauceCodePro Nerd Font",
    "Hack": "Hack Nerd Font",
    "0xProto": "0xProto Nerd Font",
    "Lilex": "Lilex Nerd Font",
    "VictorMono": "VictorMono Nerd Font",
    "AtkinsonHyperlegibleMono": "AtkynsonMono Nerd Font",
}


def families():
    """Installed monospace families: the first name of each fc-list entry."""
    text = run_checked(["fc-list", ":spacing=mono", "family"]).stdout
    names = {line.split(",")[0].strip() for line in text.splitlines() if line.strip()}
    # not the Nerd Font Mono / Propo variants, not emoji
    return {n for n in names if (not n.endswith((" Mono", " Propo")) or "Nerd Font" not in n) and "Emoji" not in n}


def current():
    return run_checked(["fc-match", "-f", "%{family[0]}", "monospace"]).stdout.strip()


def refresh_cache():
    """Refresh fontconfig after installing files; this is required for success."""
    run_checked(["fc-cache", "-f", str(FONTS)], timeout=60)


def cmd_list():
    have = families()
    fonts = [{"id": i, "family": f, "installed": f in have} for i, f in CURATED.items()]
    known = set(CURATED.values())
    fonts += [{"id": "", "family": f, "installed": True} for f in sorted(have - known, key=str.lower)]
    fonts.sort(key=lambda f: not f["installed"])     # stable: installed first, order kept
    out({"ok": True, "current": current(), "fonts": fonts})


def cmd_install(fid):
    if fid not in CURATED:
        out({"ok": False, "error": f"unknown font: {fid}"})
    dst = FONTS / fid
    with tempfile.TemporaryDirectory() as tmp:
        archive = Path(tmp) / "font.tar.xz"
        try:
            urllib.request.urlretrieve(RELEASE.format(fid), archive)
            with tarfile.open(archive) as tar:
                tar.extractall(Path(tmp) / "x", filter="data")
        except Exception as e:
            out({"ok": False, "error": f"download failed: {e}"})
        if dst.exists():
            shutil.rmtree(dst)
        dst.mkdir(parents=True)
        # only the base family: the Mono / Propo variants would crowd every list
        for f in (Path(tmp) / "x").rglob("*"):
            if f.suffix.lower() in (".ttf", ".otf") and "NerdFontMono" not in f.name and "NerdFontPropo" not in f.name:
                shutil.move(str(f), dst / f.name)
    refresh_cache()
    out({"ok": True, "family": CURATED[fid]})


def cmd_set(family):
    if family not in families():
        out({"ok": False, "error": f"not installed: {family}"})
    CHOICE.parent.mkdir(parents=True, exist_ok=True)
    esc = family.replace("&", "&amp;").replace("<", "&lt;")
    CHOICE.write_text(
        '<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "fonts.dtd">\n'
        "<!-- written by the Shell Manager (fonts.py set) -->\n<fontconfig>\n"
        f'  <alias binding="strong"><family>monospace</family><prefer><family>{esc}</family></prefer></alias>\n'
        "</fontconfig>\n")
    KITTY.parent.mkdir(parents=True, exist_ok=True)
    KITTY.write_text(f"# written by the Shell Manager (fonts.py set)\nfont_family {family}\n")
    # running programs that can reload; the rest pick it up when they start
    run(["pkill", "-USR1", "-x", "kitty"], timeout=3)
    run(["makoctl", "reload"], timeout=3)
    out({"ok": True})


def main(args):
    try:
        if args == ["list"]:
            cmd_list()
        elif len(args) == 2 and args[0] == "install":
            cmd_install(args[1])
        elif len(args) == 2 and args[0] == "set":
            cmd_set(args[1])
        fail("usage: fonts.py list | install <id> | set <family>")
    except (OSError, RuntimeError) as e:
        fail(str(e))


if __name__ == "__main__":
    main(sys.argv[1:])
