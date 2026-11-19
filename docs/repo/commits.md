# Commits

`scope: what changed` — English, lowercase, imperative, no full stop, ≤ ~72
characters; a body says why. Scopes: a package name (`hypr`, `quickshell`, …),
`themes`, `scripts`, `system`, `installer`, `docs`, `repo`.

- One commit is one whole change: a feature, a fix, a refactor, a cleanup. Not
  a single line or a small tweak split off from the change it belongs to.
- No WIP, fixup, "misc" or "tidy" subjects. A half-done change waits until it
  is finished.
- The body says why in a few short lines when the subject does not.
- Co-authors: one `Co-Authored-By:` trailer per model that helped write the
  change, for example `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  Agents add their own model's trailer.
- Nothing broken: `./install.py check`; `qs log -c shell` without errors for
  the shell. Check `git diff --cached` for secrets.
- Someone else's uncommitted changes are not committed or reverted without
  asking; commit your own hunks only.

```
scope: what changed

Why, in a few short lines when the subject does not say it.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
```

## Before a commit

Every commit answers three checks first.

- Security: no tokens, keys or personal data in the diff; `/etc` only through
  `system/`, no sudo run by an agent; hardware values from `.machine.toml`,
  never the repo; no untrusted input in shell, QML or Lua exec strings; no
  downloaded code or scripts without the owner's say-so.
- Tests: `ruff check` (config `ruff.toml`) is clean for the Python, `shellcheck`
  for the shell scripts, a failure fixed in the same commit; an installer or
  behaviour change adds or updates a test in `tests/`;
  when none is needed and that is not obvious, one line in the body says why.
  A change to what `setup` does also runs `tests/fresh-machine.sh`. Tests the
  change breaks are fixed in the same commit, not skipped.
- Docs: a doc the change makes wrong is fixed in the same commit (the
  installer module's docstring, its topic file in `docs/`, the README, the
  component's README, `packages/quickshell/shell/AGENTS.md` for shell rules).
  Find them by grepping the docs for the names the change touches (function,
  key, file, option). No new docs unless asked.
- Agents tell the user the three answers, one line each (security / tests /
  docs), then commit.

## Branches

`main` is the default. Published history is not rewritten except by the
owner's decision, with a backup (`git bundle create … --all`) first. No hooks:
commands that check out old commits run with `git -c core.hooksPath=/dev/null`
and end with `./install.py link`.

## Before a push

```
./install.py check
./install.py doctor
./install.py system status
git status
git log --oneline -5
```
