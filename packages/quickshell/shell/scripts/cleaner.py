#!/usr/bin/env python3
"""System cleanup for the cleaner (apps/cleaner and its bar module). One JSON
object per command.

    cleaner.py scan                 {"ok", "total", "categories": [{id, label, hint, size, root, safe, command?}]}
    cleaner.py clean <id>…          empties those user categories          {"ok", "freed"}
    cleaner.py plan <id>…           the root ones' steps and one script for pkexec
                                    {"ok", "steps": [{label, what, command}], "script", "size"}
    cleaner.py ai [model]           Claude suggests what in ~ could go
                                    {"ok", "suggestions": [{path, size, days, kind, why, risk}]}
    cleaner.py trash <path>…        moves suggested paths to the Trash     {"ok", "freed"}

User categories are caches that rebuild themselves, the thumbnails and the
Trash: emptied in place. Root ones (pacman's cache, orphans, the journal,
core dumps) are only planned here: the shell shows the steps and runs the
script itself through pkexec (apps/auth, RootService), so polkit's
five-minute password memory holds between runs.
The AI mode hands Claude a summary of ~ (sizes, ages — no file contents) with
no tools; it may only suggest paths from that summary, never protected ones
(the dotfiles, keys, config), and they go to the Trash, not away.
Errors: {"ok": false, "error": "..."}."""
import json, os, re, shutil, subprocess, sys, time
from pathlib import Path
from backend import fail, out, run, run_checked

HOME = Path.home()
CACHE = HOME / ".cache"
CONTEXT = HOME / ".cache/dotfiles/cleaner-ai.json"     # what the AI was shown: the only paths it may name

# id, label, hint, folders whose contents go, safe (checked by default)
USER = [
    ("trash", "Trash", "files you deleted", [HOME / ".local/share/Trash/files", HOME / ".local/share/Trash/info"], True),
    ("thumbnails", "Thumbnails", "file manager previews", [CACHE / "thumbnails"], True),
    ("aur", "AUR builds", "yay / paru build folders", [CACHE / "yay", CACHE / "paru"], True),
    ("dev", "Developer caches", "pip, npm, uv, go, cargo downloads",
     [CACHE / "pip", CACHE / "npm", HOME / ".npm/_cacache", CACHE / "uv", CACHE / "go-build",
      HOME / ".cargo/registry/cache"], True),
    ("shaders", "Shader caches", "GPU shaders, built again on demand",
     [CACHE / "mesa_shader_cache", CACHE / "nvidia/GLCache", HOME / ".nv/ComputeCache"], True),
    ("browsers", "Browser caches", "close the browsers first",
     [CACHE / "BraveSoftware", CACHE / "mozilla", CACHE / "chromium", CACHE / "google-chrome"], False),
]
# id, label, hint, size probe, command (run as root through pkexec)
ROOT = [
    ("pacman", "Package cache", "keeps the newest version of each", "pacman",
     "paccache -rk1 && paccache -ruk0"),
    ("orphans", "Orphan packages", "dependencies nothing needs now", "orphans",
     'o=$(pacman -Qdtq); if [ -n "$o" ]; then pacman -Rns --noconfirm $o; fi'),
    ("journal", "System journal", "keeps the last two weeks", "journal", "journalctl --vacuum-time=2weeks"),
    ("coredumps", "Crash dumps", "core dumps of crashed programs", "coredumps",
     "find /var/lib/systemd/coredump -type f -delete"),
]
PROTECTED = [HOME / p for p in (".dotfiles", ".ssh", ".gnupg", ".config", ".local/share/keyrings",
                                ".password-store", ".local/state", ".mozilla", ".thunderbird")]


def size_of(path):
    """Bytes under a path, not following symlinks; 0 when it isn't there."""
    total = 0
    try:
        if path.is_symlink() or path.is_file():
            return path.lstat().st_size
        for root, _dirs, files in os.walk(path, followlinks=False):
            for name in files:
                try:
                    total += os.lstat(os.path.join(root, name)).st_size
                except OSError:
                    pass
    except OSError:
        pass
    return total


def probe(kind, required=False):
    try:
        if kind == "pacman":
            return size_of(Path("/var/cache/pacman/pkg"))
        if kind == "coredumps":
            return size_of(Path("/var/lib/systemd/coredump"))
        if kind == "journal":
            result = run(["journalctl", "--disk-usage"], timeout=15)
            if result is None or result.returncode:
                if required:
                    raise RuntimeError("journalctl is unavailable or failed")
                return 0
            text = result.stdout
            m = re.search(r"take up ([\d.]+)([KMGT]?)", text)
            if m:
                return int(float(m.group(1)) * 1024 ** "BKMGT".index(m.group(2) or "B"))
        if kind == "orphans":
            result = run(["pacman", "-Qdtq"], timeout=15)
            if result is None or result.returncode:
                if required:
                    raise RuntimeError("pacman orphan query is unavailable or failed")
                return 0
            names = result.stdout.split()
            if not names:
                return 0
            result = run(["pacman", "-Qi"] + names, timeout=30)
            if result is None or result.returncode:
                if required:
                    raise RuntimeError("pacman package query is unavailable or failed")
                return 0
            info = result.stdout
            total = 0
            for value, unit in re.findall(r"Installed Size\s*:\s*([\d.]+)\s*(\w+)", info):
                total += int(float(value) * {"B": 1, "KiB": 1024, "MiB": 1024 ** 2, "GiB": 1024 ** 3}.get(unit, 1))
            return total
    except (OSError, ValueError, OverflowError, RuntimeError):
        if required:
            raise
        pass
    return 0


def cmd_scan():
    cats = []
    for cid, label, hint, dirs, safe in USER:
        size = sum(size_of(d) for d in dirs)
        cats.append({"id": cid, "label": label, "hint": hint, "size": size, "root": False, "safe": safe})
    for cid, label, hint, kind, command in ROOT:
        cats.append({"id": cid, "label": label, "hint": hint, "size": probe(kind), "root": True, "safe": True,
                     "command": command})
    out({"ok": True, "total": sum(c["size"] for c in cats), "categories": cats})


def empty(folder):
    """Removes what is inside `folder` (not the folder itself); bytes freed."""
    freed = 0
    if not folder.is_dir() or folder.is_symlink():
        return 0
    for child in folder.iterdir():
        size = size_of(child)
        try:
            if child.is_dir() and not child.is_symlink():
                shutil.rmtree(child)
            else:
                child.unlink()
            freed += size
        except OSError:
            pass
    return freed


def cmd_clean(ids):
    known = {c[0]: c for c in USER}
    bad = [i for i in ids if i not in known]
    if bad:
        out({"ok": False, "error": f"not a user category: {bad[0]}"})
    freed = sum(empty(d) for i in ids for d in known[i][3])
    out({"ok": True, "freed": freed})


def detail(cid):
    """What a system step is about to do, in words, with what it will touch."""
    if cid == "pacman":
        pkgs = Path("/var/cache/pacman/pkg")
        n = sum(1 for f in pkgs.glob("*.pkg.tar.*") if not f.name.endswith(".sig")) if pkgs.is_dir() else 0
        return f"removes old versions of {n} cached packages, keeps the newest; uninstalled ones go"
    if cid == "orphans":
        names = run_checked(["pacman", "-Qdtq"], timeout=15).stdout.split()
        if not names:
            return "nothing to remove"
        shown = ", ".join(names[:8]) + (f" and {len(names) - 8} more" if len(names) > 8 else "")
        return f"uninstalls {len(names)}: {shown}"
    if cid == "journal":
        return "deletes system log entries older than two weeks"
    if cid == "coredumps":
        d = Path("/var/lib/systemd/coredump")
        n = sum(1 for _ in d.iterdir()) if d.is_dir() else 0
        return f"deletes {n} crash dumps"
    return ""


def cmd_plan(ids):
    known = {c[0]: c for c in ROOT}
    bad = [i for i in ids if i not in known]
    if bad or not ids:
        out({"ok": False, "error": f"not a system category: {bad[0] if bad else '(none)'}"})
    steps = [{"label": known[i][1], "what": detail(i), "command": known[i][4]} for i in ids]
    out({"ok": True, "steps": steps, "script": "; ".join(known[i][4] for i in ids),
         "size": sum(probe(known[i][3], required=i == "orphans") for i in ids)})


# ---- AI ----------------------------------------------------------------------------

def summary():
    """Folders of ~ three levels down from 100 MB, files from 200 MB, with ages."""
    now = time.time()
    rows = []
    du = run_checked(["du", "-x", "-B1", "-d", "3", "--threshold=100M", str(HOME)], timeout=120).stdout
    for line in du.splitlines():
        size, path = line.split("\t", 1)
        p = Path(path)
        if p == HOME:
            continue
        rows.append((path, int(size), "dir"))
    found = run_checked(["find", str(HOME), "-xdev", "-type", "f", "-size", "+200M", "-printf", "%s\t%p\n"],
                        timeout=120).stdout
    for line in found.splitlines():
        size, path = line.split("\t", 1)
        rows.append((path, int(size), "file"))
    items = []
    for path, size, kind in sorted(rows, key=lambda r: -r[1])[:120]:
        try:
            age = int((now - os.lstat(path).st_mtime) / 86400)
        except OSError:
            continue
        items.append({"path": path.replace(str(HOME), "~", 1), "kind": kind, "mb": size // 1048576, "days": age})
    return items


def protected(path):
    p = Path(os.path.realpath(path))
    if p == HOME or HOME not in p.parents:
        return True
    return any(p == q or q in p.parents or p in q.parents for q in PROTECTED)


PROMPT = """You help free disk space in a Linux (Arch) user's home folder. Below is a list
of its biggest folders and files: path (~ is home), kind, size in MB, days since
it last changed. You see no contents.

Suggest at most 15 entries from THIS LIST that are most likely safe to delete:
caches, build output (node_modules, target, .venv, __pycache__, dist) of
projects untouched for long, old downloads, installers, ISO images, archives
next to their unpacked folder, leftovers of uninstalled programs. Prefer big
and old. Skip anything that may hold the user's own work (documents, photos,
code that changed recently, mail, games' saves) and anything you are unsure
of. Never name a folder that contains another entry you would keep.

Answer with ONLY this JSON, nothing else:
{"suggestions": [{"path": "<exactly as listed>", "why": "<under 70 characters>", "risk": "low" | "medium"}]}

The list:
"""


def claude_env():
    """The environment for `claude -p`: the signed-in account, not an API key
    left in the session (it wins over the login and may be stale), and no
    Claude Code session this was started from."""
    return {k: v for k, v in os.environ.items()
            if k != "ANTHROPIC_API_KEY" and k != "CLAUDECODE" and not k.startswith("CLAUDE_CODE_")}


def cmd_ai(model):
    items = summary()
    CONTEXT.parent.mkdir(parents=True, exist_ok=True)
    CONTEXT.write_text(json.dumps(items))
    listing = "\n".join(f'{i["path"]}\t{i["kind"]}\t{i["mb"]} MB\t{i["days"]} d' for i in items)
    try:
        process = subprocess.run(["claude", "-p", PROMPT + listing, "--model", model, "--output-format", "json",
                                  "--tools", "", "--no-session-persistence", "--max-budget-usd", "0.50"],
                                 capture_output=True, text=True, timeout=240, cwd=str(CACHE), env=claude_env())
    except FileNotFoundError:
        fail("claude is not installed")
    except OSError as e:
        fail(f"could not start claude: {e}")
    except subprocess.TimeoutExpired:
        fail("Claude took too long (4 min)")
    try:
        reply = json.loads(process.stdout)
        if not isinstance(reply, dict):
            raise TypeError("invalid Claude response")
        text = reply.get("result", "")
        if reply.get("is_error"):
            fail("Claude: " + (text if isinstance(text, str) and text else "error")[:200])
        if not isinstance(text, str):
            raise TypeError("invalid Claude result")
        text = re.sub(r"^```(?:json)?|```$", "", text.strip(), flags=re.M).strip()
        wanted = json.loads(text[text.index("{"):text.rindex("}") + 1])["suggestions"]
        if not isinstance(wanted, list):
            raise TypeError("suggestions must be a list")
    except (ValueError, KeyError, TypeError, AttributeError):
        fail("Claude's answer wasn't the list: " + (process.stderr or process.stdout)[:200])
    shown = {i["path"]: i for i in items}
    suggestions = []
    for s in wanted:
        if not isinstance(s, dict) or not isinstance(s.get("path"), str):
            continue
        item = shown.get(s["path"])
        if not item:
            continue                                     # not from the list: ignored
        real = str(HOME / item["path"][2:]) if item["path"].startswith("~/") else item["path"]
        if protected(real) or not os.path.lexists(real):
            continue
        why = s.get("why") if isinstance(s.get("why"), str) else ""
        suggestions.append({"path": item["path"], "size": item["mb"] * 1048576, "days": item["days"],
                            "kind": item["kind"], "why": why[:90],
                            "risk": "medium" if s.get("risk") == "medium" else "low"})
    out({"ok": True, "suggestions": suggestions})


def cmd_trash(paths):
    try:
        cached = json.loads(CONTEXT.read_text())
    except (OSError, ValueError) as e:
        fail(f"could not read last analysis: {e}")
    if not isinstance(cached, list) or not all(
        isinstance(item, dict) and isinstance(item.get("path"), str) and item["path"]
        for item in cached
    ):
        fail("last analysis is invalid")
    shown = {item["path"] for item in cached}
    freed, errors = 0, []
    for path in paths:
        if path not in shown:
            errors.append(f"{path}: not in the last analysis")
            continue
        real = str(HOME / path[2:]) if path.startswith("~/") else path
        if protected(real):
            errors.append(f"{path}: protected")
            continue
        size = size_of(Path(real))
        moved = run(["gio", "trash", real], timeout=30)
        if moved is None:
            errors.append(f"{path}: gio is unavailable or timed out")
        elif moved.returncode == 0:
            freed += size
        else:
            errors.append(f"{path}: {(moved.stderr.strip() or 'gio trash failed')[:80]}")
    if errors:
        out({"ok": False, "error": "; ".join(errors[:3]), "freed": freed})
    out({"ok": True, "freed": freed})


def main(args):
    try:
        if args == ["scan"]:
            cmd_scan()
        elif len(args) >= 2 and args[0] == "clean":
            cmd_clean(args[1:])
        elif len(args) >= 2 and args[0] == "plan":
            cmd_plan(args[1:])
        elif args[:1] == ["ai"] and len(args) <= 2:
            cmd_ai(args[1] if len(args) == 2 else "haiku")
        elif len(args) >= 2 and args[0] == "trash":
            cmd_trash(args[1:])
        fail("usage: cleaner.py scan | clean <id>… | plan <id>… | ai [model] | trash <path>…")
    except (OSError, ValueError, RuntimeError) as e:
        fail(str(e))


if __name__ == "__main__":
    main(sys.argv[1:])
