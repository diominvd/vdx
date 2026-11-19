# Diagnosis by symptom and invariant

Use current source, existing fixtures, and bounded logs. Reproduce one failure
path before broadening the audit. Do not turn every fix into a whole-shell rewrite.

## Trace and isolate

1. Identify trigger, expected/observed result, involved surface, state and timing.
   Find its label/id/IPC function using scoped `rg -n` in `apps/`, `modules/`,
   `bar/`, `scripts/` and the relevant docs.
2. Follow UI → route → state owner → native API or exact backend command →
   parse/validation → published state → UI. Read direct consumers/callers.
3. Separate these possibilities: not installed/disabled; not instantiated;
   missing link; load/type error; IPC method not reloaded; backend never starts;
   backend exits with failure; malformed schema; stale reply; binding never
   notified; view lifecycle/focus/geometry error.
4. Use existing fake-backend fixtures or a minimal production-logic fixture.
   Test the failure and a successful retry. Record baseline failures separately.

## Symptom map

| Symptom | Focused evidence / likely boundary |
|---|---|
| Entire bar vanished | `qs list --all`, bounded `qs log -c shell`, shared import/type errors, newly unlinked file, supervisor log/retry state |
| File exists but type unavailable | Installed symlink/target, import root, singleton/container type, new-file linking, forbidden Behavior root |
| App never appears | `shell.qml` instantiation, app registry, lazy Loader activation, IPC target, installed rules; do not infer wiring from a README |
| IPC method missing after edit | Handler definitions need supervised restart; live reload is insufficient |
| Popup opens on wrong screen / twice | `PopupManager` ownership, focused monitor, disconnected bars, `popupTargets`; use `BarLayout.openModule` |
| Popup content disappears on style change | `PopupContentHost` ownership/restoration and source/host destruction; borrowed items are not owned clones |
| Endless loading/busy | Failed-to-start path, busy set before launch, completion paths, no stdout vs `onExited`, late callbacks |
| List empty or model type error | Array vs object parser, backend error object, missing fields, null fallback; preserve last valid state intentionally |
| Setting reverts or does not reset | Correct state owner, default/fallback mismatch, stale external write, missing reset key, app/module shared id |
| Search misses row | Literal label/hint, page/shared-block registry, stale generated index, duplicate destination handling |
| Works after second open only | Loader first-show initialization and dependency ready ordering |
| Slider jumps back / action lost | Query overwrites optimistic value, queue order, inappropriate latest-only mutation queue |
| Old result replaces new state | Request identity/generation and cancellation; completion belongs to old request |
| Idle CPU or RSS rises | Hidden UI still constructed, ungated loops/listeners/timers, repeated model rebuilding, child processes surviving teardown |
| Hyprland inaccessible from terminal | `hyprctl instances -j` vs inherited session signature; current session/socket availability |

## Asynchronous service review

For each action, write down who owns its request, busy state, reply, error and
children, and which events may interleave. Then check:

1. **Before start:** validate arguments and availability; apply the shared busy
   guard synchronously, snapshot immutable parameters, clear only this action's
   prior error/reply. Checking `Process.running` alone may miss a pre-start race.
2. **Start failure:** recover if the executable cannot launch; `onExited` alone
   may never cover it. Current Wi-Fi processes demonstrate `onStarted` plus
   `onRunningChanged` guards. Use the installed API and tested pattern.
3. **Reply:** stdout may be empty/malformed, a JSON error, or the wrong shape.
   `Reply.parse`/`parseList` only establish container shape. Validate required
   fields and success, retain useful prior data where appropriate, show errors.
4. **Completion ordering:** collectors and exit/running callbacks can differ in
   timing. Do not clear a newly set error or call success twice. Capture result
   data and reset old state before notifying listeners that may reenter.
5. **Overlap:** FIFO for mutations; latest pending query/slider value only where
   replaceable; shared guard for mutually exclusive connection/auth actions.
   Reject overlap or queue deliberately, not by accidental overwriting.
6. **Cancel/retry:** supersede old requests with an identity/generation, bound
   termination, ignore stale callbacks, preserve retryable input/output. A
   TERM-resistant child must not block the replacement or overwrite its reply.
7. **Failure feedback:** unwind all busy/loading flags, clear credential process
   environments and password strings before publishing idle, and allow retry.
   Never log passwords, tokens or raw credential-bearing commands.
8. **Lifecycle:** close/disable/destroy stops work no longer needed; references
   shared by another live consumer remain active. A backend `--listen` normally
   uses `scripts/listen.sh`; ensure watched children die with it.

Do not copy a parser null fallback and silently discard an error. Do not use
detached cleanup for state whose next request can race it. Review the existing
RootService, Files, Capture and Lock controllers for these ownership cases.

## Live session inspection and recovery

Use these only when the actual session is available and the task calls for it.

```sh
qs list --all
qs log -c shell | rg 'ERROR|WARN|Binding loop|ReferenceError|TypeError'
hyprctl instances -j
hyprctl clients -j
```

Filter/tail logs as needed; never assume an empty grep proves loading succeeded.
Inspect exit statuses and the relevant log context. Check actual IPC targets in
the registry/handlers before calling `qs -c shell ipc call <target> <method>`.

New installed files: run repo `./install.py link`, then `./install.py verify`.
For restart, inspect `qs list --all` and identify ONLY this shell's PID/config;
TERM that PID, confirm the old shell/supervisor ended, then start through the
correct Hyprland instance:

```sh
hyprctl eval 'hl.exec_cmd("~/.config/quickshell/shell/scripts/supervise.sh")'
```

If the inherited instance is stale, select the correct instance from
`hyprctl instances -j` and use `hyprctl -i <instance> eval …`. Do not kill all
Quickshell configs, use `pkill`, or start a bare competing shell. Supervisor
intentional TERM/INT/HUP/exit 0 stops; crash restarts; a recognized load error
waits for QML/JS edits (or periodic retry), and repeated crashes eventually stop.
Check current `supervise.sh` rather than treating every exit as a crash.

Screenshots use `grim -g 'X,Y WxH' out.png`; obtain geometry from compositor
state. Take them when visual verification is needed, not on each search.
Before synthetic keys inspect `hyprctl activewindow -j`. Keyboard-grabbing
overlays, real lock/PAM/root/device/network actions are not generic smoke tests.

## Performance diagnosis

Compare the same shell PID/config, same uptime window and same state before
and after: idle; one relevant popup/app open; close/reopen; repeated interaction.
Record CPU, RSS, startup/first-open cost and surviving child processes. Use
Shell Manager's resources view or bounded OS sampling; its CPU is a lifetime
average and RSS/VSZ are KiB. Memory growth across repeats matters more than one
RSS sample. Inspect consumers before reducing a poll interval or stopping a
listener: the bar, Island, schedules or an active recorder may still need it.
