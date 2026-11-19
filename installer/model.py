"""dotfiles installer — the link model: packages, themes, managed symlinks, system files, package lists."""

from __future__ import annotations

import os
import json
import re
import shutil
import subprocess
import time
import tomllib
from pathlib import Path

from . import components, machine
from .paths import (
    DEFAULT_THEME,
    HOME,
    PKG,
    PRUNE,
    ROOT,
    SKIP,
    STATE,
    SYSTEM,
    TGT,
    THEME,
    THEME_FILE,
)
from .ui import dim, err, removed, short, warn


def expand(p: str) -> Path:
    return Path(os.path.expanduser(p))


def active_theme() -> str | None:
    """The theme in .theme; DEFAULT_THEME when unset or gone; None without either."""
    name = THEME_FILE.read_text().strip() if THEME_FILE.exists() else ""
    return next((n for n in (name, DEFAULT_THEME) if n and (THEME / n).is_dir()), None)


def themes() -> list[str]:
    if not THEME.is_dir():
        return []
    return sorted(d.name for d in THEME.iterdir() if d.is_dir() and not d.name.startswith("."))


def parse_pkg(pkg: str) -> dict:
    mf = PKG / pkg / "package.toml"
    if mf.is_file():
        try:
            return tomllib.loads(mf.read_text())
        except tomllib.TOMLDecodeError as e:
            err(f"{pkg}: bad package.toml: {e}")
    return {}


def install_dir(pkg: str, man: dict) -> Path:
    d = man.get("dir")
    return expand(d) if d else TGT / pkg


def pkg_names() -> list[str]:
    names = set()
    if PKG.is_dir():
        names |= {p.name for p in PKG.iterdir() if p.is_dir() and not p.name.startswith(".")}
    act = active_theme()
    if act:
        names |= {p.name for p in (THEME / act).iterdir() if p.is_dir()}
    return sorted(names)


def sources_for(pkg: str) -> list[tuple[str, Path]]:
    """Return (relpath, best source) for a package, merging base + active theme."""
    act = active_theme()
    base = PKG / pkg
    th = (THEME / act / pkg) if act else None

    rels: set[str] = set()
    if base.is_dir():
        rels |= {str(f.relative_to(base)) for f in base.rglob("*") if f.is_file()}
    if th and th.is_dir():
        rels |= {str(f.relative_to(th)) for f in th.rglob("*") if f.is_file()}

    # every rel is a file of the theme or of the base: the theme's wins
    return [(rel, th / rel if th and (th / rel).is_file() else base / rel) for rel in sorted(rels)]


def build_entries(every: bool = False) -> list[tuple[Path, Path, str]]:
    """(source, target, package) of every link; only the selected components'
    files unless `every` (a file no component owns is always linked)."""
    entries: list[tuple[Path, Path, str]] = []
    cat = components.load()
    table = components.claims(cat)
    on = None if every else components.selected(cat=cat)

    def wanted(key: str) -> bool:
        name = components.owner(key, table)
        return on is None or name is None or name in on

    if (ROOT / "home").is_dir():
        for f in sorted((ROOT / "home").iterdir()):
            if f.is_file() and f.name not in SKIP and wanted(f"home/{f.name}"):
                entries.append((f, HOME / f.name, "(home)"))

    for pkg in pkg_names():
        man = parse_pkg(pkg)
        idir = install_dir(pkg, man)
        files_map = man.get("files") or {}
        pkg_skip = set(man.get("skip") or [])
        for rel, src in sources_for(pkg):
            if Path(rel).name in SKIP or rel in pkg_skip or not wanted(f"{pkg}/{rel}"):
                continue
            tgt = expand(str(files_map[rel])) if rel in files_map else idir / rel
            entries.append((src, tgt, pkg))

    return entries


def is_managed(p: Path) -> bool:
    """A symlink into this repo (a sibling like ~/.dotfiles-old is not)."""
    if not p.is_symlink():
        return False
    try:
        return p.resolve().is_relative_to(ROOT)
    except (OSError, RuntimeError):
        return False


def _walk(base: Path):
    """Yield file paths under base, pruning heavy/uninteresting dirs."""
    for root, dirs, files in os.walk(base):
        dirs[:] = sorted(d for d in dirs if d not in PRUNE)
        for name in sorted(files):
            yield Path(root) / name


def find_managed() -> list[Path]:
    """Installed dotfile links, excluding checkout sources and AI-owned links."""
    manifest = ROOT / "ai/links.json"
    ai_targets = {HOME / target for target in json.loads(manifest.read_text())["links"]} if manifest.is_file() else set()
    return [p for p in _walk(HOME)
            if not p.is_relative_to(ROOT) and p not in ai_targets and is_managed(p)]


def stale_links(entries: list[tuple[Path, Path, str]]) -> list[Path]:
    expected = {t for _, t, _ in entries}
    return [p for p in find_managed() if p not in expected]


def cleanup_stale(entries: list[tuple[Path, Path, str]] | None = None) -> int:
    entries = entries if entries is not None else build_entries()
    n = 0
    for p in stale_links(entries):
        p.unlink(missing_ok=True)
        removed(f"{short(p)} {dim('(stale)')}")
        n += 1
    return n


def is_same(tgt: Path, src: Path) -> bool:
    if not tgt.is_symlink() or not is_managed(tgt):
        return False
    try:
        return tgt.resolve() == src.resolve()
    except (OSError, ValueError):
        return False


BACKUP = STATE / "backup" / time.strftime("%Y-%m-%dT%H-%M-%S")   # one folder per run


def resolve_conflict(tgt: Path, backup: Path | None = None) -> None:
    """Make room for a symlink. A real file or folder is moved into this run's
    backup folder under its path from ~ (never overwritten, never deleted)."""
    if not tgt.exists() and not tgt.is_symlink():
        return
    if tgt.is_symlink():
        tgt.unlink(missing_ok=True)
        return
    if tgt.is_dir() and not any(c.is_file() and not c.is_symlink() for c in tgt.rglob("*")):
        shutil.rmtree(tgt)
        return
    backup = BACKUP if backup is None else backup
    try:
        dest = backup / tgt.relative_to(HOME)
    except ValueError:
        dest = backup / str(tgt).lstrip("/")
    n = 1
    while dest.exists() or dest.is_symlink():
        dest = dest.with_name(f"{dest.name.rsplit('.~', 1)[0]}.~{n}")
        n += 1
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(tgt), str(dest))
    warn(f"backed up {short(tgt)} -> {short(dest)}")


def create_symlink(src: Path, tgt: Path) -> None:
    tgt.parent.mkdir(parents=True, exist_ok=True)
    tgt.symlink_to(os.path.relpath(src, tgt.parent))


def link_counts(entries: list[tuple[Path, Path, str]]) -> tuple[int, int]:
    """(linked, problems) over all entries."""
    good = sum(1 for src, tgt, _ in entries if src.exists() and is_same(tgt, src))
    return good, len(entries) - good


def system_files(every: bool = False) -> list[Path]:
    """Files under system/ of the selected components (every one with `every`)."""
    files = [f for f in sorted(SYSTEM.rglob("*")) if f.is_file() and f.name not in SKIP] if SYSTEM.is_dir() else []
    if every:
        return files
    cat = components.load()
    keep = set(components.unique(components.selected(cat=cat), cat, "system"))
    claimed = {p for c in cat.values() for p in c["system"]}
    # a file no component claims is installed everywhere (`check components` names it)
    return [f for f in files if str(f.relative_to(SYSTEM)) in keep or str(f.relative_to(SYSTEM)) not in claimed]


PLACEHOLDER = re.compile(rb"@([A-Z_]+)@")


def render(src: Path, hw: dict | None = None) -> bytes:
    """A system file with @KEY@ replaced by this machine's hardware value
    (@BATTERY@ -> BAT1); ValueError when the machine has no such value."""
    data = src.read_bytes()
    if not PLACEHOLDER.search(data):
        return data
    hw = machine.hardware() if hw is None else hw

    def value(m: re.Match) -> bytes:
        v = hw.get(m.group(1).decode().lower())
        if not isinstance(v, str) or not v:
            raise ValueError(f"{m.group(0).decode()}: this machine has no {m.group(1).decode().lower()}")
        return v.encode()

    return PLACEHOLDER.sub(value, data)


def system_state(every: bool = False) -> list[tuple[Path, Path, str]]:
    """(src, dst, state) for the selected system files; state is ok, differs,
    missing, unreadable (a root-only folder, /etc/polkit-1/rules.d) or
    unrenderable (a placeholder this machine has no value for)."""
    out = []
    for src in system_files(every):
        dst = Path("/") / src.relative_to(SYSTEM)
        try:
            want = render(src)
        except ValueError:
            out.append((src, dst, "unrenderable"))
            continue
        try:
            state = "ok" if dst.read_bytes() == want else "differs"
        except FileNotFoundError:
            state = "missing"
        except OSError:
            state = "unreadable"
        out.append((src, dst, state))
    return out


def system_leftovers() -> list[Path]:
    """/etc files of components that are off, still there as we wrote them."""
    on = {src for src in system_files()}
    out = []
    for src in system_files(every=True):
        if src in on:
            continue
        dst = Path("/") / src.relative_to(SYSTEM)
        try:
            if dst.read_bytes() == render(src):
                out.append(dst)
        except (OSError, ValueError):
            pass
    return out


def wanted_packages() -> tuple[list[str], list[str]]:
    """(pacman, aur) names of the selected components."""
    cat = components.load()
    on = components.selected(cat=cat)
    return components.unique(on, cat, "pacman"), components.unique(on, cat, "aur")


def missing_packages() -> tuple[list[str], list[str]]:
    if not shutil.which("pacman"):
        return [], []
    repo, aur = wanted_packages()
    # pacman -T names what no installed package satisfies, provides included:
    # yay-bin satisfies yay, nvidia-open-dkms satisfies nvidia-open
    missing = set(subprocess.run(["pacman", "-T", *repo, *aur], capture_output=True, text=True).stdout.split())
    return [p for p in repo if p in missing], [p for p in aur if p in missing]
