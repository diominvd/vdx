---
name: vdx-quickshell
description: Develop, debug and review the VDX Quickshell desktop shell, including its QML UI, services, settings and backends. Use for «мой шелл», «шелл VDX» and Quickshell work in diominvd/vdx; not generic shell scripting or other Quickshell configs.
---

# VDX Quickshell

Locate the checkout by `install.py`, `components.toml` and
`packages/quickshell/shell/shell.qml`; do not assume the current directory.
Read its root and shell `AGENTS.md`, inspect the working diff, then select
only the documents relevant to the task from the table below.

All paths below are relative to that checkout. The repository documents own
the rules; this skill routes to them. Historical memories do not establish
current behaviour or authorize switching branches.

| Task | Read |
|---|---|
| UI, wording, controls, motion | `docs/shell/design.md` |
| Settings, module, app or service changes | `docs/shell/writing-code.md`; nearest working implementation |
| Bar, Island, popup hosting, IPC, state ownership | `docs/shell/architecture.md` |
| Crash, stale state, async race, device failure, performance | `docs/shell/debugging.md` |
| Companion | `docs/shell/companion.md`; verify current production wiring |
| Verification | `docs/shell/testing.md`, `docs/agent/validation.md` |
| Theme or component integration | `docs/repo/themes.md`, `docs/repo/components.md` |
| Requested commit | `docs/repo/commits.md` |

For a bounded path and test inventory, optionally run:

```sh
python3 <skill-dir>/scripts/context.py --root <checkout> --area runtime
```

Use `--help` for the available areas. The helper reads paths and Git status;
it does not execute project code or prove that a mapped feature is wired in.

Trace the affected trigger → route → state owner → backend/native API → reply
→ view. Verify APIs against installed working examples. Fix the responsible
owner, then run the checks appropriate to that path. For visible changes,
inspect the target runtime before claiming visual correctness.
