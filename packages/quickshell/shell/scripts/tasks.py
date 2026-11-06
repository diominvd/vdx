#!/usr/bin/env python3
"""Processes for the task manager (apps/taskmanager). One JSON object per command.

    tasks.py list                   {"ok", "cpu", "memUsed", "memTotal", "cores",
                                     "procs": [{pid, ppid, name, user, mine, kernel, cpu, mem, threads, cmd}]}
    tasks.py kill <TERM|KILL> <pid>…  {"ok", "killed": n}

`cpu` (machine and per process) is the share of all cores since the previous
`list` (0–100), from a snapshot in ~/.cache/dotfiles/tasks.json — the first
call reads 0, and so does the first call after a reboot. `mem` is the resident size in bytes. Errors: {"ok": false, "error": "..."}."""
import json, os, pwd, signal, sys
from pathlib import Path
from backend import out

SNAPSHOT = Path.home() / ".cache/dotfiles/tasks.json"
PAGE = os.sysconf("SC_PAGE_SIZE")
ME = os.getuid()


def cpu_times():
    with open("/proc/stat") as f:
        parts = [int(x) for x in f.readline().split()[1:]]
    return sum(parts), parts[3] + parts[4]          # total, idle + iowait


def boot_time():
    # the counters in /proc/stat restart at every boot
    with open("/proc/stat") as f:
        for line in f:
            if line.startswith("btime "):
                return int(line.split()[1])
    return 0


def meminfo():
    info = {}
    with open("/proc/meminfo") as f:
        for line in f:
            key, value = line.split(":", 1)
            info[key] = int(value.split()[0]) * 1024
    return info["MemTotal"] - info["MemAvailable"], info["MemTotal"]


users = {}


def user(uid):
    if uid not in users:
        try:
            users[uid] = pwd.getpwuid(uid).pw_name
        except KeyError:
            users[uid] = str(uid)
    return users[uid]


def read_proc(pid):
    base = f"/proc/{pid}"
    with open(base + "/stat") as f:
        stat = f.read()
    # comm may hold spaces and parens: it ends at the last ')'
    comm = stat[stat.index("(") + 1:stat.rindex(")")]
    fields = stat[stat.rindex(")") + 2:].split()
    ppid, utime, stime, threads = int(fields[1]), int(fields[11]), int(fields[12]), int(fields[17])
    with open(base + "/statm") as f:
        rss = int(f.read().split()[1]) * PAGE
    with open(base + "/cmdline", "rb") as f:
        argv = [a.decode(errors="replace") for a in f.read().split(b"\0") if a]
    uid = os.stat(base).st_uid
    name = comm
    # comm is cut at 15 characters; the program's own name reads better
    if argv:
        first = os.path.basename(argv[0].split(" ")[0])
        if len(comm) >= 15 and first.startswith(comm[:8]):
            name = first
    return {
        "pid": pid, "ppid": ppid, "name": name, "user": user(uid), "mine": uid == ME,
        "kernel": not argv and (ppid == 2 or pid == 2), "jiffies": utime + stime,
        "mem": rss, "threads": threads, "cmd": " ".join(argv)[:300],
    }


def cmd_list():
    total, idle = cpu_times()
    boot = boot_time()
    try:
        prev = json.loads(SNAPSHOT.read_text())
    except (OSError, ValueError):
        prev = {}
    # no baseline after a reboot or when the counters did not move forward
    # (CPU hotplug): a stale snapshot would divide by a 1-jiffy window
    if prev.get("boot") != boot or not 0 < prev.get("total", 0) < total:
        prev = {}
    d_total = total - prev["total"] if prev else 1
    d_idle = idle - prev["idle"] if prev else 0
    old = prev.get("procs", {})

    procs, now = [], {}
    for entry in os.scandir("/proc"):
        if not entry.name.isdigit():
            continue
        try:
            p = read_proc(int(entry.name))
        except (OSError, ValueError, IndexError):
            continue                                      # gone meanwhile
        now[entry.name] = p["jiffies"]
        before = old.get(entry.name)
        # a pid that went backwards is a new process under a reused pid
        fresh = before is not None and p["jiffies"] >= before
        p["cpu"] = round(100 * (p["jiffies"] - before) / d_total, 1) if fresh and prev else 0.0
        del p["jiffies"]
        procs.append(p)

    SNAPSHOT.parent.mkdir(parents=True, exist_ok=True)
    SNAPSHOT.write_text(json.dumps({"boot": boot, "total": total, "idle": idle, "procs": now}))
    used, mem_total = meminfo()
    machine = round(100 * (1 - d_idle / d_total), 1) if prev else 0.0
    out({"ok": True, "cpu": max(0.0, machine), "memUsed": used, "memTotal": mem_total,
         "cores": os.cpu_count(), "procs": procs})


def cmd_kill(sig, pids):
    signum = {"TERM": signal.SIGTERM, "KILL": signal.SIGKILL}.get(sig)
    if signum is None:
        out({"ok": False, "error": f"bad signal: {sig}"})
    killed, errors = 0, []
    for pid in pids:
        try:
            os.kill(int(pid), signum)
            killed += 1
        except ProcessLookupError:
            killed += 1                                   # already gone: what was wanted
        except PermissionError:
            errors.append(f"{pid}: not yours (needs root)")
        except ValueError:
            errors.append(f"{pid}: not a pid")
    if errors:
        out({"ok": False, "error": "; ".join(errors[:3]) + ("…" if len(errors) > 3 else ""), "killed": killed})
    out({"ok": True, "killed": killed})


if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["list"]:
        cmd_list()
    elif len(args) >= 3 and args[0] == "kill":
        cmd_kill(args[1].upper(), args[2:])
    out({"ok": False, "error": "usage: tasks.py list | kill <TERM|KILL> <pid>…"})
