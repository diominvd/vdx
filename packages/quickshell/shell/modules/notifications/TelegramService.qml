pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../../kit/reply.js" as Reply
import "../../kit/markup.js" as Markup
import "telegram_rules.js" as Rules

// Notifications › Forwarding and NotificationsService share one worker. No startup read or
// idle polling: local status on page open, network only for an action or new notice.
Singleton {
  id: root

  // ---- tuning ----
  readonly property string script: Paths.scriptsDir + "/telegram.py"
  readonly property var settingsKeys: ["enabled", "body", "silent", "urgency", "filter", "apps"]
  readonly property int queueMax: 50
  readonly property int queueAgeMs: 60000
  readonly property int sendGapMs: 1100

  // ---- state ----
  readonly property bool enabled: ModuleSettings.get("telegram", "enabled", false) === true
  readonly property string policy: JSON.stringify(["urgency", "filter", "apps", "body", "silent"].map(k => ModuleSettings.get("telegram", k, null)))
  property bool stateKnown: false
  property bool configured: false
  property bool connected: false
  property string username: ""
  property string pairUrl: ""
  property bool busy: false
  property string status: ""
  property string error: ""
  property var queue: []
  property bool readQueued: false
  property real nextSendAt: 0

  onEnabledChanged: if (!enabled) { queue = []; sendDelay.stop(); }
  onPolicyChanged: { queue = []; sendDelay.stop(); }

  // ---- actions ----
  function refresh() {
    if (busy) { readQueued = true; return; }
    run("status", {});
  }

  function connect(token) {
    if (busy || token.trim() === "") return false;
    ModuleSettings.set("telegram", "enabled", false);
    queue = [];
    return run("connect", { token: token });
  }

  function disconnect() {
    if (busy) return;
    ModuleSettings.set("telegram", "enabled", false);
    queue = [];
    run("disconnect", {});
  }

  function run(action, payload) {
    if (busy || proc.running) return false;
    busy = true;
    if (action !== "status") error = "";
    status = action === "send" ? "Sending…" : "Working…";
    proc.action = action;
    proc.payload = JSON.stringify(payload);
    proc.replyReady = false;
    proc.processStopped = false;
    proc.pendingReply = null;
    proc.stdinEnabled = true;
    proc.command = ["python3", root.script, action];
    proc.running = true;
    return true;
  }

  // Called only for news accepted by the existing history deduplication.
  function enqueue(news) {
    if (!enabled) return;
    const options = {
      urgency: ModuleSettings.get("telegram", "urgency", "all"),
      filter: ModuleSettings.get("telegram", "filter", "all"),
      apps: String(ModuleSettings.get("telegram", "apps", ""))
    };
    const body = ModuleSettings.get("telegram", "body", true) === true;
    const silent = ModuleSettings.get("telegram", "silent", false) === true;
    let pending = queue.slice();
    for (const n of news) {
      if (!Rules.accepts(n, options)) continue;
      const text = Rules.message({ app: Markup.plain(n.app), summary: Markup.plain(n.summary), body: Markup.plain(n.body) }, body);
      pending = pending.filter(p => p.key !== n.key);
      pending.push({ key: n.key, at: Date.now(), text: text, silent: silent });
    }
    queue = pending.slice(-queueMax);
    schedule();
  }

  function schedule() {
    if (busy || !enabled || queue.length === 0) return;
    sendDelay.interval = Math.max(1, nextSendAt - Date.now());
    sendDelay.restart();
  }

  function drain() {
    if (busy || !enabled) return;
    queue = queue.filter(p => Date.now() - p.at < queueAgeMs);
    if (queue.length === 0) return;
    const item = queue[0];
    queue = queue.slice(1);
    run("send", { text: item.text, silent: item.silent });
  }

  function consumeReply() {
    if (!proc.processStopped || !proc.replyReady) return;
    const o = proc.pendingReply;
    const action = proc.action;
    proc.replyReady = false;
    proc.payload = "";
    let success = o?.ok === true;
    if (success && ["status", "connect", "renew", "pair", "disconnect"].includes(action)) {
      success = typeof o.configured === "boolean" && typeof o.connected === "boolean"
             && typeof o.username === "string" && typeof o.pairUrl === "string";
      if (success) {
        stateKnown = true;
        configured = o.configured;
        connected = o.connected;
        username = o.username;
        pairUrl = o.pairUrl;
      }
    }
    if (!success) {
      error = typeof o?.error === "string" && o.error ? o.error : "Invalid reply from Telegram helper";
      status = "";
      if (action === "send") queue = []; // no automatic retries: timeout can mean delivered
      if (action === "pair") readQueued = true; // refresh an expired link without asking for the token again
    } else {
      if (action !== "status") error = ""; // opening the page must retain a delivery failure
      status = action === "send" ? "Notification sent" : action === "test" ? "Test sent"
             : connected ? "Connected" : configured ? "Waiting for Start in Telegram" : "Not connected";
    }
    if (action === "send" || action === "test") nextSendAt = Date.now() + sendGapMs;
    if (typeof o?.retryAfter === "number" && isFinite(o.retryAfter) && o.retryAfter > 0)
      nextSendAt = Date.now() + Math.min(3600, o.retryAfter) * 1000;
    busy = false;
    if (readQueued) { readQueued = false; refresh(); }
    else schedule();
  }

  // ---- worker ----
  Timer { id: sendDelay; onTriggered: root.drain() }

  Process {
    id: proc
    property string action: ""
    property string payload: ""
    property bool started: false
    property bool processStopped: true
    property bool replyReady: false
    property var pendingReply: null
    stdinEnabled: true
    onStarted: {
      started = true;
      write(payload + "\n");
      payload = "";
      stdinEnabled = false;
    }
    onRunningChanged: {
      if (running) return;
      processStopped = true;
      payload = "";
      if (!started) {
        pendingReply = { ok: false, error: "Could not start Telegram helper" };
        replyReady = true;
      }
      started = false;
      root.consumeReply();
    }
    stdout: StdioCollector {
      onStreamFinished: {
        proc.pendingReply = Reply.parse(text, "telegram.py");
        proc.replyReady = true;
        root.consumeReply();
      }
    }
  }
}
