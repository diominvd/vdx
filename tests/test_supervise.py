"""supervise.sh: a kill ends it, a config that does not load is one toast and a
wait for a fix (not a crash loop), five crashes in a minute stop it, and its
toasts go once the shell has been up for a few seconds."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import textwrap
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUPERVISE = ROOT / "packages/quickshell/shell/scripts/supervise.sh"

# a qs that ends with the next code of codes.txt; on 255 it leaves a log of a
# config that did not load and makes shell.qml newer (the fix)
FAKE_QS = textwrap.dedent("""\
    #!/usr/bin/env bash
    echo "$*" >> "$SANDBOX/qs.calls"
    code=$(head -1 "$SANDBOX/codes.txt"); sed -i 1d "$SANDBOX/codes.txt"
    # "up": runs past the supervisor's settle time, then is killed
    [[ $code == up ]] && { sleep 4; exit 143; }
    if [[ $code == 255 ]]; then
      mkdir -p "$XDG_RUNTIME_DIR/quickshell/by-pid/$$"
      printf 'ERROR: Failed to load configuration\\nERROR:   caused by @shell.qml[2:3]: Nope is not a type\\n' \\
        > "$XDG_RUNTIME_DIR/quickshell/by-pid/$$/log.log"
      touch -d "@$(( $(date +%s) + 5 ))" "$SANDBOX/shell/shell.qml"
    fi
    exit "$code"
    """)


class SessionEnvironment(unittest.TestCase):
    def select(self, sessions, display="wayland-1", inherited="old-session"):
        source = SUPERVISE.read_text()
        body = source.split("resolve_hyprland_session() {", 1)[1].split("\n}\n", 1)[0]
        with tempfile.TemporaryDirectory() as temporary:
            runtime = Path(temporary)
            for signature, pid, wayland in sessions:
                directory = runtime / "hypr" / signature
                directory.mkdir(parents=True)
                (directory / "hyprland.lock").write_text(f"{pid}\n{wayland}\n")
            env = dict(os.environ, WAYLAND_DISPLAY=display,
                       HYPRLAND_INSTANCE_SIGNATURE=inherited, TEST_RUNTIME=str(runtime))
            result = subprocess.run(
                ["bash", "-uc", 'runtime=$TEST_RUNTIME; resolve_hyprland_session() {' + body
                 + '\n}\nresolve_hyprland_session\nprintf "%s" "$HYPRLAND_INSTANCE_SIGNATURE"'],
                env=env, capture_output=True, text=True, check=True)
            return result.stdout

    def test_stale_signature_is_replaced_by_the_live_display_session(self):
        self.assertEqual(self.select([("new-session", os.getpid(), "wayland-1")]), "new-session")

    def test_other_display_and_dead_sessions_do_not_win(self):
        self.assertEqual(self.select([
            ("a-dead", 999999999, "wayland-1"),
            ("b-other-display", os.getpid(), "wayland-2"),
            ("c-current", os.getpid(), "wayland-1"),
        ]), "c-current")

    def test_missing_matching_session_preserves_the_environment(self):
        self.assertEqual(self.select([("unrelated", os.getpid(), "wayland-2")]), "old-session")
        self.assertEqual(self.select([]), "old-session")

    def test_absolute_display_path_matches_its_socket_name(self):
        self.assertEqual(self.select([("new-session", os.getpid(), "wayland-1")],
                                     display="/run/user/1000/wayland-1"), "new-session")

    def test_no_display_keeps_the_inherited_signature(self):
        self.assertEqual(self.select([("new-session", os.getpid(), "wayland-1")], display=""),
                         "old-session")


class Supervise(unittest.TestCase):
    def run_with(self, codes):
        tmp = Path(self.enterContext(tempfile.TemporaryDirectory()))
        scripts = tmp / "shell/scripts"
        scripts.mkdir(parents=True)
        shutil.copy(SUPERVISE, scripts / "supervise.sh")
        (scripts / "settings_migrate.py").write_text("")
        (tmp / "shell/shell.qml").write_text("")
        (tmp / "codes.txt").write_text("".join(f"{c}\n" for c in codes))
        bin_ = tmp / "bin"
        bin_.mkdir()
        (bin_ / "qs").write_text(FAKE_QS)
        (bin_ / "notify-send").write_text('#!/usr/bin/env bash\necho "$*" >> "$SANDBOX/toasts"\n'
                                          '[[ $1 == -p ]] && wc -l < "$SANDBOX/toasts"\n')
        (bin_ / "makoctl").write_text('#!/usr/bin/env bash\n[[ $1 == dismiss ]] && echo "$3" >> "$SANDBOX/dismissed"\n')
        for f in bin_.iterdir():
            f.chmod(0o755)
        (tmp / "run").mkdir()
        env = {k: v for k, v in os.environ.items() if k != "WAYLAND_DISPLAY"}
        env.update(PATH=f"{bin_}:{env['PATH']}", SANDBOX=str(tmp), XDG_RUNTIME_DIR=str(tmp / "run"))
        r = subprocess.run(["bash", str(scripts / "supervise.sh")], env=env, timeout=30)
        calls = (tmp / "qs.calls").read_text().splitlines()
        toasts = (tmp / "toasts").read_text().splitlines() if (tmp / "toasts").exists() else []
        time.sleep(0.2)   # the settle check of the last start may still be writing
        self.dismissed = (tmp / "dismissed").read_text().split() if (tmp / "dismissed").exists() else []
        return r.returncode, len(calls), toasts

    def test_a_kill_ends_it(self):
        self.assertEqual(self.run_with([143]), (0, 1, []))

    def test_a_config_error_is_one_toast_and_a_retry_on_a_fix(self):
        code, starts, toasts = self.run_with([255, 255, 0])
        self.assertEqual((code, starts), (0, 3))
        self.assertEqual(len(toasts), 1)
        self.assertIn("config has an error", toasts[0])
        self.assertIn("Nope is not a type", toasts[0])
        self.assertNotIn("crashing", toasts[0])

    def test_its_toasts_go_once_the_shell_stays_up(self):
        code, starts, toasts = self.run_with([255, "up"])
        self.assertEqual((code, starts, len(toasts)), (0, 2, 1))
        self.assertEqual(self.dismissed, ["1"])

    def test_a_config_error_toast_stays_while_it_fails(self):
        self.run_with([255, 255, 0])
        self.assertEqual(self.dismissed, [])

    def test_five_crashes_stop_it(self):
        code, starts, toasts = self.run_with([139] * 6)
        self.assertEqual((code, starts), (1, 5))
        self.assertEqual(len(toasts), 1)
        self.assertIn("keeps crashing", toasts[0])


if __name__ == "__main__":
    unittest.main()
