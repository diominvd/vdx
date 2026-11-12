# Agent instructions

- Read the existing implementation and reuse its components and services.
  Keep one owner for state, preserve public APIs, and limit changes to the
  requested modules.
- For QML, verify properties, signals, imports and Qt/Quickshell APIs against
  working examples. Avoid binding loops and respect component lifetimes; check
  runtime logs for errors.
- Use VDX theme tokens and icon conventions. Handle narrow layouts, overflow,
  loading, empty and error states. Claim visual correctness only after viewing
  the UI in the target runtime.
- Every feature must account for CPU, memory and startup cost. Create hidden UI
  only when needed; scope timers, processes and listeners to active work. Check
  expensive paths rather than adding permanent background work by default.
- Workflow: inspect, briefly plan complex changes, implement the smallest
  complete fix, run focused checks, review the diff, and report results.
