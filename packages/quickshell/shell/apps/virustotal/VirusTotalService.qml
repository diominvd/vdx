pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../../kit/reply.js" as Reply

// The VirusTotal lookup (scripts/virustotal.py), shared by its window and its
// bar module. Scan asks what VirusTotal knows about a hash, a URL or a file
// path; a file it has never seen goes up only when Upload is pressed. Recent
// lookups are kept for the window, and between runs when the option is on.
// Options: Shell Manager › Shell apps (ModuleSettings "virustotal").
Singleton {
  id: root

  readonly property string script: Paths.scriptsDir + "/virustotal.py"

  // ---- options ----
  function opt(key, fallback) { return ModuleSettings.get("virustotal", key, fallback); }
  readonly property int historyKeep: opt("historyKeep", 20)
  readonly property bool keepHistory: opt("keepHistory", false)
  readonly property int waitSeconds: opt("waitSeconds", 90)
  readonly property string reportAction: opt("reportAction", "browser")
  readonly property bool clipboardOn: opt("clipboard", false)

  property string target: ""                // what was asked
  property bool busy: false
  property bool uploading: false            // the busy lookup is an upload
  property var result: null                 // the script's reply, known or not
  property string error: ""
  property var history: []                  // [{target, verdict}], newest first

  // "malicious" | "suspicious" | "clean" | "unknown" | ""
  readonly property string verdict: verdictOf(result)
  readonly property bool canUpload: !!result && validResult(result) && !result.known && result.kind === "file"
                                    && result.target !== result.sha256

  function verdictOf(r) {
    if (!r) return "";
    if (r.known === false) return "unknown";
    if (r.known !== true || !validStats(r.stats)) return "";
    if (r.stats.malicious > 0) return "malicious";
    if (r.stats.suspicious > 0) return "suspicious";
    return "clean";
  }

  function validStats(stats) {
    return stats && typeof stats === "object" && !Array.isArray(stats)
      && ["malicious", "suspicious", "undetected", "harmless", "timeout"].every(key =>
        typeof stats[key] === "number" && isFinite(stats[key]) && stats[key] >= 0);
  }

  function validResult(r) {
    if (!r || r.ok !== true || typeof r.known !== "boolean"
        || !["file", "url"].includes(r.kind) || typeof r.target !== "string") return false;
    if (r.known) {
      return typeof r.name === "string" && typeof r.link === "string" && validStats(r.stats)
        && Array.isArray(r.detections) && r.detections.every(d => d
          && typeof d.engine === "string" && typeof d.category === "string"
          && typeof d.result === "string");
    }
    return r.kind === "file" && typeof r.sha256 === "string"
      && (r.size === null || (typeof r.size === "number" && isFinite(r.size) && r.size >= 0));
  }

  function replyError(r, fallback) {
    return typeof r?.error === "string" && r.error.trim() !== "" ? r.error : fallback;
  }

  function finishLookup(message) {
    uploading = false;
    error = message;
    busy = false;
  }

  function acceptResult(r) {
    if (r?.ok !== true) { finishLookup(replyError(r, "VirusTotal lookup failed")); return false; }
    if (!validResult(r)) { finishLookup("bad VirusTotal reply"); return false; }
    result = r;
    remember(r);
    error = "";
    uploading = false;
    busy = false;
    return true;
  }

  function verdictWord(v) {
    return ({ malicious: "MALICIOUS", suspicious: "SUSPICIOUS", clean: "CLEAN", unknown: "NOT SEEN BEFORE" })[v] ?? "NO SCAN YET";
  }

  function count(key) { return result?.stats?.[key] ?? 0; }

  function historyLimit() {
    return Math.max(0, Math.min(50, historyKeep));
  }

  function validHistory(rows) {
    if (!Array.isArray(rows)) return [];
    const verdicts = ["malicious", "suspicious", "clean", "unknown"];
    return rows.filter(row => row && typeof row.target === "string" && verdicts.includes(row.verdict));
  }

  function loadHistory(rows) {
    history = keepHistory ? validHistory(rows).slice(0, historyLimit()) : [];
  }

  function scan(text) {
    const t = text.trim();
    if (busy || t === "") return;
    target = t;
    busy = true;
    uploading = false;
    error = "";
    result = null;
    proc.command = ["python3", script, "scan", t, String(waitSeconds)];
    proc.running = true;
  }

  function upload() {
    if (busy || !canUpload) return;
    busy = true;
    uploading = true;
    error = "";
    proc.command = ["python3", script, "upload", result.target, String(waitSeconds)];
    proc.running = true;
  }

  // the report: the browser, or the link copied to the clipboard
  function openLink() {
    if (!result?.link) return;
    if (reportAction === "copy") Quickshell.execDetached(["wl-copy", result.link]);
    else Quickshell.execDetached(["xdg-open", result.link]);
  }

  // the clipboard's text, if it is a hash or a URL, goes into the popup's
  // field (never scanned by itself): `into` is the field's owner, prefill(text)
  property var into: null
  property bool clipPending: false
  function readClipboard(owner) {
    if (clipPending || clipProc.running) return false;
    into = owner;
    clipPending = true;
    error = "";
    clipProc.running = true;
    return true;
  }

  function parse(text) {
    return Reply.parse(text, "virustotal.py");
  }

  // the history: newest first, the option's length; written only when kept
  onKeepHistoryChanged: persist()

  function persist() {
    state.history = keepHistory ? history : [];
    stateFile.writeAdapter();
  }

  function remember(r) {
    if (!validResult(r)) return;
    history = [{ target: r.target, verdict: verdictOf(r) }]
      .concat(validHistory(history).filter(h => h.target !== r.target)).slice(0, historyLimit());
    persist();
  }

  FileView {
    id: stateFile
    path: Quickshell.statePath("virustotal.json")
    printErrors: false
    onLoaded: root.loadHistory(state.history)
    onLoadFailed: stateFile.writeAdapter()

    JsonAdapter {
      id: state
      property var history: []
    }
  }

  Process {
    id: proc
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.finishLookup("could not start VirusTotal lookup");
    }
    stdout: StdioCollector {
      onStreamFinished: {
        root.acceptResult(root.parse(text));
      }
    }
  }

  // the clipboard: a hash (64 hex digits) or an http(s) URL
  Process {
    id: clipProc
    command: ["wl-paste", "--no-newline"]
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.into = null;
      root.clipPending = false;
      root.error = "could not start clipboard read";
    }
    stdout: StdioCollector {
      onStreamFinished: {
        const t = text.trim();
        const owner = root.into;
        root.into = null;
        root.clipPending = false;
        if (owner && (/^[0-9a-fA-F]{64}$/.test(t) || /^https?:\/\/\S+$/i.test(t)))
          owner.prefill(t);
      }
    }
  }
}
