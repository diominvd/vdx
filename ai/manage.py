#!/usr/bin/env python3
"""Inspect or link owned AI resources; preserve replaced files in local backups."""

import argparse
from datetime import UTC, datetime
import json
from pathlib import Path
import shutil


ROOT = Path(__file__).resolve().parent.parent


def present(path):
    return path.exists() or path.is_symlink()


def matches(path, source):
    return path.is_symlink() and path.resolve() == source.resolve()


def resources(home):
    manifest = json.loads((ROOT / "ai/links.json").read_text())
    for target, source in manifest["links"].items():
        source = ROOT / source
        if not source.exists():
            raise ValueError(f"Missing source: {source}")
        yield home / target, source
    for target in manifest["retire"]:
        yield home / target, None


def status(home):
    pending = 0
    for target, source in resources(home):
        ok = matches(target, source) if source else not present(target)
        pending += not ok
        print(f"{'ok' if ok else 'pending'}: {target} -> {source or '(retired)'}")
    return int(bool(pending))


def link(home):
    changes = [(target, source) for target, source in resources(home)
               if not (matches(target, source) if source else not present(target))]
    if not changes:
        print("All AI links are current.")
        return
    stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%S.%fZ")
    backup = home / ".local/state/vdx-ai" / stamp
    backup.mkdir(parents=True, mode=0o700)
    records = []
    journal = backup / "manifest.json"
    for target, source in changes:
        relative = str(target.relative_to(home))
        existed = present(target)
        records.append({"target": relative, "source": str(source) if source else None,
                        "existed": existed})
        journal.write_text(json.dumps(records, indent=2) + "\n")
        if existed:
            saved = backup / "files" / relative
            saved.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(target), str(saved))
        if source:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.symlink_to(source, target_is_directory=source.is_dir())
        print(f"linked: {relative}" if source else f"archived: {relative}")
    print(f"Backup: {backup}")


def restore(home, backup):
    backup = backup.resolve()
    if backup.parent != (home / ".local/state/vdx-ai").resolve():
        raise ValueError("Backup must be a direct child of ~/.local/state/vdx-ai")
    records = json.loads((backup / "manifest.json").read_text())
    allowed = {str(target.relative_to(home)) for target, _ in resources(home)}
    for record in records:
        if record["target"] not in allowed:
            raise ValueError("Unknown target in backup manifest")
        target = home / record["target"]
        source = Path(record["source"]) if record["source"] else None
        if present(target) and not (source and matches(target, source)):
            raise ValueError(f"Changed since linking; refusing to replace: {target}")
        saved = backup / "files" / record["target"]
        if record["existed"] and not present(saved):
            raise ValueError(f"Backup file missing: {saved}")
    for record in reversed(records):
        target = home / record["target"]
        if target.is_symlink():
            target.unlink()
        if record["existed"]:
            shutil.move(str(backup / "files" / record["target"]), str(target))
    print(f"Restored {backup}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("status", "link", "restore"))
    parser.add_argument("backup", nargs="?", type=Path)
    parser.add_argument("--home", type=Path, default=Path.home(),
                        help="Target home directory (also useful for isolated checks)")
    args = parser.parse_args()
    home = args.home.expanduser().resolve()
    try:
        if args.command == "status":
            return status(home)
        if args.command == "link":
            link(home)
        elif args.backup:
            restore(home, args.backup)
        else:
            parser.error("restore requires a backup directory")
    except (OSError, ValueError) as error:
        parser.exit(1, f"{error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
