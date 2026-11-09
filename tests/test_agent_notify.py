"""agent_notify.py: what a Codex or Claude Code notice says — the project, the
request or the last answer — and when it stays silent."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location(
    "agent_notify", ROOT / "packages/quickshell/shell/scripts/agent_notify.py")
notify = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(notify)


class Compose(unittest.TestCase):
    def test_permission_names_the_project_and_the_request(self):
        app, title, body, urgency = notify.compose(
            "claude-permission",
            {"cwd": "/home/me/.dotfiles/", "notification_type": "permission_prompt",
             "message": "Claude needs your permission to use Bash"})
        self.assertEqual((app, urgency), ("Claude Code", "critical"))
        self.assertEqual(title, "Claude Code needs permission · .dotfiles")
        self.assertEqual(body, "Claude needs your permission to use Bash")

    def test_permission_without_a_message_says_the_tool_and_its_command(self):
        _, _, body, _ = notify.compose(
            "codex-permission", {"tool_name": "Bash", "tool_input": {"command": "rm -rf build\nls"}})
        self.assertEqual(body, "Bash: rm -rf build")
        _, _, body, _ = notify.compose("codex-permission", {})
        self.assertEqual(body, "A command is waiting for your approval")

    def test_claude_idle_notifications_are_not_permission_prompts(self):
        self.assertIsNone(notify.compose("claude-permission", {"notification_type": "idle_prompt"}))

    def test_complete_quotes_the_first_line_of_the_last_message(self):
        _, title, body, urgency = notify.compose(
            "codex-complete", {"cwd": "/srv/app", "last_assistant_message": "\n## Done\nmore"})
        self.assertEqual((title, body, urgency), ("Codex finished · app", "Done", "normal"))

    def test_complete_without_a_message_and_a_stop_hook_continuation(self):
        _, _, body, _ = notify.compose("claude-complete", {})
        self.assertEqual(body, "The task is complete")
        self.assertIsNone(notify.compose("claude-complete", {"stop_hook_active": True}))

    def test_unknown_events_are_silent(self):
        self.assertIsNone(notify.compose("gemini-complete", {}))
        self.assertIsNone(notify.compose("codex-other", {}))

    def test_long_text_is_cut_on_one_line(self):
        text = notify.one_line("word " * 100)
        self.assertEqual(len(text), notify.TEXT_LIMIT)
        self.assertTrue(text.endswith("…"))


if __name__ == "__main__":
    unittest.main()
