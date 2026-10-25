"""dotfiles installer — `check`: the repo itself (links, syntax, themes, components, tests, the shell, the repo)."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from . import components, detect, hypr, machine
from .links import link_problems
from .model import PLACEHOLDER, build_entries, system_files
from .paths import PKG, ROOT, SKIP, SYSTEM, TGT, THEME
from .ui import err, heading, ok, warn

# `check` looks at the repo, not at the machine: links, the syntax of every
# tracked file, generated themes, package lists, the shell's registry and
# icons, ignored files and trailing whitespace. Each group returns its
# problems as "path: what"; a tool that is not installed skips its part.

SHELL = PKG / "quickshell" / "shell"


def tracked() -> list[Path]:
    """Files git tracks here (submodules are checked in their own repositories)."""
    names = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-z"], capture_output=True, text=True).stdout
    return [ROOT / n for n in names.split("\0") if n and (ROOT / n).is_file() and not (ROOT / n).is_symlink()]


def rel(p: Path) -> str:
    return str(p.relative_to(ROOT))


def strip_jsonc(text: str) -> str:
    """JSON with // and /* */ comments -> plain JSON (strings are left alone)."""
    out, i, n = [], 0, len(text)
    while i < n:
        if text[i] == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            out.append(text[i:j + 1])
            i = j + 1
        elif text.startswith("//", i):
            i = text.find("\n", i) if "\n" in text[i:] else n
        elif text.startswith("/*", i):
            i = text.find("*/", i) + 2 if "*/" in text[i:] else n
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def language(f: Path) -> str:
    """What a tracked file is checked as; "" for nothing."""
    if f.suffix in (".py", ".lua", ".json", ".jsonc", ".toml", ".qml", ".sh"):
        return f.suffix[1:]
    if rel(f).startswith("packages/zsh/") or f.name == ".zshenv":
        return "zsh"
    try:
        first = f.read_text().split("\n", 1)[0]
    except (UnicodeDecodeError, OSError):
        return ""
    if first.startswith("#!"):
        return "py" if "python" in first else "sh" if re.search(r"\b(ba)?sh\b", first) else ""
    return "xml" if first.startswith("<?xml") else ""


def tool_errors(command: list[str], files: list[Path]) -> list[str]:
    """Run a checker on each file; its first output line names the problem."""
    out = []
    for f in files:
        r = subprocess.run(command + [str(f)], capture_output=True, text=True)
        if r.returncode != 0:
            msg = (r.stderr or r.stdout).strip().splitlines()
            line = msg[0].replace(str(f), rel(f)) if msg else "failed"
            out.append(line if rel(f) in line else f"{rel(f)}: {line}")
    return out


def qmllint() -> str | None:
    return shutil.which("qmllint") or next((p for p in ("/usr/lib/qt6/bin/qmllint",) if Path(p).is_file()), None)


def syntax_problems() -> list[str]:
    import tomllib
    import xml.etree.ElementTree as ET
    by: dict[str, list[Path]] = {}
    for f in tracked():
        by.setdefault(language(f), []).append(f)
    out = []
    for f in by.get("py", []):
        try:
            compile(f.read_text(), rel(f), "exec")
        except SyntaxError as e:
            out.append(f"{rel(f)}:{e.lineno}: {e.msg}")
    for f in by.get("json", []) + by.get("jsonc", []):
        try:
            json.loads(strip_jsonc(f.read_text()))
        except ValueError as e:
            out.append(f"{rel(f)}: {e}")
    for f in by.get("toml", []):
        try:
            tomllib.loads(f.read_text())
        except tomllib.TOMLDecodeError as e:
            out.append(f"{rel(f)}: {e}")
    for f in by.get("xml", []):
        try:
            ET.parse(f)
        except ET.ParseError as e:
            out.append(f"{rel(f)}: {e}")
    out += tool_errors(["bash", "-n"], by.get("sh", []))
    for lang, command in (("zsh", ["zsh", "-n"]), ("lua", ["luac", "-p"])):
        if not by.get(lang):
            continue
        if shutil.which(command[0]):
            out += tool_errors(command, by[lang])
        else:
            warn(f"{command[0]} not found: {lang} files not checked")
    lint = qmllint()
    if lint and by.get("qml"):
        # syntax only: the rest of qmllint's warnings are about types it can't
        # see (Quickshell's), not mistakes
        r = subprocess.run([lint, "--json", "-", *map(str, by["qml"])], capture_output=True, text=True)
        try:
            for f in json.loads(r.stdout)["files"]:
                for w in f["warnings"]:
                    if w.get("id") == "syntax":
                        out.append(f"{rel(Path(f['filename']))}:{w.get('line')}: {w['message']}")
        except (ValueError, KeyError):
            out.append(f"qmllint: unreadable output ({r.stderr.strip()[:80]})")
    elif by.get("qml"):
        warn("qmllint not found (qt6-declarative): QML not checked")
    return out


def theme_problems() -> list[str]:
    script = THEME / "mktheme.py"
    if not script.is_file():
        return []
    r = subprocess.run([sys.executable, str(script), "--check"], capture_output=True, text=True)
    stale = [f"{line}: out of date — run themes/mktheme.py" for line in r.stdout.splitlines() if line]
    return stale + ([r.stderr.strip()] if r.returncode and not stale else [])


def components_problems() -> list[str]:
    """The catalog, and that it covers the repo: files, submodules, system/, bar modules, packages."""
    out = components.problems()
    if out:
        return out
    cat = components.load()
    table = components.claims(cat)
    where = "components.toml"
    # every path a component names exists
    for n, c in cat.items():
        for p in c["links"]:
            if not any(base.exists() for base in [ROOT / p, PKG / p, *(d / p for d in THEME.iterdir() if d.is_dir())]):
                out.append(f"{where}: [{n}] links {p!r}: no such file or folder")
        out += [f"{where}: [{n}] system {p!r}: not in system/" for p in c["system"] if not (SYSTEM / p).is_file()]
        out += [f"{where}: [{n}] user_units {p!r}: no such file" for p in c["user_units"]
                if not (ROOT / p).is_file() and not any(p.startswith(s + "/") for s in c["submodules"])]
        out += [f"{where}: [{n}] submodule {p!r}: not in .gitmodules" for p in c["submodules"] if p not in submodule_paths()]
    # every tracked config file has an owner (one no component owns is linked everywhere)
    for f in tracked():
        r = rel(f)
        top, _, rest = r.partition("/")
        if top == "home":
            key = r
        elif top == "packages":
            key = rest
        elif top == "themes" and rest.count("/") >= 2:
            key = rest.split("/", 1)[1]
        else:
            continue
        if Path(key).name not in SKIP and components.owner(key, table) is None:
            out.append(f"{r}: no component links it")
    for p in submodule_paths():
        name = components.owner(p.removeprefix("packages/"), table)
        if name is None or p not in cat[name]["submodules"]:
            out.append(f"{p}: submodule of no component (list it in submodules of the one that links it)")
    # system/: each file belongs to one component
    claimed = [p for c in cat.values() for p in c["system"]]
    out += [f"{where}: system {p!r} is claimed twice" for p in sorted({p for p in claimed if claimed.count(p) > 1})]
    for f in sorted(SYSTEM.rglob("*")) if SYSTEM.is_dir() else []:
        if f.is_file() and f.name not in SKIP and str(f.relative_to(SYSTEM)) not in claimed:
            out.append(f"{rel(f)}: no component installs it")
    # this machine's [hypr] would write a working config
    out += [f".machine.toml: {p}" for p in hypr.problems(machine.load() or {})]
    # placeholders name a text value of the machine profile
    keys = {k.upper() for k, v in detect.hardware(ROOT / "nonexistent").items() if isinstance(v, str)}
    for f in system_files(every=True):
        for m in set(PLACEHOLDER.findall(f.read_bytes())):
            if m.decode() not in keys:
                out.append(f"{rel(f)}: @{m.decode()}@: no such machine value (have {', '.join(sorted(keys))})")
    layout = PKG / "quickshell" / "shell" / "bar" / "BarLayout.qml"
    if layout.is_file():
        out += bar_problems(cat, layout.read_text())
    # packages are real, and in the right list
    repo = components.unique(set(cat), cat, "pacman")
    aur = components.unique(set(cat), cat, "aur")
    if shutil.which("pacman"):
        env = {**os.environ, "LC_ALL": "C"}
        r = subprocess.run(["pacman", "-Si", *repo], capture_output=True, text=True, env=env)
        out += [f"{where}: pacman {p}: in no repository"
                for p in re.findall(r"package '([^']+)' was not found", r.stderr)]
        known = set(subprocess.run(["pacman", "-Slq"], capture_output=True, text=True).stdout.split())
        out += [f"{where}: aur {p}: is in a repository — move it to pacman" for p in aur if p in known]
    return out


def bar_problems(cat: dict, layout_text: str) -> list[str]:
    """The bar's registry against the catalog: every bar module comes with a component, every
    module a component names is a bar module or a music section (BarLayout.sections: files,
    yandex, radio), and every section is brought by one."""
    where = "components.toml"
    ids = set(re.findall(r'\{ id: "(\w+)",', layout_text))
    found = re.search(r"readonly property var sections: \[([^\]]*)\]", layout_text)
    sections = set(re.findall(r'"(\w+)"', found.group(1))) if found else set()
    named = {m for c in cat.values() for m in c["modules"]}
    out = [f"bar module {m!r}: no component brings it" for m in sorted(ids - named)]
    out += [f"{where}: module {m!r}: not in bar/BarLayout.qml" for m in sorted(named - ids - sections)]
    out += [f"bar section {s!r}: no component brings it" for s in sorted(sections - named)]
    return out


def test_problems() -> list[str]:
    """The installer's own tests (tests/); their failures, one line each."""
    if not (ROOT / "tests").is_dir():
        return []
    r = subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-t", ".", "-q"],
                       cwd=ROOT, capture_output=True, text=True,
                       env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
    if r.returncode == 0:
        return []
    lines = [line for line in r.stderr.splitlines() if line.startswith(("FAIL:", "ERROR:"))]
    return lines or [r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "tests failed"]


def hypr_problems() -> list[str]:
    """Hyprland's own parser on the config as linked, and on a copy without
    machine/ (a new machine's): nothing is applied to the running session."""
    if not shutil.which("Hyprland") or not (TGT / "hypr" / "hyprland.lua").exists():
        return []
    out = []
    with tempfile.TemporaryDirectory() as tmp:
        for variant in ("this machine", "a new machine"):
            copy = Path(tmp) / variant.replace(" ", "-")
            shutil.copytree(TGT / "hypr", copy, symlinks=False, ignore=shutil.ignore_patterns("plugins"))
            if variant == "a new machine":
                shutil.rmtree(copy / "machine", ignore_errors=True)
            # Hyprland won't start, even to parse, without a runtime dir (ssh, sudo -u, a container)
            env = {**os.environ, "XDG_RUNTIME_DIR": os.environ.get("XDG_RUNTIME_DIR") or tmp}
            r = subprocess.run(["Hyprland", "--verify-config", "-c", str(copy / "hyprland.lua")],
                               capture_output=True, text=True, timeout=60, env=env)
            result = (r.stdout + r.stderr).split("Config parsing result:")[-1].strip()
            if result != "config ok":
                out += [f"hypr ({variant}): {line.replace(str(copy), '~/.config/hypr')}"
                        for line in result.splitlines() if line.strip()][:5]
    return out


def submodule_paths() -> list[str]:
    f = ROOT / ".gitmodules"
    return re.findall(r"^\s*path\s*=\s*(\S+)", f.read_text(), re.M) if f.is_file() else []


def qml_strings(expr: str) -> list[str]:
    """The string literals of a QML expression, less those it compares against."""
    return [m.group(1) for m in re.finditer(r'"([^"]*)"', expr)
            if not re.search(r"[=!]==?\s*$", expr[:m.start()]) and re.fullmatch(r"[a-z0-9][a-z0-9-]*", m.group(1))]


def icon_uses(path: Path, text: str) -> list[tuple[str, int]]:
    """(icon name, line) written out in a QML file: `icon` / `iconOn` / `iconOff`
    values anywhere, `name` inside a KitIcon."""
    uses = []
    stack: list[str] = []
    for no, line in enumerate(text.splitlines(), 1):
        for m in re.finditer(r"\b(icon(?:On|Off)?)\s*:\s*([^,;}\n]+)", line):
            uses += [(s, no) for s in qml_strings(m.group(2))]
        m = re.match(r"\s*name\s*:\s*(.+)", line)
        if m and stack and stack[-1] == "KitIcon":
            uses += [(s, no) for s in qml_strings(m.group(1))]
        # the object each `{` opens: `KitIcon {` -> KitIcon, anything else -> ?
        code = re.sub(r'"[^"]*"', '""', line.split("//", 1)[0])
        for m in re.finditer(r"([A-Za-z_]\w*)?\s*([{}])", code):
            if m.group(2) == "{":
                stack.append(m.group(1) if m.group(1) and m.group(1)[0].isupper() else "?")
            elif stack:
                stack.pop()
    return uses


def shell_problems() -> list[str]:
    if not SHELL.is_dir():
        return []
    out = []

    def srel(p: Path) -> str:
        return str(p.relative_to(SHELL))

    qml = {p: p.read_text() for p in sorted(SHELL.rglob("*.qml"))}
    # icons: every outline icon has its solid twin, every name written out exists
    icons = SHELL / "kit" / "icons"
    outline = {p.stem for p in icons.glob("*.svg")}
    solid = {p.stem for p in (icons / "solid").glob("*.svg")}
    out += [f"kit/icons/{n}.svg: no solid/ twin" for n in sorted(outline - solid)]
    out += [f"kit/icons/solid/{n}.svg: no outline twin" for n in sorted(solid - outline)]
    # ...and both their Rounded twins (Appearance › Corners round)
    for sub in ("round", "round/solid"):
        have = {p.stem for p in (icons / sub).glob("*.svg")}
        out += [f"kit/icons/{n}.svg: no {sub}/ twin" for n in sorted(outline - have)]
    registry = SHELL / "apps" / "apps.json"
    apps = json.loads(registry.read_text()) if registry.is_file() else []
    uses = [(srel(p), n, no) for p, text in qml.items() for n, no in icon_uses(p, text)]
    uses += [("apps/apps.json", a["icon"], 0) for a in apps if "icon" in a]
    out += [f"{f}:{no}: no icon {n!r} in kit/icons" for f, n, no in uses if n not in outline]
    # Every KitIcon Phosphor alias must have both locally bundled weights. This
    # catches a typo or a missing asset before it becomes an invisible glyph.
    kit_icon = icons.parent / "KitIcon.qml"
    kit_text = kit_icon.read_text() if kit_icon.is_file() else ""
    phosphor = icons / "phosphor"
    aliases = dict(re.findall(r'"([a-z0-9-]+)"\s*:\s*"([a-z0-9-]+)"', kit_text))
    # The runtime renderer must never silently load legacy Material SVGs.
    if 'Qt.resolvedUrl("icons/"' in kit_text or 'Theme.round ? "round/"' in kit_text:
        out.append("kit/KitIcon.qml: legacy Material runtime fallback remains")
    if "icons/phosphor/" not in kit_text:
        out.append("kit/KitIcon.qml: Phosphor asset path is missing")
    if not re.search(r"\\bbrightness\\s*:\\s*1\\b", kit_text) or not re.search(r"\\bcolorization\\s*:\\s*1\\b", kit_text) or not re.search(r"\\bcolorizationColor\\s*:\\s*root\\.tint\\b", kit_text):
        out.append("kit/KitIcon.qml: SVG tint normalization is incomplete")
    for key, glyph in sorted(aliases.items()):
        for suffix in ("", "-fill"):
            asset = phosphor / f"{glyph}{suffix}.svg"
            if not asset.is_file():
                out.append(f"kit/KitIcon.qml: {key!r} maps to missing Phosphor asset {asset.name}")
    # Every key in the legacy catalogue must be covered, otherwise it silently
    # falls back to Material and the migration can regress unnoticed.
    catalogue = icons / "material.txt"
    if catalogue.is_file():
        legacy_keys = {line.split()[0] for line in catalogue.read_text().splitlines()
                       if line.strip() and not line.lstrip().startswith("#")}
        out += [f"kit/KitIcon.qml: missing Phosphor alias for legacy key {key!r}"
                for key in sorted(legacy_keys - aliases.keys())]
    # imports
    for p, text in qml.items():
        for m in re.finditer(r"^import qs\.([\w.]+)", text, re.M):
            if not (SHELL / m.group(1).replace(".", "/")).is_dir():
                out.append(f"{srel(p)}: import qs.{m.group(1)}: no such folder")
    # scripts the QML runs
    for p, text in qml.items():
        for m in re.finditer(r'scriptsDir \+ "/([\w.-]+)"', text):
            if not (SHELL / "scripts" / m.group(1)).is_file():
                out.append(f"{srel(p)}: scripts/{m.group(1)}: no such script")
    # the bar's registry: a folder, a settings page and a Component per module
    layout, bar = SHELL / "bar" / "BarLayout.qml", SHELL / "bar" / "ModuleFaces.qml"
    modules = re.findall(r'\{ id: "(\w+)",[^}]*\}', qml.get(layout, ""))
    components = set(re.findall(r"Component\s*\{\s*id:\s*(\w+)", qml.get(bar, "")))
    for entry in re.findall(r'\{ id: "\w+",[^}]*\}', qml.get(layout, "")):
        mid = re.search(r'id: "(\w+)"', entry).group(1)
        settings = re.search(r'settings: "([\w.]+)"', entry)
        if settings and not (SHELL / "modules" / mid / settings.group(1)).is_file():
            out.append(f"bar/BarLayout.qml: {mid}: no modules/{mid}/{settings.group(1)}")
        if mid not in components:
            out.append(f"bar/ModuleFaces.qml: no Component for module {mid}")
    # the apps' registry: files, modules, IPC targets and binds it names
    targets = set(re.findall(r'(?:target|ipcTarget):\s*"([\w-]+)"', "\n".join(qml.values())))
    keybinds = PKG / "hypr" / "components" / "keybinds.lua"
    binds = keybinds.read_text() if keybinds.is_file() else ""
    for a in apps:
        aid = a.get("id", "?")
        for key in ("settings", "moduleSettings"):
            if key in a and not (SHELL / a[key]).is_file():
                out.append(f"apps/apps.json: {aid}: no {a[key]}")
        if "module" in a and a["module"] not in modules:
            out.append(f"apps/apps.json: {aid}: no bar module {a['module']!r}")
        if a.get("ipc") and a["ipc"] not in targets:
            out.append(f"apps/apps.json: {aid}: no IPC target {a['ipc']!r}")
        if a.get("bind") and f'"{a["bind"]}"' not in binds:
            out.append(f"apps/apps.json: {aid}: no bind {a['bind']!r} in hypr/components/keybinds.lua")
    # IPC targets written out twice answer only once
    found = re.findall(r'(?:target|ipcTarget):\s*"([\w-]+)"', "\n".join(t for p, t in qml.items() if "IpcHandler" in t or "ipcTarget" in t))
    out += [f"IPC target {t!r} is declared twice" for t in sorted({t for t in found if found.count(t) > 1})]
    # the Shell Manager's search index is read from the pages: rebuilt with them
    index = SHELL / "scripts" / "settings_index.py"
    if index.is_file():
        r = subprocess.run([sys.executable, str(index), "--check"], capture_output=True, text=True)
        out += [f"{line}: out of date — run {rel(index)}" for line in r.stdout.splitlines() if line]
    return out


def repo_problems() -> list[str]:
    out = []
    ignored = subprocess.run(["git", "-C", str(ROOT), "ls-files", "-ci", "--exclude-standard"],
                             capture_output=True, text=True).stdout.split()
    out += [f"{f}: tracked but ignored (.gitignore) — a secret?" for f in ignored]
    for f in tracked():
        if f.suffix == ".md":                       # two trailing spaces are a line break there
            continue
        try:
            lines = f.read_text().splitlines()
        except (UnicodeDecodeError, OSError):
            continue
        bad = [i for i, line in enumerate(lines, 1) if line != line.rstrip()]
        if bad:
            out.append(f"{rel(f)}:{bad[0]}: trailing whitespace" + (f" (+{len(bad) - 1} more)" if len(bad) > 1 else ""))
    return out


CHECKS = {
    "links": lambda: link_problems(build_entries()),
    "syntax": syntax_problems,
    "themes": theme_problems,
    "components": components_problems,
    "tests": test_problems,
    "hypr": hypr_problems,
    "shell": shell_problems,
    "repo": repo_problems,
}


def cmd_check(args) -> int:
    unknown = [g for g in args.groups if g not in CHECKS]
    if unknown:
        err(f"no such check: {', '.join(unknown)} (have: {', '.join(CHECKS)})")
        return 2
    heading("Checking the repo")
    total = 0
    for name in args.groups or CHECKS:
        problems = CHECKS[name]()
        total += len(problems)
        if not problems:
            ok(name)
            continue
        err(f"{name}: {len(problems)} problem(s)")
        for line in problems:
            print(f"      {line}")
    return 1 if total else 0
