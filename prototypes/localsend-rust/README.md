# LocalSend backend prototype

This standalone process validates the official LocalSend Rust core as a VDX
backend. JSONL contract v1 is an internal integration contract, not a public VDX
API. The core is unmodified source from LocalSend v1.18.2, commit
`af0416be50770a97760f7070684bc667b759a15c`, in `vendor/localsend-core/`.
Only the `discovery`, `http`, and `multicast` core features are enabled; WebRTC
is excluded. Keep the upstream `LICENSE` with the vendored source.

## Build and run

```sh
cargo build --release --locked --manifest-path prototypes/localsend-rust/Cargo.toml
mkdir -p /tmp/localsend-downloads
prototypes/localsend-rust/target/release/vdx-localsend-prototype \
  --download-dir /tmp/localsend-downloads
```

The optional VDX component uses the checked-in x86_64 binary at
`packages/localsend/vdx-localsend`. Maintainers rebuild that artifact from this
locked, vendored source with the command above and replace the tracked file;
end-user setup does not install Cargo or download/execute a binary. The
`localsend` component is off by default and links that directory to
`~/.config/localsend/`.

The helper listens on LocalSend TCP/UDP port 53317. Its TLS identity is stored
under `$XDG_STATE_HOME/vdx-localsend-prototype` or
`~/.local/state/vdx-localsend-prototype`; `--state-dir` overrides it. The
default receive directory is `~/Downloads/LocalSend-Prototype`; pass
`--download-dir` to choose another. At startup, only stale regular files with
the helper's UUID `.part` naming pattern are removed.

## JSONL v1

One JSON object per line on stdin; one JSON object per line on stdout. Every
command requires a unique string `id` (1–128 bytes). The helper remembers IDs
for its lifetime, rejects duplicates, and accepts at most 65,536 commands per
process to keep memory bounded. Commands are strict:
unknown fields and unknown commands return `invalid_command`. Input is capped at
64 KiB per line; malformed or oversized lines produce errors and do not stop the
process. Diagnostics go to stderr. Every event has `v: 1` and an `event` name.

### Commands

Discover devices and read the current discovery store:

```json
{"cmd":"discover","id":"cmd-001"}
{"cmd":"devices","id":"cmd-002"}
```

Send one or more local files to a device identified by its discovered
fingerprint. Up to 100 paths are allowed in one batch; the JSONL line limit also
applies.

```json
{"cmd":"send","id":"cmd-003","fingerprint":"<device fingerprint>","paths":["/home/me/a.txt","/home/me/b.png"]}
```

Accept the selected files from an incoming session, or reject the request. The
selection must be a nonempty subset of offered `fileIds`.

```json
{"cmd":"accept","id":"cmd-004","sessionId":"<incoming session>","fileIds":["<file id 1>","<file id 2>"]}
{"cmd":"reject","id":"cmd-005","sessionId":"<incoming session>"}
```

Cancel an active transfer, inspect backend state, or request shutdown. Cancel
acts on the whole LocalSend session; it does not promise per-file protocol
cancellation.

```json
{"cmd":"cancel","id":"cmd-006","transferId":"<transfer id>"}
{"cmd":"status","id":"cmd-007"}
{"cmd":"shutdown","id":"cmd-008","force":false,"timeoutMs":30000}
```

`shutdown` defaults to graceful mode with a 30-second drain timeout. On timeout
it cancels transfers and allows up to five more seconds for cleanup. Set
`force:true` to cancel immediately. Closing stdin or receiving SIGTERM/SIGINT
uses forced cancellation and cleanup. Active receives are written to private
`.part` files; task cancellation removes them, and an unclean process death is
recovered at the next startup.

### Command results and events

Successful commands receive a `command_result`. The send result includes the
new `transferId`; accepting includes both transfer and session IDs.

```json
{"v":1,"event":"command_result","id":"cmd-003","ok":true,"transferId":"<transfer id>"}
{"v":1,"event":"command_result","id":"cmd-004","ok":true,"transferId":"<transfer id>","sessionId":"<session id>"}
```

Errors have a machine-readable `code` and human-readable `message`. Invalid
JSON has `id:null`; otherwise the supplied command ID is echoed when available.

```json
{"v":1,"event":"error","id":"cmd-009","code":"device_not_found","message":"device fingerprint is not in the discovery store"}
```

Discovery emits changed devices by fingerprint, a final snapshot, and a
completion event. `devices` returns the current snapshot in its command result.

```json
{"v":1,"event":"device","id":null,"device":{"fingerprint":"<fingerprint>","alias":"Phone","version":"2.2","deviceModel":"Android","deviceType":"mobile","channel":{"host":"192.168.1.40","port":53317,"protocol":"https"}}}
{"v":1,"event":"discovery_complete","id":"cmd-001","devices":[]}
```

Incoming requests are never auto-accepted. They expire and are declined after
60 seconds. `incoming` includes all offered files and identifiers; selection is
explicit in the `accept` command. Up to 100 files may be selected.

```json
{"v":1,"event":"incoming","id":null,"sessionId":"<session id>","transferId":"<transfer id>","alias":"Phone","fingerprint":"<fingerprint>","files":[{"fileId":"<file id>","fileName":"photo.jpg","size":12345,"fileType":"image/jpeg"}],"confirmTimeoutSeconds":60}
```

Transfers emit `transfer_started`, coalesced `transfer_progress`, per-file
`file_completed`, and exactly one `transfer_finished`. Terminal `state` is
`completed`, `failed`, or `cancelled`; a failed multi-file batch can contain
both successful and failed file results. Progress fields describe both the
current file and session byte totals. A terminal result is not dropped when the
progress queue is full.

```json
{"v":1,"event":"transfer_started","id":"cmd-003","transferId":"<transfer id>","direction":"send","totalFiles":2,"state":"active"}
{"v":1,"event":"transfer_progress","id":"cmd-003","transferId":"<transfer id>","fileId":"<file id>","fileName":"a.txt","fileBytes":512,"fileTotal":1024,"transferredBytes":512,"totalBytes":2048}
{"v":1,"event":"file_completed","id":"cmd-003","transferId":"<transfer id>","file":{"fileId":"<file id>","fileName":"a.txt","state":"completed","bytes":1024}}
{"v":1,"event":"transfer_finished","id":"cmd-003","transferId":"<transfer id>","state":"completed","files":[],"error":null}
```

Other events: `ready`, `warning`, `peer_registered`, `incoming_rejected`,
`incoming_expired`, `remote_cancel`, `shutdown_timeout`, and `stopped`.

## Safety and limits

- HTTPS peers are verified against the advertised LocalSend certificate
  fingerprint; incoming TLS client identity must match its advertised
  fingerprint. TLS verification is not disabled.
- Source files are streamed from paths and SHA-256 is included in LocalSend
  metadata. Incoming files are size/hash checked before commit.
- Files are first created with mode 0600 as unique `.part` files. Finalization
  uses an atomic same-directory hard link, which fails rather than overwriting;
  collisions receive a numbered filename. Unsafe basenames are rejected. On
  Linux, writes are anchored through the open download-directory descriptor so
  renaming the configured directory cannot redirect an in-flight receive.
- At most two active transfer sessions are accepted. Files within an outgoing
  batch are streamed sequentially; an incoming session processes at most two
  file streams at once, with bounded per-file buffers.
- A cancel command cancels the whole transfer session. The official core
  exposes session cancellation, not independent per-file cancellation through
  this helper.
- The shell integration lives in `packages/quickshell/shell/apps/localsend/`.
  Open it through the launcher or `qs -c shell ipc call localsend open`.
  Apps › LocalSend controls background receiving (off by default). The shell
  owns the helper; no separate daemon or systemd service is installed.
- A backend exit fails both queued and sent requests, clears incoming offers
  and marks active transfers failed. File operations are never replayed after
  a restart. The helper stops when no window, transfer or request needs it.
