"""The display backend: a monitor moves only where it overlaps nothing, and an
old display.json (scales only) still restores."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parent.parent / "packages/quickshell/shell/scripts"
sys.path.insert(0, str(SCRIPTS))   # display.py imports backend.py from its folder
SCRIPT = SCRIPTS / "display.py"
spec = importlib.util.spec_from_file_location("display", SCRIPT)
display = importlib.util.module_from_spec(spec)
spec.loader.exec_module(display)


def mon(name, x, y, width=1920, height=1080, scale=1.0, modes=("1920x1080@60.00Hz", "1920x1080@144.00Hz", "1280x720@120.00Hz")):
    return {"name": name, "x": x, "y": y, "width": width, "height": height,
            "scale": scale, "refreshRate": 60.0, "disabled": False, "availableModes": list(modes)}


def run(fn, *args):
    """Call a command, return what it printed and its exit code."""
    buf = io.StringIO()
    code = 0
    with contextlib.redirect_stdout(buf):
        try:
            fn(*args)
        except SystemExit as e:
            code = e.code
    return json.loads(buf.getvalue()), code


class Position(unittest.TestCase):
    def setUp(self):
        # a 1920-wide laptop at scale 1.2 (1600 logical px) and a 1920 monitor to its right
        self.monitors = [mon("eDP-1", 0, 0, scale=1.2), mon("HDMI-A-2", 1600, 0)]
        self.applied = []
        self.tmp = tempfile.TemporaryDirectory()
        self.state = Path(self.tmp.name) / "display.json"
        patches = [
            mock.patch.object(display, "monitors", side_effect=lambda: self.monitors),
            mock.patch.object(display, "apply", side_effect=lambda m, scale=None, pos=None: self.applied.append((m["name"], pos))),
            mock.patch.object(display, "STATE", self.state),
        ]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        self.addCleanup(self.tmp.cleanup)

    def test_overlap_is_refused_and_nothing_applied(self):
        out, code = run(display.cmd_position, "HDMI-A-2", "1000", "0")
        self.assertEqual((out["ok"], code), (False, 1))
        self.assertIn("eDP-1", out["error"])
        self.assertEqual(self.applied, [])

    def test_touching_edges_are_allowed_and_saved(self):
        out, code = run(display.cmd_position, "HDMI-A-2", "1600", "0")
        self.assertEqual((out["ok"], code), (True, 0))
        self.assertEqual(self.applied, [("HDMI-A-2", (1600, 0))])
        self.assertEqual(json.loads(self.state.read_text())["positions"], {"HDMI-A-2": [1600, 0]})

    def test_scale_that_overlaps_moves_the_monitor_beside_its_neighbour(self):
        # eDP-1 at 0x0 is 1600 logical px wide at 1.2; at 1.0 it would reach 1920, over HDMI-A-2 at 1600,
        # so it moves left to end at HDMI-A-2's left edge (x = 1600 - 1920)
        out, code = run(display.cmd_scale, "eDP-1", "1.0")
        self.assertEqual((out["ok"], code), (True, 0))
        self.assertEqual(self.applied, [("eDP-1", (-320, 0))])
        self.assertEqual(json.loads(self.state.read_text())["positions"], {"eDP-1": [-320, 0]})

    def test_scale_that_fits_is_applied(self):
        out, code = run(display.cmd_scale, "eDP-1", "1.25")   # 1536 px wide, touching HDMI-A-2's edge at 1600
        self.assertEqual((out["ok"], code), (True, 0))
        self.assertEqual(self.applied, [("eDP-1", None)])

    def test_logical_size_follows_scale(self):
        self.assertEqual(display.logical(self.monitors[0]), (0, 0, 1600, 900))

    def test_saved_lua_reapplies_layout_and_exact_rate_on_reload(self):
        self.monitors[1]["availableModes"] = ["1920x1080@143.987Hz"]
        display.save({"scales": {"HDMI-A-2": 1.25},
                      "rates": {"HDMI-A-2": 143.99},
                      "positions": {"HDMI-A-2": [1600, -200]}})
        rules = self.state.with_suffix(".lua").read_text()
        self.assertIn('mode = "1920x1080@143.987"', rules)
        self.assertIn('position = "1600x-200", scale = 1.25', rules)
        self.assertNotIn('output = "eDP-1"', rules)
        self.assertFalse(self.state.with_suffix(".lua.tmp").exists())
        lua = shutil.which("lua")
        if not lua:
            self.skipTest("Lua runtime unavailable")
        home = Path(self.tmp.name) / "home"
        target = home / ".local/state/dotfiles/display.lua"
        target.parent.mkdir(parents=True)
        target.write_text(rules)
        config = SCRIPTS.parents[2] / "hypr/components/monitors.lua"
        fixture = """
package.preload['components.machine'] = function() return {load=function() return false end} end
local last
hl = {monitor=function(rule) last = rule end}
for i=1,3 do
 dofile(arg[1])
 assert(last.output == 'HDMI-A-2')
 assert(last.mode == '1920x1080@143.987')
 assert(last.position == '1600x-200' and last.scale == 1.25)
end
"""
        script = home / "test.lua"
        script.write_text(fixture)
        result = subprocess.run([lua, str(script), str(config)],
                                env=os.environ | {"HOME": str(home)}, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_old_state_without_positions_loads(self):
        self.state.write_text(json.dumps({"scales": {"eDP-1": 1.25}}))
        self.assertEqual(display.saved(), {"scales": {"eDP-1": 1.25}, "rates": {}, "positions": {}})


class Rate(unittest.TestCase):
    def setUp(self):
        self.monitors = [mon("HDMI-A-2", 0, 0)]
        self.applied = []
        self.tmp = tempfile.TemporaryDirectory()
        self.state = Path(self.tmp.name) / "display.json"
        patches = [
            mock.patch.object(display, "monitors", side_effect=lambda: self.monitors),
            mock.patch.object(display, "apply", side_effect=lambda m, scale=None, pos=None, rate=None: self.applied.append((m["name"], rate))),
            mock.patch.object(display, "STATE", self.state),
        ]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        self.addCleanup(self.tmp.cleanup)

    def test_choices_are_the_rates_at_the_current_resolution(self):
        self.assertEqual(display.refresh_choices(self.monitors[0]), [144.0, 60.0])

    def test_own_rate_is_always_a_choice(self):
        m = mon("X", 0, 0, modes=())
        self.assertEqual(display.refresh_choices(m), [60.0])

    def test_offered_rate_is_applied_and_saved(self):
        out, code = run(display.cmd_rate, "HDMI-A-2", "144")
        self.assertEqual((out["ok"], code), (True, 0))
        self.assertEqual(self.applied, [("HDMI-A-2", 144.0)])
        self.assertEqual(json.loads(self.state.read_text())["rates"], {"HDMI-A-2": 144.0})

    def test_rate_not_offered_is_refused(self):
        out, code = run(display.cmd_rate, "HDMI-A-2", "120")
        self.assertEqual((out["ok"], code), (False, 1))
        self.assertEqual(self.applied, [])

    def test_restore_applies_saved_rate_only_when_offered(self):
        self.state.write_text(json.dumps({"rates": {"HDMI-A-2": 144.0}}))
        run(display.cmd_restore)
        self.assertEqual(self.applied, [("HDMI-A-2", 144.0)])
        self.applied.clear()
        self.state.write_text(json.dumps({"rates": {"HDMI-A-2": 120.0}}))
        run(display.cmd_restore)
        self.assertEqual(self.applied, [("HDMI-A-2", None)])


class Mode(unittest.TestCase):
    def test_scale_keeps_the_exact_rate_so_nothing_is_modeset(self):
        m = mon("eDP-1", 0, 0)
        m["refreshRate"] = 144.00301          # what Hyprland reports for this panel
        ok = mock.Mock(returncode=0, stdout="", stderr="")
        with mock.patch.object(display, "run_or_fail", return_value=ok) as eval_, \
             mock.patch.object(display, "run", return_value=None):
            display.apply(m, scale=1.25)
        lua = eval_.call_args[0][0][-1]
        self.assertIn('mode = "1920x1080@144.00301"', lua)

    def test_saved_rounded_rate_resolves_to_exact_offered_mode(self):
        m = mon("DP-1", 0, 0, modes=("1920x1080@143.987Hz",))
        self.assertEqual(display.exact_rate(m, 143.99), 143.987)
        self.assertEqual(display.exact_rate(m, 120), 60.0)

    def test_apply_never_restores_awww_cache(self):
        # awww restore redraws the cached picture, not the chosen one (the shell redraws)
        ok = mock.Mock(returncode=0, stdout="", stderr="")
        with mock.patch.object(display, "run_or_fail", return_value=ok), \
             mock.patch.object(display, "run") as run_:
            display.apply(mon("eDP-1", 0, 0), scale=1.25)
        run_.assert_not_called()


if __name__ == "__main__":
    unittest.main()
