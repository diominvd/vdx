"""AI links preserve existing files and can be restored without touching edits."""

import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from installer import model


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("ai_manage", ROOT / "ai/manage.py")
manage = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(manage)


class AiWorkspaceTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()
        self.addCleanup(self.output.__exit__, None, None, None)

    def backups(self):
        return list((self.home / ".local/state/vdx-ai").iterdir())

    def test_link_idempotence_and_restore_empty_home(self):
        self.assertEqual(manage.status(self.home), 1)
        manage.link(self.home)
        self.assertEqual(manage.status(self.home), 0)
        backups = self.backups()
        manage.link(self.home)
        self.assertEqual(self.backups(), backups)
        manage.restore(self.home, backups[0])
        self.assertFalse(manage.present(self.home / "AI.md"))

    def test_existing_files_and_retired_skill_are_preserved(self):
        target = self.home / ".claude/CLAUDE.md"
        target.parent.mkdir(parents=True)
        target.write_text("personal instructions\n")
        retired = self.home / ".codex/skills/shell"
        retired.mkdir(parents=True)
        (retired / "SKILL.md").write_text("original skill\n")
        manage.link(self.home)
        self.assertFalse(retired.exists())
        manage.restore(self.home, self.backups()[0])
        self.assertEqual(target.read_text(), "personal instructions\n")
        self.assertEqual((retired / "SKILL.md").read_text(), "original skill\n")

    def test_changed_target_blocks_restore_before_any_mutation(self):
        manage.link(self.home)
        target = self.home / ".claude/CLAUDE.md"
        target.unlink()
        target.write_text("new user edit\n")
        with self.assertRaisesRegex(ValueError, "Changed since linking"):
            manage.restore(self.home, self.backups()[0])
        self.assertTrue((self.home / "AI.md").is_symlink())
        self.assertEqual(target.read_text(), "new user edit\n")

    def test_broken_symlink_is_backed_up_and_restored(self):
        target = self.home / "AI.md"
        target.symlink_to(self.home / "missing")
        manage.link(self.home)
        manage.restore(self.home, self.backups()[0])
        self.assertTrue(target.is_symlink())
        self.assertEqual(target.readlink(), self.home / "missing")

    def test_dotfile_cleanup_preserves_ai_links_and_checkout_sources(self):
        manage.link(self.home)
        stale = self.home / "old-config"
        stale.symlink_to(ROOT / "README.md")
        source = ROOT / "packages/opencode/rules/TOKENS.md"
        paths = [self.home / "AI.md", self.home / ".codex/AGENTS.md", source, stale]
        with patch.object(model, "HOME", self.home), patch.object(model, "_walk", return_value=paths):
            self.assertEqual(model.stale_links([]), [stale])
            self.assertEqual(model.cleanup_stale([]), 1)
        self.assertTrue((self.home / "AI.md").is_symlink())


if __name__ == "__main__":
    unittest.main()
