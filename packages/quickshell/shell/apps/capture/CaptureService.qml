pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.components
import qs.config
import qs.modules.battery

// Screen capture: the state of the overlay (CaptureOverlay) and the recording
// (CaptureRecording). Super+Shift+S calls `qs -c shell ipc call capture open`:
// the screens freeze at once, as they are (open popups, the island, menus), and
// the choices are the overlay's toolbar. While recording the same call stops it.
// The bar module is a button for the same; it shows the recording.
//
// Opening is staged so nothing flickers: `armed` creates the overlays, which
// grab a still of every screen with the pointer while still transparent. A
// Hyprland screen copy is the last frame it drew, software pointer included,
// so the pointer is hidden and every overlay redraws itself each frame, so
// Hyprland keeps recomposing. Hyprland applies the hiding late (next key
// event or a 500 ms tick), so each overlay checks its plain still where the
// pointer is and retakes it until the pointer is gone. When all are in, the
// pointer is back, `shown` makes the overlays opaque and, a frame later, open
// bar popups hide behind their own picture (PopupManager.frozen). Closing runs
// the other way round.
Singleton {
  id: root

  // ---- overlay ----
  property bool armed: false
  property bool shown: false
  property bool closing: false        // the dim fades out, then the overlay goes
  property int cursorStills: 0
  property int plainStills: 0
  property bool pointerHidden: false
  property bool redraw: false         // overlays redraw until their plain stills are in
  property bool plainCapture: false   // overlays take (and check) their plain stills
  // Hyprland windows on the shown workspaces, layout coordinates, topmost first:
  // [{x, y, width, height}]
  property var windows: []
  property point pointerAt: Qt.point(-1, -1)   // layout coordinates at open
  // the shell's own surfaces (the island, child bars, an open popup) as targets of
  // Window: each bar adds its own on targetsAsked, topmost first, layout coordinates
  property var shellTargets: []
  signal targetsAsked()
  function addTargets(rects) { shellTargets = shellTargets.concat(rects); }
  // Screen on the focused monitor, straight away: no toolbar, no dim (`capture shot screen`)
  property bool instant: false

  // ---- this capture ----
  readonly property bool cursor: settings.cursor      // the pointer in the shot / recording

  // ---- the toolbar's choices ----
  // the last picked, kept across restarts (capture.json): the next capture starts with them
  readonly property string mode: settings.mode          // region | window | screen
  readonly property string kind: settings.kind          // shot | record
  readonly property string audio: settings.audio        // off | system | mic
  // ---- options (modules.json: Shell Manager › Apps › Capture) ----
  readonly property int fps: ModuleSettings.get("capture", "fps", 60)
  readonly property string quality: ModuleSettings.get("capture", "quality", "medium")    // low | medium | high
  // auto | igpu | gpu | cpu. Auto keeps the discrete GPU asleep on battery:
  // the recorder then sees only Mesa (the integrated GPU) and never loads NVIDIA.
  readonly property string encoder: ModuleSettings.get("capture", "encoder", "auto")
  readonly property string encoderInUse: encoder !== "auto" ? encoder : BatteryService.plugged ? "gpu" : "igpu"
  // auto | h264 | hevc. Auto is HEVC on the GPU and H.264 on the CPU (x264 has no HEVC here).
  // H.264 on the GPU tints the faint greys of a flat wallpaper; HEVC keeps them.
  readonly property string codec: ModuleSettings.get("capture", "codec", "auto")
  readonly property string codecInUse: encoderInUse === "cpu" ? "h264" : codec !== "auto" ? codec : "hevc"
  // the problems the codec and quality can cause here, most important first:
  // {title, text, warn}; Shell Manager lists them all, the toolbar shows codecNote
  readonly property var codecIssues: {
    const issues = [];
    if (codec === "hevc" && encoderInUse === "cpu")
      issues.push({ title: "CPU has no HEVC", text: "The CPU encoder writes H.264, so the choice does not apply.", warn: false });
    if (codecInUse === "h264" && (encoderInUse !== "cpu" || quality !== "high"))
      issues.push({ title: "Flat greys can tint", text: "Plain backgrounds may show coloured blocks. HEVC avoids it.", warn: true });
    if (codecInUse === "hevc" && quality === "low")
      issues.push({ title: "Low quality tints", text: "Even HEVC shows coloured blocks at Low. Use Medium or High.", warn: true });
    if (codecInUse === "hevc")
      issues.push({ title: "Not every player plays HEVC", text: "Firefox and some older players refuse it. H.264 plays anywhere.", warn: false });
    return issues;
  }
  // the first warning, else the first note; null when there is nothing to say
  readonly property var codecNote: codecIssues.find(i => i.warn) ?? codecIssues[0] ?? null

  // ---- delay ----
  // seconds; 0: no Delay button in the toolbar. The button lets the screen go,
  // counts down (CaptureCountdown) and freezes it again
  readonly property int delay: ModuleSettings.get("capture", "delay", 0)
  property int countdown: 0             // seconds left; 0: none running

  // ---- recording ----
  readonly property bool recording: recordSession.recording
  property string recordOutcome: ""              // briefly stays on the bar after a recording ends
  property string recordOutcomeText: ""
  readonly property string recordFile: recordSession.request?.file ?? ""
  readonly property real recordStarted: recordSession.started
  readonly property rect recordRect: recordSession.request?.rect ?? Qt.rect(0, 0, 0, 0)
  readonly property int recordFps: recordSession.request?.fps ?? fps
  readonly property string recordAudio: recordSession.request?.audio ?? audio
  readonly property int elapsed: recordSession.elapsed
  readonly property bool paused: recordSession.paused
  // "05:42", for the faces that show it
  readonly property string elapsedText: String(Math.floor(elapsed / 60)).padStart(2, "0") + ":" + String(elapsed % 60).padStart(2, "0")
  // the screens whose bar shows the Capture module (they show the recording;
  // the others get CaptureRecording's panel): asked when a recording starts
  property var faceScreens: []
  signal facesAsked()
  // gpu-screen-recorder presets behind the options' Low / Medium / High
  readonly property var presets: ({ low: "medium", medium: "high", high: "very_high" })
  readonly property string mesaOnly: "/usr/share/glvnd/egl_vendor.d/50_mesa.json"

  // ---- output ----
  // folders from Shell Manager › Apps › Capture; empty: the defaults
  readonly property string shotDir: ModuleSettings.get("capture", "shotDir", "") || Quickshell.env("HOME") + "/Pictures/Screenshots"
  // after a shot: folder | ask (a Save as window) | clipboard (nothing on disk);
  // after a recording: folder | ask. Shell Manager › Apps › Capture.
  readonly property string shotTarget: ModuleSettings.get("capture", "shotTarget", "folder")
  readonly property string videoTarget: ModuleSettings.get("capture", "videoTarget", "folder")
  readonly property bool notifyShot: ModuleSettings.get("capture", "notifyShot", true)     // off: no toast; errors still show
  readonly property bool notifyRecord: ModuleSettings.get("capture", "notifyRecord", true)
  readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell-capture"
  readonly property string saveScript: Paths.scriptsDir + "/capture.py"
  property var trashQueue: []
  property var trashCurrent: []
  property bool trashBusy: false
  property string trashError: ""
  property var trashLastResult: ({ ok: true, moved: [], failed: [] })
  readonly property bool trashPending: trashBusy || trashQueue.length > 0
  signal trashFinished(var result)
  // a capture waiting for its Save as answer: {kind: shot | video, tmp, path}
  readonly property var pending: saveSession.pending
  readonly property bool saveBusy: saveSession.busy
  readonly property string saveError: saveSession.error
  readonly property bool replaceSave: saveSession.replacing
  readonly property bool recordAsk: recordSession.request?.ask ?? false
  readonly property string videoDir: ModuleSettings.get("capture", "videoDir", "") || Quickshell.env("HOME") + "/Videos/Recordings"

  function stamp() { return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss-zzz"); }

  // Super+Shift+S and the bar module: stops a recording, cancels a countdown,
  // closes an open overlay, else freezes the screens and shows the toolbar
  function open() {
    if (recordSession.busy) { stopRecording(); return; }
    if (countdown > 0 || countdownEnd.running) { cancelDelay(); return; }
    if (armed) { close(); return; }
    startSelection();
  }

  // `capture shot <region|window|screen>`: screen is taken on the focused
  // monitor at once; region and window open the overlay on that choice
  function shot(target) {
    if (recordSession.busy || clipboardSession.busy || pending || armed || countdown > 0 || countdownEnd.running) return;
    if (!["region", "window", "screen"].includes(target)) return;
    if (target === "screen") { instant = true; startSelection(); return; }
    setMode(target);
    setKind("shot");
    startSelection();
  }

  // freezes the screens: the stills, then the overlay with its toolbar
  function startSelection() {
    if (recordSession.busy || clipboardSession.busy || pending || armed) return;
    closing = false;
    cursorStills = 0;
    plainStills = 0;
    redraw = false;
    plainCapture = false;
    run(["sh", "-c", 'mkdir -p "$1" "$2"; find "$2" -name "Screenshot_*" -mmin +60 -delete', "sh", shotDir, cacheDir]);
    pointerAt = Qt.point(-1, -1);
    shellTargets = [];
    targetsAsked();
    windowsProc.running = true;
    PopupManager.holding = true;
    armed = true;
  }

  // the toolbar's Delay: the overlay goes, the countdown runs, the screens freeze again
  function startDelay() {
    if (delay <= 0 || !armed || closing) return;
    close();
    countdown = delay;
    countdownTimer.restart();
  }

  function cancelDelay() {
    countdown = 0;
    countdownTimer.stop();
    countdownEnd.stop();
  }

  function setPointerHidden(hidden) {
    pointerHidden = hidden;
    const command = ["hyprctl", "eval", "hl.config({cursor = {invisible = " + hidden + "}})"];
    if (hidden) {
      hideProc.command = command;
      hideProc.running = true;
    } else {
      run(command);
    }
  }

  // Every screen has its still with the pointer: hide it (hideProc goes on).
  function cursorStillReady() {
    cursorStills += 1;
    if (cursorStills < Quickshell.screens.length || !armed || closing) return;
    setPointerHidden(true);
  }

  // Every screen has its plain still: the pointer is back, show the overlays.
  function plainStillReady() {
    plainStills += 1;
    if (plainStills < Quickshell.screens.length || !armed || closing || shown) return;
    setPointerHidden(false);
    shown = true;
    freezeTimer.restart();
  }

  function close() {
    if (!armed || closing) return;
    instant = false;
    closing = true;
    freezeTimer.stop();
    if (pointerHidden) setPointerHidden(false);
    PopupManager.frozen = false;
    closeTimer.restart();
  }

  function setMode(value) { settings.mode = value; }
  function setKind(value) { settings.kind = value; }
  function setAudio(value) { settings.audio = value; }
  function setCursor(value) { settings.cursor = value; }
  function cycleKind() { setKind(kind === "shot" ? "record" : "shot"); }

  // where a new shot is written first: its folder, or the cache until Save as / never
  function shotPath() {
    return (shotTarget === "folder" ? shotDir : cacheDir) + "/Screenshot_" + stamp() + ".png";
  }

  // A cropped still from an overlay, already written to `path`; it always
  // goes to the clipboard, then to wherever shotTarget says.
  function shotSaved(path) {
    close();
    clipboardSession.copy({ file: path, target: shotTarget, notify: notifyShot,
      path: shotDir + "/" + path.split("/").pop() });
  }

  CaptureClipboard {
    id: clipboardSession
    script: root.saveScript
    onCompleted: (capture, result) => {
      if (!result.ok) root.fail("Screenshot was not copied", (result.error || "Clipboard failed") + "\n" + capture.file);
      if (capture.target === "ask") {
        saveSession.offer({ kind: "shot", tmp: capture.file, path: capture.path, notify: capture.notify,
          copyFailed: !result.ok, error: result.ok ? "" : "Clipboard failed. Save the screenshot to a file." });
      } else if (result.ok && capture.notify) {
        root.run(["notify-send", "-a", "Capture", "-i", capture.file, "Screenshot copied",
          capture.target === "folder" ? capture.file : "clipboard only"]);
      }
    }
  }

  // Save as answered: move the capture there (a leading ~ is the home folder)
  function confirmSave(path) { saveSession.confirm(path); }
  function editSave() { saveSession.edited(); }

  // Save as dismissed: a shot stays on the clipboard only; a recording is
  // never thrown away — it goes to its default folder
  function dismissSave() { saveSession.dismiss(); }

  CaptureSaver {
    id: saveSession
    script: root.saveScript
    onSaved: (capture, path) => {
      if (capture.notify) root.run(["notify-send", "-a", "Capture",
        capture.kind === "shot" ? "Screenshot saved" : "Recording saved", path]);
    }
  }

  // rect in layout coordinates (logical pixels across all monitors);
  // gpu-screen-recorder scales them to the output itself
  function startRecording(rect) {
    if (recordSession.busy || clipboardSession.busy || pending || closing || rect.width < 1 || rect.height < 1) return;
    close();
    const ask = videoTarget === "ask";
    const folder = ask ? cacheDir : videoDir;
    const file = folder + "/Recording_" + stamp() + ".mp4";
    const args = ["gpu-screen-recorder", "-w", "region",
                  "-region", Math.round(rect.width) + "x" + Math.round(rect.height) + "+" + Math.round(rect.x) + "+" + Math.round(rect.y),
                  "-f", String(fps), "-q", presets[quality] ?? "high", "-cursor", cursor ? "yes" : "no",
                  "-ac", "aac", "-fallback-cpu-encoding", "yes", "-o", file];
    if (audio === "system") args.push("-a", "default_output");
    else if (audio === "mic") args.push("-a", "default_input");
    if (codecInUse === "hevc") args.push("-k", "hevc");
    if (encoderInUse === "cpu") args.push("-encoder", "cpu");
    if (encoderInUse === "igpu") args.unshift("env", "__EGL_VENDOR_LIBRARY_FILENAMES=" + mesaOnly);
    // start after the overlay is gone, so it is not in the first frames
    recordSession.start({ file: file, rect: rect, ask: ask, notify: notifyRecord, fps: fps, audio: audio,
      path: videoDir + "/" + file.split("/").pop(),
      command: ["sh", "-c", 'mkdir -p "$1" && shift && exec "$@"', "sh", folder].concat(args) });
  }

  function stopRecording() { recordSession.stop(); }
  function togglePause() { recordSession.togglePause(); }

  function recordingDone(ok, text) {
    recordOutcome = ok ? "ok" : "error";
    recordOutcomeText = text;
    recordOutcomeTimer.restart();
  }
  Timer {
    id: recordOutcomeTimer
    interval: 6000
    onTriggered: { root.recordOutcome = ""; root.recordOutcomeText = ""; }
  }

  function run(command) { Quickshell.execDetached(command); }

  // the library's window (CaptureWindow)
  signal libraryRequested(bool toggle)
  function openLibrary() { libraryRequested(false); }
  function fail(title, message) {
    run(["notify-send", "-a", "Capture", "-u", "critical", title, message]);
  }

  // Trash operations outlive the library view, so the service owns their FIFO.
  function moveToTrash(paths) {
    const unique = Array.isArray(paths) ? [...new Set(paths.filter(p => typeof p === "string" && p !== ""))] : [];
    if (unique.length === 0) return false;
    trashError = "";
    trashQueue = trashQueue.concat([unique]);
    startTrash();
    return true;
  }

  function startTrash() {
    if (trashBusy || trashQueue.length === 0) return;
    trashCurrent = trashQueue[0];
    trashQueue = trashQueue.slice(1);
    trashBusy = true;
    trashProc.started = false;
    trashProc.exitCode = -1;
    trashProc.replyText = "";
    trashProc.command = ["python3", saveScript, "trash"].concat(trashCurrent);
    trashProc.running = true;
  }

  function finishTrash(text, code) {
    let result;
    try {
      result = JSON.parse(text);
      if (!result || typeof result.ok !== "boolean" || !Array.isArray(result.moved) || !Array.isArray(result.failed)
          || result.moved.some(p => typeof p !== "string")
          || result.failed.some(f => !f || typeof f.path !== "string" || typeof f.error !== "string"))
        throw new Error("malformed trash reply");
      const requested = trashCurrent;
      const seen = new Set();
      const paths = result.moved.concat(result.failed.map(f => f.path));
      if (result.ok !== (result.failed.length === 0)
          || paths.length !== requested.length
          || paths.some(path => !requested.includes(path) || seen.has(path) || !seen.add(path)))
        throw new Error("trash reply does not match request");
    } catch (e) {
      result = { ok: false, moved: [], failed: trashCurrent.map(path => ({ path, error: "invalid trash reply" })) };
    }
    if (code !== 0 && result.ok === true) {
      result = { ok: false, moved: [], failed: trashCurrent.map(path => ({ path, error: "trash command failed" })) };
    }
    result.ok = result.failed.length === 0 && result.ok === true;
    trashLastResult = result;
    trashError = result.failed.length
      ? result.failed.map(f => f.path.split("/").pop() + ": " + f.error).join("; ")
      : result.ok ? "" : "Capture trash operation failed";
    trashFinished(result);
    trashCurrent = [];
    trashBusy = false;
    startTrash();
  }

  function failTrashStart() {
    const failed = trashCurrent.map(path => ({ path, error: "could not start capture trash operation" }));
    finishTrash(JSON.stringify({ ok: false, moved: [], failed }), 1);
  }

  // the pointer is hidden once hyprctl returns; then the overlays redraw
  Process {
    id: hideProc
    onExited: if (root.armed && !root.closing && root.pointerHidden) {
      root.redraw = true;
      root.plainCapture = true;
    }
  }

  Timer {
    id: freezeTimer
    interval: 32      // a couple of frames: the overlay is up before popups hide
    onTriggered: PopupManager.frozen = true
  }

  Timer {
    id: closeTimer
    interval: 180     // the fade-out; popups are back before the overlay goes
    onTriggered: {
      root.shown = false;
      root.armed = false;
      root.closing = false;
      PopupManager.holding = false;
    }
  }

  // ---- countdown ----
  Timer {
    id: countdownTimer
    interval: 1000
    repeat: true
    onTriggered: {
      if (root.countdown > 1) { root.countdown -= 1; return; }
      stop();
      root.countdown = 0;
      countdownEnd.restart();
    }
  }

  Timer {
    id: countdownEnd
    interval: 150       // the countdown's panel is gone before the stills are taken
    onTriggered: root.startSelection()
  }

  // ---- hyprland windows ----
  Process {
    id: windowsProc
    command: ["sh", "-c", "hyprctl -j monitors; echo ---; hyprctl -j clients; echo ---; hyprctl -j cursorpos"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const [m, c, p] = text.split("---");
          const pos = JSON.parse(p);
          root.pointerAt = Qt.point(pos.x, pos.y);
          const monitors = JSON.parse(m);
          const shownWs = monitors.reduce((ids, x) => ids.concat([x.activeWorkspace?.id, x.specialWorkspace?.id]), []).filter(id => id);
          root.windows = root.shellTargets.concat(JSON.parse(c)
            .filter(w => w.mapped && !w.hidden && shownWs.includes(w.workspace?.id))
            .sort((a, b) => a.focusHistoryID - b.focusHistoryID)
            .map(w => ({ x: w.at[0], y: w.at[1], width: w.size[0], height: w.size[1] })));
        } catch (e) {
          root.windows = root.shellTargets;
        }
      }
    }
  }

  Process {
    id: trashProc
    property bool started: false
    property int exitCode: -1
    property string replyText: ""
    onStarted: { started = true; exitCode = -1; replyText = ""; }
    onExited: code => exitCode = code
    onRunningChanged: {
      if (running) return;
      if (started) {
        started = false;
        root.finishTrash(replyText, exitCode);
      } else root.failTrashStart();
    }
    stdout: StdioCollector { onStreamFinished: trashProc.replyText = text }
  }

  // ---- recording ----
  CaptureRecorder {
    id: recordSession
    startDelay: closeTimer.interval + 60
    onAboutToStart: { root.faceScreens = []; root.facesAsked(); }
    onCompleted: capture => {
      root.recordingDone(true, capture.ask ? "Recording ready" : "Recording saved");
      if (capture.ask) saveSession.offer({ kind: "video", tmp: capture.file, path: capture.path, notify: capture.notify });
      else if (capture.notify) root.run(["notify-send", "-a", "Capture", "Recording saved", capture.file]);
    }
    onFailed: (capture, message) => { root.recordingDone(false, message); root.fail("Recording failed", message); }
  }

  // ---- settings ----
  FileView {
    path: Quickshell.statePath("capture.json")
    printErrors: false
    onAdapterUpdated: writeAdapter()
    onLoadFailed: writeAdapter()

    JsonAdapter {
      id: settings
      property string mode: "region"
      property string kind: "shot"
      property string audio: "off"
      property bool cursor: false
    }
  }

  IpcHandler {
    target: "capture"
    function open(): void { root.open(); }
    function stop(): void { root.stopRecording(); }
    function close(): void { root.cancelDelay(); root.close(); }
    function shot(target: string): void { root.shot(target); }
    function library(): void { root.libraryRequested(true); }
  }
}
