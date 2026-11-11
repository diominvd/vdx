"""AI service reply schemas and process recovery, with no real AI commands."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

from tests.check_shell_ui import qml_block, qml_function
from tests.qml_runtime import SHELL, run_quickshell


AI = SHELL / "modules/ai"


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class AiServices(unittest.TestCase):
    def run_fixture(self, root, source):
        (root / "kit").mkdir(exist_ok=True)
        shutil.copy(SHELL / "kit/reply.js", root / "kit/reply.js")
        (root / "shell.qml").write_text(source)
        return run_quickshell(root, timeout=12)

    def result(self, output, marker):
        lines = [line.split(marker, 1)[1] for line in output.splitlines() if marker in line]
        self.assertEqual(len(lines), 1, output)
        return json.loads(lines[0])

    def test_ollama_status_accepts_offline_and_valid_models_but_preserves_good_state(self):
        source = (AI / "OllamaService.qml").read_text()
        funcs = "\n".join(qml_function(source, name) for name in ("finite", "record", "validStatus", "acceptStatus"))
        with tempfile.TemporaryDirectory(prefix="ai-ollama-schema-") as tmp:
            output = self.run_fixture(Path(tmp), '''import QtQuick
import Quickshell
Scope {
  id: root
  property var status: ({})
''' + funcs + '''
  Timer { interval: 0; running: true; onTriggered: {
    const offline = acceptStatus({installed: false, running: false});
    const good = acceptStatus({installed: true, running: true, version: "0.5",
      models: [{name: "qwen", size: 12}], loaded: [{name: "qwen", vram: 8}]});
    const snapshot = status;
    const bad = acceptStatus({installed: true, running: true, version: "0.5",
      models: [{name: "broken", size: "large"}], loaded: []});
    console.warn("AI_OLLAMA_SCHEMA:" + JSON.stringify({offline, good, bad, preserved: status === snapshot, status}));
    Qt.quit();
  } }
}
''')
            self.assertEqual(self.result(output, "AI_OLLAMA_SCHEMA:"), {
                "offline": True, "good": True, "bad": False, "preserved": True,
                "status": {"installed": True, "running": True, "version": "0.5",
                           "models": [{"name": "qwen", "size": 12}],
                           "loaded": [{"name": "qwen", "vram": 8}]}})

    def test_claude_usage_today_sessions_and_cache_shapes(self):
        source = (AI / "ClaudeService.qml").read_text()
        funcs = "\n".join(qml_function(source, name) for name in
                           ("finite", "record", "validUsage", "validToday", "validSessions", "validCache"))
        with tempfile.TemporaryDirectory(prefix="ai-claude-schema-") as tmp:
            output = self.run_fixture(Path(tmp), '''import QtQuick
import Quickshell
Scope {
  id: root
''' + funcs + '''
  Timer { interval: 0; running: true; onTriggered: {
    const usage = {ok: true, plan: "pro", limits: [{kind: "weekly", percent: 70, resets_at: "2030-01-01T00:00:00Z"}]};
    const today = {messages: 2, input: 10, output: 20, cache_read: 3, cache_write: 4};
    const sessions = [{name: "session", cwd: "/tmp", status: "busy", version: "1", started: 100}];
    const result = {usage: validUsage(usage), badUsage: validUsage({ok: true, plan: "pro", limits: [{kind: "weekly", percent: "70"}]}),
      today: validToday(today), badToday: validToday({messages: 1, input: "2", output: 3, cache_read: 0, cache_write: 0}),
      sessions: validSessions(sessions), badSessions: validSessions([{name: "bad", cwd: 2}]),
      cache: validCache(usage, 100), badCache: validCache(usage, Infinity)};
    console.warn("AI_CLAUDE_SCHEMA:" + JSON.stringify(result));
    Qt.quit();
  } }
}
''')
            self.assertEqual(self.result(output, "AI_CLAUDE_SCHEMA:"), {
                "usage": True, "badUsage": False, "today": True, "badToday": False,
                "sessions": True, "badSessions": False, "cache": True, "badCache": False})

    def test_codex_usage_requires_finite_limits_and_timestamp(self):
        source = (AI / "CodexService.qml").read_text()
        funcs = "\n".join(qml_function(source, name) for name in ("finite", "record", "validUsage"))
        with tempfile.TemporaryDirectory(prefix="ai-codex-schema-") as tmp:
            output = self.run_fixture(Path(tmp), '''import QtQuick
import Quickshell
Scope {
  id: root
''' + funcs + '''
  Timer { interval: 0; running: true; onTriggered: {
    const good = validUsage({ok: true, plan: "plus", at: "2030-01-01T00:00:00Z",
      limits: [{kind: "session", percent: 45, resets_at: "2030-01-01T01:00:00Z"}]});
    const badLimit = validUsage({ok: true, plan: "plus", at: "2030-01-01T00:00:00Z",
      limits: [{kind: "session", percent: NaN, resets_at: "2030-01-01T01:00:00Z"}]});
    const badDate = validUsage({ok: true, plan: "plus", at: "unknown", limits: []});
    console.warn("AI_CODEX_SCHEMA:" + JSON.stringify({good, badLimit, badDate}));
    Qt.quit();
  } }
}
''')
            self.assertEqual(self.result(output, "AI_CODEX_SCHEMA:"),
                             {"good": True, "badLimit": False, "badDate": False})

    def test_ollama_action_start_failure_and_completion_release_busy_after_exit(self):
        source = (AI / "OllamaService.qml").read_text()
        funcs = "\n".join(qml_function(source, name) for name in
                           ("act", "run", "consumeActionReply"))
        funcs = funcs.replace('proc.command = ["bash", root.script].concat(args);',
                              "proc.command = root.actionCommand;")
        process = qml_block(source, "Process {\n    id: actionProc")
        with tempfile.TemporaryDirectory(prefix="ai-ollama-action-") as tmp:
            root = Path(tmp)
            fake = root / "fake_action.py"
            fake.write_text("import json, time\ntime.sleep(0.2)\nprint(json.dumps({'ok': True}))\n")
            command = json.dumps([sys.executable, str(fake)])
            output = self.run_fixture(root, '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property string script: "unused"
  property var actionCommand: ["/no/such/ollama-command"]
  property var busy: null
  property string error: ""
  property int refreshes: 0
  property int phase: 0
  property bool busyWhileRunning: false
  property int ticks: 0
  function refresh() { refreshes++; }
''' + funcs + '\n' + process + '''
  Timer { interval: 10; repeat: true; running: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) { root.act("server", ["--start"]); root.phase = 1; }
    else if (root.phase === 1 && root.error === "could not start Ollama action") {
      root.actionCommand = ''' + command + '''; root.error = ""; root.act("qwen", ["--pull", "qwen"]); root.phase = 2;
    } else if (root.phase === 2 && actionProc.running) {
      root.busyWhileRunning = root.busy === "qwen"; root.phase = 3;
    } else if (root.phase === 3 && !actionProc.running && root.busy === null) {
      console.warn("AI_OLLAMA_ACTION:" + JSON.stringify({busy: root.busy, error: root.error,
        refreshes: root.refreshes, busyWhileRunning: root.busyWhileRunning}));
      Qt.quit();
    }
    if (root.ticks > 150) { console.warn("AI_OLLAMA_ACTION_TIMEOUT:" + root.phase + ":" + root.error); Qt.quit(); }
  } }
}
''')
            self.assertEqual(self.result(output, "AI_OLLAMA_ACTION:"), {
                "busy": None, "error": "", "refreshes": 2, "busyWhileRunning": True})

    def test_claude_and_codex_failed_process_starts_are_visible(self):
        claude = (AI / "ClaudeService.qml").read_text()
        codex = (AI / "CodexService.qml").read_text()
        claude_funcs = "\n".join(qml_function(claude, name) for name in
                                  ("finite", "record", "validUsage", "validToday", "validSessions"))
        usage = qml_block(claude, "Process {\n    id: usageProc")
        today = qml_block(claude, "Process {\n    id: todayProc")
        sessions = qml_block(claude, "Process {\n    id: sessionsProc")
        codex_funcs = "\n".join(qml_function(codex, name) for name in ("finite", "record", "validUsage"))
        codex_funcs = (codex_funcs.replace("function finite(", "function codexFinite(")
                       .replace("function record(", "function codexRecord(")
                       .replace("function validUsage(", "function validCodexUsage(")
                       .replace("finite(", "codexFinite(").replace("record(", "codexRecord("))
        codex_proc = qml_block(codex, "Process {\n    id: proc")
        codex_proc = codex_proc.replace("root.validUsage", "root.validCodexUsage")
        with tempfile.TemporaryDirectory(prefix="ai-start-errors-") as tmp:
            output = self.run_fixture(Path(tmp), '''import QtQuick
import Quickshell
import Quickshell.Io
import "kit/reply.js" as Reply
Scope {
  id: root
  property string script: "unused"
  property var usage: ({})
  property real fetchedAt: 0
  property var today: ({})
  property var sessions: []
  property string error: ""
  property int phase: 0
  property int ticks: 0
  function parse(text, fallback) { return Reply.parse(text, "claude.sh", fallback); }
  QtObject { id: saved; property var usage: ({}); property real fetchedAt: 0 }
''' + claude_funcs + '\n' + usage + '\n' + today + '\n' + sessions + '\n'
            + codex_funcs + '\n' + codex_proc + '''
  Timer { interval: 10; repeat: true; running: true; onTriggered: {
    root.ticks++;
    if (root.phase === 0) {
      usageProc.command = ["/no/claude-usage"]; usageProc.running = true; root.phase = 1;
    } else if (root.phase === 1 && root.error === "could not start Claude usage query") {
      root.error = ""; todayProc.command = ["/no/claude-today"]; todayProc.running = true; root.phase = 2;
    } else if (root.phase === 2 && root.error === "could not start Claude today query") {
      root.error = ""; sessionsProc.command = ["/no/claude-sessions"]; sessionsProc.running = true; root.phase = 3;
    } else if (root.phase === 3 && root.error === "could not start Claude sessions query") {
      root.error = ""; proc.command = ["/no/codex-usage"]; proc.running = true; root.phase = 4;
    } else if (root.phase === 4 && root.error === "could not start Codex usage query") {
      console.warn("AI_START_ERRORS:" + JSON.stringify({phase: root.phase, error: root.error}));
      Qt.quit();
    }
    if (root.ticks > 150) { console.warn("AI_START_ERRORS_TIMEOUT:" + root.phase + ":" + root.error); Qt.quit(); }
  } }
}
''')
            self.assertEqual(self.result(output, "AI_START_ERRORS:"),
                             {"phase": 4, "error": "could not start Codex usage query"})


if __name__ == "__main__":
    unittest.main()
