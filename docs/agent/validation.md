# Agent validation

Use the repository checks that match the change; the detailed shell matrix and
manual runtime scenarios live in [shell/testing.md](../shell/testing.md).

| Command | Use |
|---|---|
| `./install.py check` | All repository check groups |
| `./install.py check syntax` | Language/config syntax, including QML syntax via `qmllint` |
| `./install.py check shell` | Shell registries, icons and settings index |
| `./install.py check tests` | Repository unittest suite |
| `ruff check` | Python lint |
| `python tests/check_shell_ui.py` | Offscreen QML behavior; not GPU/compositor rendering |

For live runtime checks, inspect `qs log -c shell` and use the documented IPC
and screenshot steps in `shell/testing.md`. The offscreen harness is available;
there is no automated visual comparison or browser-based QML harness.
