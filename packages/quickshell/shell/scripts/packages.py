#!/usr/bin/env python3
"""Package manager for the shell (apps/packages and its bar module). One JSON
object per command.

    packages.py updates             {"ok", "pacman": [{name, from, to, desc, size, repo}], "aur": [{name, from, to, desc, repo}], "aurError"}
                                    size: the download of the new version, in bytes (0 when unknown)
    packages.py progress <name=ver>… {"ok", "bytes"}: what the cache holds of those versions, and what a running download has so far
    packages.py plan-download <name>… the steps to download them (pacman -Syw) and one script
    packages.py plan-install <name>…  the steps to install them from the cache (pacman -S) and one script
    packages.py installed           {"ok", "packages": [{name, version, desc, size, date, aur, repo, explicit, apps}]}
                                    repo: the sync repo it comes from (core, extra, …), "aur" when none has it
    packages.py cache               {"ok", "packages": [{name, installed, versions: [{version, file, size, date}]}]}
    packages.py last-update         the last upgrade in pacman's log, with its cached files
                                    {"ok", "date", "packages": [{name, from, to, file}], "missing": [{name, from}]}
    packages.py plan-remove <name>… the steps to remove them (pacman -Rns) and one script for pkexec
    packages.py plan-rollback <file>… the steps to install those cached files (pacman -U) and one script
                                    both: {"ok", "steps": [{label, what, command}], "script"}

The repo updates, removing and rolling back run through RootService from the
plans, after the auth panel (apps/auth) shows the steps. The AUR updates are
not here: the shell opens a terminal running `yay -S --needed --sudo pkexec`. Errors: {"ok": false, "error": "..."}."""
import os, re, shlex, subprocess, sys
from pathlib import Path
from backend import out, fail, run

CACHE = Path("/var/cache/pacman/pkg")
LOCAL = Path("/var/lib/pacman/local")
LOG = Path("/var/log/pacman.log")
DESKTOP_DIRS = [Path("/usr/share/applications"), Path.home() / ".local/share/applications"]
NAME = re.compile(r"[A-Za-z0-9@._+-]+")
PKG = re.compile(r"^(?P<name>.+)-(?P<ver>[^-]+-[^-]+)-(?P<arch>[^-.]+)\.pkg\.tar(\.\w+)?$")
UPDATE = re.compile(r"^(\S+) (\S+) -> (\S+)$")
UNITS = {"B": 1, "KiB": 1024, "MiB": 1024 ** 2, "GiB": 1024 ** 3}


def parse_updates(text):
    rows = []
    for line in text.splitlines():
        m = UPDATE.match(line.strip())
        if m:
            rows.append({"name": m.group(1), "from": m.group(2), "to": m.group(3)})
    return rows


def updates():
    # checkupdates syncs a copy of the databases, so it needs no root; exit 2 means none
    cu = run(["checkupdates"], timeout=300)
    if cu is None:
        fail("checkupdates is not installed (pacman-contrib)")
    pacman = parse_updates(cu.stdout)
    aur, err = [], ""
    yay = run(["yay", "-Qua"], timeout=300)
    if yay is None:
        err = "yay is not installed"
    else:
        aur = parse_updates(yay.stdout)
    # what each update is: the description of the installed version, and its repo
    info = qi() or {}
    where = repos()
    for r in pacman + aur:
        r["desc"] = info.get(r["name"], {}).get("desc", "")
    for r in pacman:
        r["repo"] = where.get(r["name"], "")
    for r in aur:
        r["repo"] = "aur"
    # what each repo update downloads: the new versions' sizes from the same copy
    sizes = download_sizes([r["name"] for r in pacman])
    for r in pacman:
        r["size"] = sizes.get(r["name"], 0)
    return {"ok": True, "pacman": pacman, "aur": aur, "aurError": err}


def temp_db():
    # the copy of the databases checkupdates syncs (no root needed); it names it by the user id
    return os.environ.get("CHECKUPDATES_DB") or str(Path(os.environ.get("TMPDIR") or "/tmp") / f"checkup-db-{os.getuid()}")


def download_sizes(names):
    # name -> the size of the new version's download, from the copy of the databases
    if not names:
        return {}
    r = run(["pacman", "-Si", "--dbpath", temp_db()] + names)
    if r is None or r.returncode != 0:
        return {}
    sizes = {}
    for block in r.stdout.strip().split("\n\n"):
        fields = {k.strip(): v.strip() for k, v in
                  (line.split(" : ", 1) for line in block.splitlines() if " : " in line)}
        if fields.get("Name"):
            sizes[fields["Name"]] = size_bytes(fields.get("Download Size", ""))
    return sizes


def progress(args):
    # bytes of the cached files of name=version, finished or still downloading (.part)
    # (the downloading ones are read from the root script's copy, see WATCH)
    sizes = {}
    watched = {}
    if WATCH.is_file():
        for line in WATCH.read_text().splitlines():
            size, _, fname = line.partition(" ")
            if size.isdigit():
                watched[fname.removesuffix(".part")] = int(size)
    for a in args:
        name, _, ver = a.partition("=")
        if not NAME.fullmatch(name) or not re.fullmatch(r"[A-Za-z0-9:._+~-]+", ver):
            fail(f"bad package: {a}")
        pat = re.compile(rf"^{re.escape(name)}-{re.escape(ver)}-[^-]+\.pkg\.tar(\.\w+)?(\.part)?$")
        if CACHE.is_dir():
            for f in CACHE.iterdir():
                if pat.match(f.name) and f.is_file():
                    try:
                        sizes[f.name.removesuffix(".part")] = f.stat().st_size
                    except FileNotFoundError:
                        pass
        for fname, size in watched.items():
            if pat.match(fname):
                sizes[fname] = max(size, sizes.get(fname, 0))
    return {"ok": True, "bytes": sum(sizes.values())}


def size_bytes(text):
    m = re.match(r"([\d.,]+)\s+(\S+)", text.strip())
    if not m:
        return 0
    return int(float(m.group(1).replace(",", ".")) * UNITS.get(m.group(2), 1))


def desktop_apps():
    # the apps shown in menus: their .desktop files, grouped by the package that owns them
    entries = []
    for d in DESKTOP_DIRS:
        if not d.is_dir():
            continue
        for f in sorted(d.glob("*.desktop")):
            name, hidden = None, False
            for line in f.read_text(errors="replace").splitlines():
                if line.startswith("Name=") and name is None:
                    name = line[5:].strip()
                elif line.strip() in ("NoDisplay=true", "Hidden=true"):
                    hidden = True
            if name and not hidden:
                entries.append((str(f), name))
    owners = {}
    paths = [p for p, _ in entries if p.startswith("/usr/")]
    for i in range(0, len(paths), 200):
        r = run(["pacman", "-Qo"] + paths[i:i + 200])
        if r is None:
            continue
        for line in r.stdout.splitlines():
            m = re.match(r"^(\S+) is owned by (\S+) ", line)
            if m:
                owners.setdefault(m.group(2), []).append(m.group(1))
    names = {p: n for p, n in entries}
    by_pkg = {}
    for pkg, files in owners.items():
        by_pkg[pkg] = sorted({names[f] for f in files if f in names})
    return by_pkg


def install_date(name, version):
    # pacman writes the package's desc file when it installs it; its mtime is the date
    try:
        return (LOCAL / f"{name}-{version}" / "desc").stat().st_mtime
    except OSError:
        return 0


def qi():
    # pacman -Qi of every installed package: name -> {version, desc, size, date}
    r = run(["pacman", "-Qi"])
    if r is None or r.returncode != 0:
        return None
    packages = {}
    for block in r.stdout.strip().split("\n\n"):
        f = {}
        for line in block.splitlines():
            if " : " in line:
                k, v = line.split(" : ", 1)
                f.setdefault(k.strip(), v.strip())
        name = f.get("Name")
        if name:
            version = f.get("Version", "")
            packages[name] = {"version": version, "desc": f.get("Description", ""),
                              "size": size_bytes(f.get("Installed Size", "")),
                              "date": install_date(name, version)}
    return packages


def repos():
    # pacman -Sl: name -> the sync repo that has it (the first, as pacman picks)
    r = run(["pacman", "-Sl"])
    where = {}
    for line in (r.stdout if r else "").splitlines():
        parts = line.split()
        if len(parts) >= 2:
            where.setdefault(parts[1], parts[0])
    return where


def installed():
    info = qi()
    if info is None:
        fail("pacman -Qi failed")
    foreign = set((run(["pacman", "-Qmq"]) or subprocess.CompletedProcess([], 1, "")).stdout.split())
    explicit = set((run(["pacman", "-Qeq"]) or subprocess.CompletedProcess([], 1, "")).stdout.split())
    apps = desktop_apps()
    where = repos()
    packages = [{"name": name, "version": i["version"], "desc": i["desc"], "size": i["size"],
                 "date": i["date"], "aur": name in foreign,
                 "repo": "aur" if name in foreign else where.get(name, ""), "explicit": name in explicit,
                 "apps": apps.get(name, [])} for name, i in info.items()]
    packages.sort(key=lambda p: p["name"])
    return {"ok": True, "packages": packages}


def cached():
    # every package file in pacman's cache: name, version (epoch:pkgver-pkgrel), file, size, date
    if not CACHE.is_dir():
        return {}
    files = {}
    for f in CACHE.iterdir():
        m = PKG.match(f.name)
        if not m or not f.is_file():
            continue
        st = f.stat()
        files.setdefault(m.group("name"), []).append({
            "version": m.group("ver"), "file": str(f), "size": st.st_size, "mtime": st.st_mtime})
    for vs in files.values():
        vs.sort(key=lambda v: v["mtime"], reverse=True)
    return files


def installed_versions():
    r = run(["pacman", "-Q"])
    if r is None:
        return {}
    return dict(line.split(" ", 1) for line in r.stdout.splitlines() if " " in line)


def cache_view():
    now = installed_versions()
    packages = []
    for name, vs in sorted(cached().items()):
        packages.append({"name": name, "installed": now.get(name, ""),
                         "versions": [{"version": v["version"], "file": v["file"], "size": v["size"],
                                       "date": v["mtime"]} for v in vs]})
    return {"ok": True, "packages": packages}


def last_update():
    # the log's transactions: the last one with upgrades, each upgrade with the
    # cached file of its old version
    if not LOG.is_file():
        return {"ok": True, "date": "", "packages": [], "missing": []}
    blocks, cur = [], []
    for line in LOG.read_text(errors="replace").splitlines():
        if "[ALPM] transaction started" in line:
            blocks.append(cur)
            cur = []
        cur.append(line)
    blocks.append(cur)
    last = next((b for b in reversed(blocks) if any("[ALPM] upgraded " in l for l in b)), [])
    up = re.compile(r"^\[(?P<date>[^\]]+)\] \[ALPM\] upgraded (\S+) \((\S+) -> (\S+)\)")
    rows = [m for m in (up.match(l) for l in last) if m]
    now = installed_versions()
    files = cached()
    packages, missing = [], []
    for m in rows:
        name, old, new = m.group(2), m.group(3), m.group(4)
        if now.get(name) != new:
            continue                                  # changed again since
        hit = next((v for v in files.get(name, []) if v["version"] == old), None)
        if hit:
            packages.append({"name": name, "from": old, "to": new, "file": hit["file"]})
        else:
            missing.append({"name": name, "from": old})
    return {"ok": True, "date": rows[0].group("date") if rows else "",
            "packages": packages, "missing": missing}


def plan_names(names, label, what, template):
    if not names:
        fail("nothing picked")
    for n in names:
        if not NAME.fullmatch(n):
            fail(f"bad package name: {n}")
    cmd = template.format(names=" ".join(shlex.quote(n) for n in names))
    steps = [{"label": label.format(n=len(names)), "what": what, "command": cmd}]
    return {"ok": True, "steps": steps, "script": cmd}


# the repo updates in the shell: download first (confirmed in the auth panel),
# then install from the cache (a second confirmation)
# pacman downloads into download-*/ dirs only the alpm user can read: the root
# script copies the sizes of what is there into a readable file (WATCH) while
# it runs; the watcher ends with the script's shell, also when it is killed
WATCH = Path("/run/vdx-progress")
WATCHER = (f"( while :; do "
           f"find {CACHE} -maxdepth 2 -type f -printf '%s %f\\n' > {WATCH}.tmp 2>/dev/null; "
           f"chmod 644 {WATCH}.tmp; mv -f {WATCH}.tmp {WATCH}; sleep 0.5; done ) &\n"
           "watcher_pid=$!\n"
           f"trap 'kill \"$watcher_pid\" 2>/dev/null; wait \"$watcher_pid\" 2>/dev/null; rm -f {WATCH} {WATCH}.tmp' EXIT\n")


def plan_download(names):
    plan = plan_names(names, "Download {n} packages", "pacman -Syw: into the cache, nothing installed",
                      "pacman -Syw --noconfirm -- {names}")
    if plan["ok"]:
        plan["script"] = WATCHER + plan["script"]
    return plan


def plan_install(names):
    return plan_names(names, "Install {n} packages", "pacman -S: from the cache",
                      "pacman -S --noconfirm -- {names}")


def plan_remove(names):
    return plan_names(names, "Remove {n} packages", "pacman -Rns: with what only they need",
                      "pacman -Rns --noconfirm -- {names}")


def plan_rollback(files):
    if not files:
        fail("nothing to roll back")
    steps = []
    for f in files:
        p = Path(f)
        m = PKG.match(p.name)
        # only files from pacman's cache, never another path
        if not m or p.parent != CACHE or not p.is_file():
            fail(f"not a cached package: {f}")
        steps.append({"label": f"Install {m.group('name')} {m.group('ver')}",
                      "what": "pacman -U: an older version from the cache",
                      "command": "pacman -U --noconfirm -- " + shlex.quote(f)})
    return {"ok": True, "steps": steps, "script": " && ".join(s["command"] for s in steps)}


def main():
    if len(sys.argv) < 2:
        fail("usage: packages.py updates|progress|installed|cache|last-update|plan-download|plan-install|plan-remove|plan-rollback …")
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == "updates":
        out(updates())
    elif cmd == "installed":
        out(installed())
    elif cmd == "cache":
        out(cache_view())
    elif cmd == "last-update":
        out(last_update())
    elif cmd == "plan-remove":
        out(plan_remove(args))
    elif cmd == "plan-download":
        out(plan_download(args))
    elif cmd == "plan-install":
        out(plan_install(args))
    elif cmd == "progress":
        out(progress(args))
    elif cmd == "plan-rollback":
        out(plan_rollback(args))
    else:
        fail(f"unknown command: {cmd}")


if __name__ == "__main__":
    main()
