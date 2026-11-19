pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Shell-owned LocalSend process and the sole owner of its JSONL state.
Singleton {
  id: root

  // ---- public state ----
  property string processStatus: "stopped" // stopped | starting | ready | stopping | error
  property string error: ""
  property bool serviceAvailable: false
  property bool stateStale: false
  property bool discoveryActive: false
  property int deviceRevision: 0
  readonly property bool backgroundEnabled: ModuleSettings.get("localsend", "background", false) === true
  readonly property bool windowOpen: _windowOpen
  readonly property var devices: deviceModel
  readonly property var transfers: transferModel
  readonly property var incomingRequests: incomingModel

  signal commandFailed(string id, string code, string message)
  signal backendError(string message)
  signal incomingExpired(string alias)

  // ---- bounded process and IPC state ----
  readonly property int maxQueuedCommands: 64
  readonly property int maxDevices: 256
  readonly property int maxTransfers: 100
  readonly property int maxEventBytes: 262144
  readonly property int restartLimit: 3
  readonly property string helperPath: Quickshell.env("HOME") + "/.config/localsend/vdx-localsend"
  readonly property string downloadsPath: Quickshell.env("HOME") + "/Downloads/LocalSend"
  readonly property string statePath: Quickshell.statePath("localsend")

  property bool _windowOpen: false
  property bool processStarted: false
  property bool processReady: false
  property bool exitHandled: false
  property bool requestedShutdown: false
  property bool gotStoppedEvent: false
  property int restartAttempts: 0
  property int commandSequence: 0
  property string shutdownCommandId: ""
  property string stderrLast: ""
  property real lastCancelledReceiveAt: 0
  property var pendingCommands: ({})
  property var commandQueue: []

  ListModel { id: deviceModel; dynamicRoles: true }
  ListModel { id: transferModel; dynamicRoles: true }
  ListModel { id: incomingModel; dynamicRoles: true }

  function record(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
  }

  function text(value, max) {
    return typeof value === "string" && value.length > 0 && value.length <= max;
  }

  function number(value) {
    return typeof value === "number" && isFinite(value) && value >= 0;
  }

  function copyFiles(value) {
    const isArray = Array.isArray(value);
    const count = isArray ? value.length : value && typeof value.count === "number" && typeof value.get === "function" ? value.count : 0;
    const result = [];
    for (let i = 0; i < Math.min(count, 100); i++) {
      const file = isArray ? value[i] : value.get(i);
      const copy = {};
      for (const key of ["fileId", "fileName", "size", "fileType", "transferredBytes", "bytes", "state", "error", "path", "sha256"])
        if (file[key] !== undefined) copy[key] = file[key];
      result.push(copy);
    }
    return result;
  }

  function utf8Length(value) {
    try { return encodeURIComponent(value).replace(/%[0-9a-f]{2}/gi, "x").length; }
    catch (e) { return maxEventBytes + 1; }
  }

  function nextId() {
    commandSequence += 1;
    return "ls-" + Date.now() + "-" + commandSequence;
  }

  function activeTransferCount() {
    let count = 0;
    for (let i = 0; i < transferModel.count; i++) {
      if (["active", "starting"].includes(transferModel.get(i).state)) count += 1;
    }
    return count;
  }

  function shouldRun() {
    return backgroundEnabled || _windowOpen || activeTransferCount() > 0
      || Object.keys(pendingCommands).length > 0 || commandQueue.length > 0;
  }

  function shellReady() { syncLifecycle(); }

  function setWindowOpen(open) {
    _windowOpen = open === true;
    if (!_windowOpen && !backgroundEnabled) {
      // Pending confirmations are not accepted after their owning window closes.
      const sessions = [];
      for (let i = 0; i < incomingModel.count; i++) sessions.push(incomingModel.get(i).sessionId);
      sessions.forEach(session => rejectTransfer(session, true));
    }
    syncLifecycle();
  }

  function setBackgroundMode(enabled) {
    ModuleSettings.set("localsend", "background", enabled === true);
  }

  function syncLifecycle() {
    if (shouldRun()) {
      if (requestedShutdown) return; // let the graceful stop finish; it will be restarted if still needed
      if (!backend.running && !restartTimer.running) {
        if (processStatus === "error" && restartAttempts >= restartLimit) restartAttempts = 0;
        startHelper(false);
      }
      return;
    }
    if (!backend.running || requestedShutdown) return;
    if (!processReady) {
      requestedShutdown = true;
      backend.running = false;
      return;
    }
    beginGracefulShutdown();
  }

  function startHelper(retryNow) {
    if (backend.running || restartTimer.running) return;
    if (retryNow) restartAttempts = 0;
    if (restartAttempts >= restartLimit) {
      processStatus = "error";
      serviceAvailable = false;
      if (error === "") error = "LocalSend helper is unavailable; install the optional LocalSend component or retry.";
      return;
    }
    restartAttempts += 1;
    processStatus = "starting";
    processStarted = false;
    processReady = false;
    exitHandled = false;
    requestedShutdown = false;
    gotStoppedEvent = false;
    stderrLast = "";
    backend.command = [helperPath, "--state-dir", statePath, "--download-dir", downloadsPath];
    backend.running = true;
  }

  function retry() { startHelper(true); }

  function processStartFailed() {
    if (exitHandled) return;
    exitHandled = true;
    processStarted = false;
    processReady = false;
    discoveryActive = false;
    serviceAvailable = false;
    processStatus = "error";
    error = stderrLast || "Could not start LocalSend helper. Is the optional component installed?";
    stateStale = true;
    markDevicesUnavailable();
    incomingModel.clear();
    failQueuedCommands("backend_unavailable", error);
    backendError(error);
    scheduleRestart();
  }

  function processExited(code, exitStatus) {
    if (exitHandled) return;
    exitHandled = true;
    processStarted = false;
    processReady = false;
    discoveryActive = false;
    serviceAvailable = false;
    const expected = requestedShutdown || gotStoppedEvent;
    stabilityTimer.stop();
    incomingModel.clear();
    markDevicesUnavailable();
    if (expected) {
      requestedShutdown = false;
      shutdownCommandId = "";
      processStatus = "stopped";
      stateStale = deviceModel.count > 0;
      restartAttempts = 0;
      markActiveTransfersFailed("LocalSend helper stopped before the transfer completed.");
      failQueuedCommands("backend_stopped", "LocalSend helper stopped before the request completed.");
      Qt.callLater(() => root.syncLifecycle());
      return;
    }
    processStatus = "error";
    error = stderrLast || ("LocalSend helper exited unexpectedly (code " + code + ").");
    stateStale = true;
    markActiveTransfersFailed(error);
    failQueuedCommands("backend_stopped", error);
    backendError(error);
    scheduleRestart();
  }

  function scheduleRestart() {
    if (!shouldRun() || restartAttempts >= restartLimit) return;
    restartTimer.interval = 750 * Math.pow(2, restartAttempts - 1);
    restartTimer.restart();
  }

  function failQueuedCommands(code, message) {
    // Detach every old request before callbacks can submit work for a new process.
    const ids = Object.keys(pendingCommands);
    commandQueue = [];
    pendingCommands = ({});
    for (const id of ids) commandFailed(id, code, message);
  }

  function markActiveTransfersFailed(message) {
    const now = Date.now();
    for (let i = 0; i < transferModel.count; i++) {
      const row = transferModel.get(i);
      if (["active", "starting"].includes(row.state)) {
        transferModel.setProperty(i, "state", "failed");
        transferModel.setProperty(i, "error", message);
        transferModel.setProperty(i, "finishedAt", now);
      }
    }
  }

  function markDevicesUnavailable() {
    for (let i = 0; i < deviceModel.count; i++) deviceModel.setProperty(i, "available", false);
    if (deviceModel.count > 0) deviceRevision += 1;
  }

  function beginGracefulShutdown() {
    const id = nextId();
    requestedShutdown = true;
    gotStoppedEvent = false;
    shutdownCommandId = id;
    processStatus = "stopping";
    if (backend.running && processReady) {
      backend.write(JSON.stringify({ cmd: "shutdown", id: id, force: false, timeoutMs: 10000 }) + "\n");
      shutdownDeadline.restart();
    } else if (backend.running) {
      backend.running = false;
    }
  }

  function sendCommand(cmd, fields, meta) {
    const id = nextId();
    const item = Object.assign({ cmd: cmd, id: id }, fields || {});
    const line = JSON.stringify(item);
    if (utf8Length(line) > 65536) {
      error = "LocalSend command exceeds the JSONL size limit.";
      commandFailed(id, "message_too_large", error);
      return "";
    }
    if (Object.keys(pendingCommands).length >= maxQueuedCommands) {
      error = "Too many LocalSend requests are waiting for the helper.";
      commandFailed(id, "busy", error);
      return "";
    }
    const pending = Object.assign({}, pendingCommands);
    pending[id] = Object.assign({ cmd: cmd, at: Date.now() }, meta || {});
    pendingCommands = pending;
    if (backend.running && processReady) backend.write(line + "\n");
    else {
      commandQueue = commandQueue.concat([{ id: id, line: line }]);
      syncLifecycle();
    }
    return id;
  }

  function flushCommands() {
    if (!backend.running || !processReady) return;
    const queued = commandQueue;
    commandQueue = [];
    for (let i = 0; i < queued.length; i++) backend.write(queued[i].line + "\n");
  }

  function discover() {
    if (discoveryActive) return "";
    discoveryActive = true;
    const id = sendCommand("discover", {}, { kind: "discover" });
    if (id === "") discoveryActive = false;
    return id;
  }

  function sendFiles(fingerprint, paths) {
    if (!text(fingerprint, 128) || !Array.isArray(paths) || paths.length < 1 || paths.length > 100
        || !paths.every(path => text(path, 16384))) {
      error = "Choose a device and between 1 and 100 valid file paths.";
      commandFailed("", "invalid_arguments", error);
      return "";
    }
    return sendCommand("send", { fingerprint: fingerprint, paths: paths },
      { kind: "send", fingerprint: fingerprint, paths: paths.slice() });
  }

  function acceptTransfer(sessionId, fileIds) {
    const request = incomingForSession(sessionId);
    if (!request || !Array.isArray(fileIds) || fileIds.length < 1 || fileIds.length > 100
        || !fileIds.every(id => text(id, 128))) {
      error = "Incoming request expired or file selection is invalid.";
      commandFailed("", "invalid_arguments", error);
      return "";
    }
    return sendCommand("accept", { sessionId: sessionId, fileIds: fileIds },
      { kind: "accept", sessionId: sessionId, fileIds: fileIds.slice(),
        request: { fingerprint: request.fingerprint, alias: request.alias, files: copyFiles(request.files) } });
  }

  function rejectTransfer(sessionId, automatic) {
    if (!text(sessionId, 128)) return "";
    const request = incomingForSession(sessionId);
    if (!request && !automatic) return "";
    return sendCommand("reject", { sessionId: sessionId },
      { kind: automatic ? "autoReject" : "reject", sessionId: sessionId });
  }

  function cancelTransfer(transferId) {
    if (!text(transferId, 128)) return "";
    return sendCommand("cancel", { transferId: transferId },
      { kind: "cancel", transferId: transferId });
  }

  function getStatus() { return sendCommand("status", {}, { kind: "status" }); }

  function pendingFor(id) { return Object.prototype.hasOwnProperty.call(pendingCommands, id) ? pendingCommands[id] : null; }

  function finishCommand(id) {
    if (!pendingFor(id)) return null;
    const next = Object.assign({}, pendingCommands);
    const entry = next[id];
    delete next[id];
    pendingCommands = next;
    commandQueue = commandQueue.filter(item => item.id !== id);
    if (entry.kind === "discover") discoveryActive = false;
    return entry;
  }

  function incomingForSession(sessionId) {
    for (let i = 0; i < incomingModel.count; i++) {
      if (incomingModel.get(i).sessionId === sessionId) return incomingModel.get(i);
    }
    return null;
  }

  function removeIncoming(sessionId) {
    for (let i = incomingModel.count - 1; i >= 0; i--) {
      if (incomingModel.get(i).sessionId === sessionId) incomingModel.remove(i);
    }
  }

  function normalizeDevice(value) {
    const channel = record(value.channel) ? value.channel : value;
    if (!text(value.fingerprint, 128) || !text(value.alias, 256)
        || !text(channel.host, 256) || !number(channel.port)) return null;
    return { fingerprint: value.fingerprint, alias: value.alias,
      deviceType: typeof value.deviceType === "string" ? value.deviceType : "unknown",
      address: channel.host + ":" + channel.port, protocol: channel.protocol || "https" };
  }

  function upsertDevice(value) {
    const device = normalizeDevice(value);
    if (!device) { protocolError("malformed device event"); return; }
    let index = -1;
    for (let i = 0; i < deviceModel.count; i++) {
      if (deviceModel.get(i).fingerprint === device.fingerprint) { index = i; break; }
    }
    const data = Object.assign(device, { lastSeen: Date.now(), available: true });
    if (index >= 0) deviceModel.set(index, data);
    else if (deviceModel.count < maxDevices) deviceModel.append(data);
    else {
      let oldest = -1;
      let oldestSeen = Number.MAX_VALUE;
      for (let i = 0; i < deviceModel.count; i++) {
        const row = deviceModel.get(i);
        if (!row.available && row.lastSeen < oldestSeen) { oldest = i; oldestSeen = row.lastSeen; }
      }
      if (oldest >= 0) { deviceModel.remove(oldest); deviceModel.append(data); }
    }
    deviceRevision += 1;
  }

  function reconcileDevices(rows) {
    if (!Array.isArray(rows) || rows.length > maxDevices || !rows.every(value => normalizeDevice(value))) {
      protocolError("invalid device snapshot"); return;
    }
    const seen = {};
    rows.forEach(value => {
      const device = normalizeDevice(value);
      if (!device) return;
      seen[device.fingerprint] = true;
      upsertDevice(value);
    });
    for (let i = 0; i < deviceModel.count; i++) {
      const fingerprint = deviceModel.get(i).fingerprint;
      if (!seen[fingerprint]) deviceModel.setProperty(i, "available", false);
    }
    deviceRevision += 1;
    stateStale = false;
  }

  function findTransfer(id) {
    for (let i = 0; i < transferModel.count; i++) {
      if (transferModel.get(i).transferId === id) return i;
    }
    return -1;
  }

  function trimTransfers() {
    while (transferModel.count > maxTransfers) {
      let oldest = -1;
      for (let i = 0; i < transferModel.count; i++) {
        if (["completed", "failed", "cancelled"].includes(transferModel.get(i).state)) { oldest = i; break; }
      }
      if (oldest < 0) return;
      transferModel.remove(oldest);
    }
  }

  function upsertTransfer(id, fields) {
    if (!text(id, 128)) return -1;
    let index = findTransfer(id);
    if (index < 0) {
      transferModel.append(Object.assign({ transferId: id, sessionId: "", direction: "",
        fingerprint: "", deviceAlias: "", files: [], sourcePaths: [], transferredBytes: 0, totalBytes: 0,
        progress: 0, totalFiles: 0, cancelRequested: false, state: "starting", error: "",
        startedAt: Date.now(), finishedAt: 0 }, fields || {}));
      index = transferModel.count - 1;
    } else {
      Object.keys(fields || {}).forEach(key => transferModel.setProperty(index, key, fields[key]));
    }
    trimTransfers();
    return findTransfer(id);
  }

  function handleCommandResult(message) {
    if (!text(message.id, 128) || message.ok !== true) { protocolError("malformed command_result"); return; }
    const pending = pendingFor(message.id);
    if (!pending) return; // a late response after a process restart
    if (pending.kind === "discover") return; // acknowledged now, completed by discovery_complete
    if (pending.kind === "send" || pending.kind === "accept") {
      if (!text(message.transferId, 128)) { protocolError("command result omitted transferId"); return; }
      pending.transferId = message.transferId;
      if (pending.kind === "accept" && text(message.sessionId, 128)) pending.sessionId = message.sessionId;
      const next = Object.assign({}, pendingCommands); next[message.id] = pending; pendingCommands = next;
      // The decision has been acknowledged. Keep its metadata in pending until
      // transfer_started, but remove the request from the decision list now.
      if (pending.kind === "accept") removeIncoming(pending.sessionId);
    } else {
      finishCommand(message.id);
      if (["reject", "autoReject"].includes(pending.kind)) removeIncoming(pending.sessionId);
      if (pending.kind === "cancel") {
        const index = findTransfer(pending.transferId);
        if (index >= 0) transferModel.setProperty(index, "cancelRequested", true);
      }
      if (pending.kind === "status" && Array.isArray(message.devices)) reconcileDevices(message.devices);
    }
    if (pending.kind === "shutdown") shutdownDeadline.restart();
    syncLifecycle();
  }

  function handleError(message) {
    if (!text(message.code, 128) || typeof message.message !== "string") { protocolError("malformed error event"); return; }
    const id = typeof message.id === "string" ? message.id : "";
    const pending = id ? finishCommand(id) : null;
    error = message.message.slice(0, 512);
    if (pending) {
      if (pending.kind === "discover") discoveryActive = false;
      commandFailed(id, message.code, error);
    } else if (message.code === "unexpected_upload" && Date.now() - lastCancelledReceiveAt < 5000) {
      // The Android upload may finish its HTTP request after the accepted session was cancelled.
      return;
    } else backendError(error);
    syncLifecycle();
  }

  function handleIncoming(message) {
    if (!text(message.sessionId, 128) || !text(message.transferId, 128)
        || !text(message.alias, 256) || !text(message.fingerprint, 128)
        || !Array.isArray(message.files) || message.files.length < 1 || message.files.length > 100
        || !number(message.confirmTimeoutSeconds)) { protocolError("malformed incoming event"); return; }
    if (incomingModel.count >= 2 && !incomingForSession(message.sessionId)) {
      rejectTransfer(message.sessionId, true);
      return;
    }
    if (!_windowOpen && !backgroundEnabled) {
      rejectTransfer(message.sessionId, true);
      return;
    }
    removeIncoming(message.sessionId);
    const files = [];
    for (let i = 0; i < message.files.length; i++) {
      const file = message.files[i];
      if (!record(file) || !text(file.fileId, 128) || !text(file.fileName, 1024) || !number(file.size)) {
        protocolError("malformed incoming file metadata"); return;
      }
      files.push({ fileId: file.fileId, fileName: file.fileName, size: file.size,
        fileType: typeof file.fileType === "string" ? file.fileType : "application/octet-stream" });
    }
    incomingModel.append({ sessionId: message.sessionId, transferId: message.transferId,
      fingerprint: message.fingerprint, alias: message.alias, files: files,
      expiresAt: Date.now() + message.confirmTimeoutSeconds * 1000 });
    syncLifecycle();
  }

  function handleTransferStarted(message) {
    if (!text(message.id, 128) || !text(message.transferId, 128) || !["send", "receive"].includes(message.direction)
        || !number(message.totalFiles)) { protocolError("malformed transfer_started event"); return; }
    const pending = typeof message.id === "string" ? pendingFor(message.id) : null;
    let fields = { direction: message.direction, state: "active", startedAt: Date.now() };
    if (message.direction === "send" && pending) {
      const device = deviceByFingerprint(pending.fingerprint);
      fields.fingerprint = pending.fingerprint;
      fields.deviceAlias = device ? device.alias : "";
      fields.totalFiles = message.totalFiles;
      fields.sourcePaths = (pending.paths || []).slice();
      fields.files = (pending.paths || []).map(path => ({ fileId: "", fileName: path.split("/").pop(),
        size: 0, transferredBytes: 0, state: "queued", error: "", path: path }));
    }
    if (message.direction === "receive") {
      if (!text(message.sessionId, 128)) { protocolError("receive transfer omitted sessionId"); return; }
      const request = incomingForSession(message.sessionId) || (pending && pending.kind === "accept" ? pending.request : null);
      fields.sessionId = message.sessionId;
      fields.fingerprint = request ? request.fingerprint : "";
      fields.deviceAlias = request ? request.alias : "";
      fields.totalBytes = number(message.totalBytes) ? message.totalBytes : 0;
      fields.totalFiles = message.totalFiles;
      fields.files = request ? copyFiles(request.files).filter(file => !pending || pending.kind !== "accept" || pending.fileIds.includes(file.fileId))
        .map(file => ({ fileId: file.fileId, fileName: file.fileName,
        size: file.size, transferredBytes: 0, state: "queued", error: "", path: "" })) : [];
      removeIncoming(message.sessionId);
    }
    upsertTransfer(message.transferId, fields);
    if (pending) finishCommand(message.id);
    syncLifecycle();
  }

  function deviceByFingerprint(fingerprint) {
    for (let i = 0; i < deviceModel.count; i++) {
      const item = deviceModel.get(i);
      if (item.fingerprint === fingerprint) return item;
    }
    return null;
  }

  function handleProgress(message) {
    if (!text(message.id, 128) || !text(message.transferId, 128) || !text(message.fileId, 128)
        || !text(message.fileName, 1024) || !number(message.fileBytes) || !number(message.fileTotal)
        || !number(message.transferredBytes) || !number(message.totalBytes)) {
      protocolError("malformed transfer_progress event"); return;
    }
    let index = findTransfer(message.transferId);
    if (index < 0) index = upsertTransfer(message.transferId, { state: "active" });
    if (index < 0) return;
    const row = transferModel.get(index);
    const files = copyFiles(row.files);
    let fileIndex = files.findIndex(file => file.fileId === message.fileId);
    if (fileIndex < 0) fileIndex = files.findIndex(file => file.state === "queued" && file.fileName === message.fileName);
    const file = { fileId: message.fileId, fileName: message.fileName,
      size: message.fileTotal, transferredBytes: message.fileBytes, state: "active", error: "", path: "" };
    if (fileIndex < 0) files.push(file); else files[fileIndex] = Object.assign({}, files[fileIndex], file);
    transferModel.setProperty(index, "files", files);
    transferModel.setProperty(index, "transferredBytes", message.transferredBytes);
    transferModel.setProperty(index, "totalBytes", message.totalBytes);
    transferModel.setProperty(index, "progress", message.totalBytes > 0 ? Math.min(1, message.transferredBytes / message.totalBytes) : 0);
  }

  function handleFileCompleted(message) {
    if (!text(message.id, 128) || !text(message.transferId, 128) || !record(message.file) || !text(message.file.fileId, 128)
        || !["completed", "failed", "cancelled"].includes(message.file.state)) {
      protocolError("malformed file_completed event"); return;
    }
    const index = findTransfer(message.transferId);
    if (index < 0) return;
    const files = copyFiles(transferModel.get(index).files);
    let fileIndex = files.findIndex(item => item.fileId === message.file.fileId);
    if (fileIndex < 0 && typeof message.file.fileName === "string")
      fileIndex = files.findIndex(item => item.state === "queued" && item.fileName === message.file.fileName);
    const file = Object.assign({}, fileIndex >= 0 ? files[fileIndex] : {}, message.file);
    if (fileIndex < 0) files.push(file); else files[fileIndex] = file;
    transferModel.setProperty(index, "files", files);
    if (number(message.transferredBytes)) transferModel.setProperty(index, "transferredBytes", message.transferredBytes);
    if (number(message.totalBytes)) transferModel.setProperty(index, "totalBytes", message.totalBytes);
  }

  function handleFinished(message) {
    if (!text(message.id, 128) || !text(message.transferId, 128)
        || !["completed", "failed", "cancelled"].includes(message.state) || !Array.isArray(message.files)
        || message.files.length > 100 || !message.files.every(file => record(file) && text(file.fileId, 128)
          && ["completed", "failed", "cancelled"].includes(file.state))) {
      protocolError("malformed transfer_finished event"); return;
    }
    const index = findTransfer(message.transferId);
    if (index < 0) return;
    const row = transferModel.get(index);
    if (["completed", "failed", "cancelled"].includes(row.state)) return;
    transferModel.setProperty(index, "state", message.state);
    transferModel.setProperty(index, "files", message.files);
    transferModel.setProperty(index, "error", record(message.error) ? String(message.error.message || "") : "");
    transferModel.setProperty(index, "finishedAt", Date.now());
    if (number(message.transferredBytes)) transferModel.setProperty(index, "transferredBytes", message.transferredBytes);
    if (number(message.totalBytes)) transferModel.setProperty(index, "totalBytes", message.totalBytes);
    if (row.totalBytes > 0) transferModel.setProperty(index, "progress", message.state === "completed" ? 1 : row.transferredBytes / row.totalBytes);
    if (row.direction === "receive" && message.state === "cancelled") lastCancelledReceiveAt = Date.now();
    syncLifecycle();
  }

  function handleEvent(message) {
    if (!record(message) || message.v !== 1 || !text(message.event, 64)) {
      protocolError("invalid JSONL event envelope or unsupported contract version"); return;
    }
    switch (message.event) {
    case "ready":
      processReady = true;
      processStatus = "ready";
      serviceAvailable = true;
      stateStale = deviceModel.count > 0;
      markDevicesUnavailable();
      error = "";
      stabilityTimer.restart();
      readyDeadline.stop();
      flushCommands();
      break;
    case "command_result": handleCommandResult(message); break;
    case "error": handleError(message); break;
    case "device":
      if (!record(message.device)) { protocolError("malformed device event"); break; }
      upsertDevice(message.device);
      break;
    case "discovery_complete":
      if (!text(message.id, 128) || !Array.isArray(message.devices)) { protocolError("malformed discovery_complete event"); break; }
      reconcileDevices(message.devices);
      finishCommand(typeof message.id === "string" ? message.id : "");
      discoveryActive = false;
      break;
    case "incoming": handleIncoming(message); break;
    case "transfer_started": handleTransferStarted(message); break;
    case "transfer_progress": handleProgress(message); break;
    case "file_completed": handleFileCompleted(message); break;
    case "transfer_finished": handleFinished(message); break;
    case "incoming_expired":
      if (text(message.sessionId, 128)) {
        const expired = incomingForSession(message.sessionId);
        if (expired) incomingExpired(expired.alias);
        removeIncoming(message.sessionId);
      }
      break;
    case "incoming_rejected":
      if (text(message.sessionId, 128)) removeIncoming(message.sessionId);
      break;
    case "remote_cancel":
      if (!text(message.sessionId, 128)) { protocolError("malformed remote_cancel event"); break; }
      for (let i = 0; i < transferModel.count; i++) {
        if (transferModel.get(i).sessionId === message.sessionId && transferModel.get(i).state === "active")
          transferModel.setProperty(i, "error", "The other device cancelled this transfer.");
      }
      break;
    case "peer_registered":
    case "warning":
    case "shutdown_timeout":
      break;
    case "stopped":
      gotStoppedEvent = true;
      break;
    default:
      console.warn("LocalSend: ignored unknown event " + message.event);
      break;
    }
    syncLifecycle();
  }

  function protocolError(message) {
    error = "LocalSend protocol error: " + String(message).slice(0, 256);
    console.warn(error);
  }

  function parseLine(line) {
    if (typeof line !== "string" || utf8Length(line) > maxEventBytes) {
      protocolError("event line exceeded the safety limit"); return;
    }
    let message;
    try { message = JSON.parse(line); }
    catch (e) { protocolError("invalid JSONL from helper: " + String(e)); return; }
    handleEvent(message);
  }

  function logStderr(line) {
    if (typeof line !== "string" || line === "") return;
    stderrLast = line.slice(0, 512);
    console.warn("LocalSend helper: " + stderrLast);
  }

  function expireCommands() {
    const now = Date.now();
    Object.keys(pendingCommands).forEach(id => {
      const item = pendingCommands[id];
      if (now - item.at <= 120000) return;
      finishCommand(id);
      commandFailed(id, "command_timeout", "LocalSend did not answer the request in time.");
    });
    syncLifecycle();
  }

  function onBackgroundSettingChanged() { syncLifecycle(); }

  Component.onCompleted: shellReady()
  onBackgroundEnabledChanged: onBackgroundSettingChanged()

  Timer {
    id: restartTimer
    repeat: false
    onTriggered: if (root.shouldRun()) root.startHelper(false)
  }

  Timer {
    id: readyDeadline
    interval: 7000
    repeat: false
    onTriggered: if (backend.running && !root.processReady) {
      root.error = "LocalSend helper did not send its ready event.";
      root.backendError(root.error);
      backend.signal(15);
    }
  }

  Timer {
    id: shutdownDeadline
    interval: 17000
    repeat: false
    onTriggered: if (backend.running && root.requestedShutdown) {
      backend.signal(15);
      forceDeadline.restart();
    }
  }

  Timer {
    id: stabilityTimer
    interval: 60000
    repeat: false
    onTriggered: root.restartAttempts = 0
  }

  Timer {
    interval: 5000
    repeat: true
    running: Object.keys(root.pendingCommands).length > 0
    onTriggered: root.expireCommands()
  }

  Timer {
    id: forceDeadline
    interval: 6000
    repeat: false
    onTriggered: if (backend.running && root.requestedShutdown) backend.signal(9)
  }

  Process {
    id: backend
    stdinEnabled: true
    stdout: SplitParser { onRead: line => root.parseLine(line) }
    stderr: SplitParser { onRead: line => root.logStderr(line) }
    onStarted: {
      root.processStarted = true;
      root.processStatus = "starting";
      readyDeadline.restart();
    }
    onExited: (code, exitStatus) => {
      readyDeadline.stop();
      shutdownDeadline.stop();
      forceDeadline.stop();
      root.processExited(code, exitStatus);
    }
    onRunningChanged: {
      if (running) return;
      if (root.processStatus === "starting" && !root.processStarted && !root.exitHandled)
        Qt.callLater(() => root.processStartFailed());
    }
  }

}
