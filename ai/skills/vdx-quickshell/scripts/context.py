#!/usr/bin/env python3
"""Print bounded, read-only VDX navigation context; never run project code."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess


SHELL = "packages/quickshell/shell"
AREAS = {
    "bar": (["bar", "components/PopupManager.qml", "components/PopupContentHost.qml"],
            ["shell", "shell_lifecycle"], ["docs/shell/architecture.md"]),
    "ui": (["kit", "config/Theme.qml", "config/Motion.qml", "apps/shellmanager"],
           ["settings_index"], ["docs/shell/design.md", "docs/shell/writing-code.md"]),
    "settings": (["config/ShellState.qml", "config/ShellSettings.qml", "config/ModuleSettings.qml",
                  "scripts/settings_migrate.py", "scripts/settings_index.py", "scripts/settings_io.py"],
                 ["settings_index", "settings_migrate", "settings_io"], ["docs/shell/architecture.md"]),
    "devices": (["modules/wifi", "modules/bluetooth", "modules/audio", "modules/battery",
                 "modules/brightness", "apps/display"],
                ["wifi", "bluetooth", "audio", "battery", "brightness", "display", "device_services"],
                ["docs/shell/architecture.md"]),
    "files": (["apps/files", "scripts/files.py", "scripts/files_portal.py"],
              ["files", "file_picker", "xdg_portal"], ["docs/shell/architecture.md"]),
    "capture": (["apps/capture", "modules/capture", "scripts/capture.py"],
                ["capture"], ["docs/shell/architecture.md"]),
    "lock": (["apps/lock", "apps/auth", "scripts/password.py"],
             ["lock", "root_service", "password"], ["docs/shell/architecture.md"]),
    "music": (["apps/music", "modules/player", "modules/mpd", "modules/yandex", "modules/radio",
               "scripts/music.sh", "scripts/music_files.py"],
              ["music", "list_replies"], ["docs/shell/architecture.md"]),
    "apps": (["apps/apps.json", "shell.qml", "apps"],
             ["packages", "backup", "clipboard"], ["docs/shell/writing-code.md"]),
    "companion": (["apps/companion", "apps/shellmanager/KimmyPage.qml", "shell.qml",
                   "apps/shellmanager/ShellManager.qml"],
                  ["companion"], ["docs/shell/companion.md"]),
    "runtime": (["shell.qml", "scripts/supervise.sh", "scripts/listen.sh", "scripts/backend.py",
                 "kit/reply.js"],
                ["supervise", "listen", "shell_lifecycle", "list_replies"],
                ["docs/shell/architecture.md", "docs/shell/testing.md"]),
    "themes": (["config/Theme.qml", "apps/shellmanager/ThemeService.qml"],
               [], ["docs/repo/themes.md", "themes/gruvbox/README.md", "docs/repo/components.md"]),
}


def git(root: Path, *args: str) -> str:
    try:
        result = subprocess.run(
            ["git", "--no-optional-locks", "-C", str(root), *args],
            capture_output=True, text=True, errors="replace", timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return "unavailable"
    return result.stdout.strip() if result.returncode == 0 else "unavailable"


def find_root(start: Path) -> Path:
    current = start.expanduser().resolve()
    for candidate in (current, *current.parents):
        if all((candidate / name).is_file() for name in
               (f"{SHELL}/shell.qml", "components.toml", "install.py")):
            return candidate
    raise ValueError("VDX root not found; use --root /path/to/vdx")


def context(root: Path, area: str) -> dict:
    paths, stems, docs = AREAS[area]
    selected = [f"{SHELL}/{path}" for path in paths]
    if area == "themes":
        selected.extend(["themes/gruvbox/quickshell/shell/config/Colors.qml",
                         "themes/mktheme.py", "components.toml"])
    docs = ["AGENTS.md", f"{SHELL}/AGENTS.md", "docs/README.md", *docs]
    candidates = sorted(path.name for path in (root / "tests").glob("test_*.py")
                        if any(stem in path.stem.removeprefix("test_") for stem in stems))
    status = git(root, "status", "--short").splitlines()
    tools = {name: shutil.which(name) for name in
             ("python3", "qs", "qmllint", "qmltestrunner", "ruff", "shellcheck", "hyprctl")}
    qt6 = {name: (str(path) if path.is_file() else None) for name in ("qmllint", "qmltestrunner")
           for path in [Path("/usr/lib/qt6/bin") / name]}
    return {
        "root": str(root), "area": area,
        "head": git(root, "rev-parse", "HEAD"),
        "branch": git(root, "branch", "--show-current"),
        "status_first_30": status[:30], "status_more": max(0, len(status) - 30),
        "read_once": [path for path in docs if (root / path).is_file()],
        "inspect": [path for path in selected if (root / path).exists()],
        "missing_map_paths": [path for path in [*selected, *docs] if not (root / path).exists()],
        "test_candidates": candidates,
        "ui_harness": "tests/check_shell_ui.py" if (root / "tests/check_shell_ui.py").is_file() else None,
        "tools_on_path": tools, "qt6_known_paths": qt6,
        "notes": ["Tool paths do not prove executables work; check their version/help.",
                  "Read applicable nested AGENTS.md instructions before editing.",
                  "Inspect current source; this helper neither runs checks nor changes state."],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="Checkout or directory within it")
    parser.add_argument("--area", choices=sorted(AREAS), default="runtime")
    args = parser.parse_args()
    try:
        root = find_root(args.root)
    except ValueError as error:
        parser.error(str(error))
    print(json.dumps(context(root, args.area), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
