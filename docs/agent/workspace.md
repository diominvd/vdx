# AI workspace

Start here for AI instructions, skills and their installation. The checkout
is the editable source; client directories contain links. `~/AI.md` links here
after `python3 ai/manage.py link`. Relative document links below are resolved
from this file's real location in the checkout.

## Where to put things

| Content | Authority |
|---|---|
| Personal working preferences, independent of project | [ai/preferences.md](../../ai/preferences.md) |
| VDX repository rules | [AGENTS.md](../../AGENTS.md) |
| Shell-specific code rules | [shell/AGENTS.md](../../packages/quickshell/shell/AGENTS.md) |
| Architecture, design, recipes, verification | Existing topic under [docs/README.md](../README.md) |
| Reusable task workflow and its scripts/assets | `ai/skills/<name>/SKILL.md` |
| Which local client gets which source | [ai/links.json](../../ai/links.json) |
| Codex specialist roles and hooks | `.codex/agents/*.toml`, `.codex/hooks.json` |
| OpenCode commands and client settings | `packages/opencode/` |
| Credentials, sessions, caches, provider settings | Client-owned files under the home directory; never Git |
| Historical context and unfinished ideas | Client-local memory; verify before using |

`CLAUDE.md` files are compatibility entry points importing neighbouring
`AGENTS.md`, not separate rulebooks. OpenCode's `rules/TOKENS.md` links to the
same personal preferences used by Codex and Claude. Read relevant topic docs
on demand; do not load every skill/reference at startup.

## Own skills

| Skill | Purpose |
|---|---|
| [vdx-quickshell](../../ai/skills/vdx-quickshell/SKILL.md) | Shell engineering; routes to current repository docs, with a read-only context helper |
| [quickshell-promo](../../ai/skills/quickshell-promo/SKILL.md) | Video production workflow, capture scripts and Remotion template |

Edit these source directories. Do not copy a skill into several clients.
Add a new skill only for a reusable workflow; a repository fact belongs in
its topic document. Add its destinations to `ai/links.json` and its index row
here and in `docs/README.md`, then validate and link it.

Codex uses `~/.agents/skills`; Claude uses `~/.claude/skills`; ZCode's existing
local skill directory is `~/.zcode/skills`. Codex officially supports
[symlinked skill folders](https://learn.chatgpt.com/docs/build-skills).
This setup installs each owned skill once per client discovery directory;
the old Codex and ZCode `shell` entries are retired with a backup.

Third-party skills remain managed by their installer/plugin. In particular,
`~/.codex/skills/.system`, `~/.codex/plugins`, Claude's `skills/synced` and
ZCode's links to those resources are external sources, not editable copies
of this workspace. A synced skill named `shell` may still appear in Claude;
use `vdx-quickshell` for this repository. Change vendor subscriptions through
their owning client, not by editing a generated cache.

## Install, check, recover

Run from the checkout:

```sh
python3 ai/manage.py status
python3 ai/manage.py link
python3 ai/manage.py status
```

`status` is read-only and exits 1 for missing/outdated links. `link` is
idempotent and moves existing targets, including retired skills, into
`~/.local/state/vdx-ai/<timestamp>/files/` before creating links. It prints
the backup directory and records replacements in `manifest.json`.
It does not edit client model, permission, plugin or credential settings.

To undo a link operation:

```sh
python3 ai/manage.py restore ~/.local/state/vdx-ai/<timestamp>
```

Restore refuses to overwrite a target changed since linking. Restore backups
in reverse chronological order. Keep backups until the new sessions work.
Open a new client session to refresh instructions and skill discovery; this
script verifies filesystem wiring, not every client's running context.

The normal dotfiles installer still owns `packages/`; after changes there or
new shell instruction files run `./install.py link` and `./install.py verify`.
AI user-directory links are an explicit development setup, separate from
desktop components and startup. The dotfiles cleanup excludes checkout sources
and the AI-owned destinations declared in `ai/links.json`. There are no watchers
or background processes.

## Memory and upkeep

The local VDX Claude memory is under
`~/.claude/projects/-home-diominvd--dotfiles/memory/`. Its dated design notes,
old branch instructions and historical test results are not current policy.
Keep private history there; do not publish it wholesale into this repository.
The memory index should point at current repository instructions first and
label old records as historical. Keep stable facts in the topic docs and
personal preferences in `ai/preferences.md`; link to them from memory.

When a task teaches something durable, update its existing authority. Remove
or correct the superseded rule there. Do not add another instruction file,
skill, roadmap or handoff document for the same fact. Plans stay in chat.

After editing this system, check Markdown links, validate changed skills,
run `python3 -m unittest tests.test_ai_workspace` for linker changes, inspect
the diff, and check `python3 ai/manage.py status` after installation.
