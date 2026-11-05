"""Kimmy: the ball made in a windowless Quickshell and given reactions (priority holds,
nothing logs a QML error), the run / mumble helpers of steer.js, the moods, decisions and
throw / stroke physics of mind.js and the looks of eyes.js."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.qml_runtime import SHELL, run_quickshell

FIXTURE = '''import QtQuick
import Quickshell
import qs.apps.companion
import "apps/companion/steer.js" as Steer
import "apps/companion/mind.js" as Mind
import "apps/companion/eyes.js" as Eyes

Scope {
  id: root
  Timer { interval: 50; running: true; onTriggered: {
    const ball = Qt.createQmlObject('import QtQuick; import qs.apps.companion; CompanionBall { size: 22 }', root, "ball");
    const out = {};
    ball.pointerNear = true; ball.pointerX = 0.8; ball.pointerY = -0.3;
    out.gaze = [ball.gazeX, ball.gazeY];
    ball.react("happy"); out.happy = ball.mood;
    ball.react("curious"); out.curiousCut = ball.mood;
    ball.react("error"); out.error = ball.mood;
    ball.react("happy"); out.happyCut = ball.mood;
    ball.express("purr", 500); out.express = ball.mood;
    out.eyes = [Eyes.look("purr").shape, Eyes.look("dizzy").shape, Eyes.look("smug").top, Eyes.look("nothing").rotL];
    // moods: a poke from a grumpy one is a huff, from a fond one a giggle; drift goes home
    const fond = { energy: 0.7, affection: 0.9, curiosity: 0.5, grumpy: 0 };
    const cross = { energy: 0.7, affection: 0.1, curiosity: 0.5, grumpy: 0.8 };
    out.pokes = [Mind.pokeReply(fond, 1, 0.5), Mind.pokeReply(cross, 1, 0.5), Mind.pokeReply(fond, 6, 0.5)];
    out.throws = [Mind.throwReply(fond, 0.2, 0.5), Mind.throwReply(cross, 0.2, 0.5), Mind.throwReply(fond, 0.95, 0.1)];
    out.trick = Mind.trickKind(fond, "flip", 0.01);
    const d = Mind.drift({ energy: 0, affection: 0, curiosity: 0, grumpy: 1 }, Mind.baseFor("playful"), 10000, 240);
    out.drift = [d.energy, d.grumpy];
    out.nudge = Mind.nudge({ energy: 0.5, affection: 0.99, curiosity: 0.5, grumpy: 0.01 }, "stroke").affection;
    // a throw: it flies, hits the wall, comes back, lands and stops inside the walls
    const s = { x: 100, y: 100, vx: 3000, vy: 0, z: 0, vz: 600 };
    let walls = 0, grounds = 0, frames = 0;
    while (!s.done && frames < 2000) { const ev = Mind.fly(s, 1 / 60, { x0: 20, x1: 800, y0: 20, y1: 600 }); if (ev.wall) walls++; if (ev.ground) grounds++; frames++; }
    out.fly = { walls: walls, grounds: grounds, frames: frames, x: s.x, z: s.z };
    out.vel = Mind.velocity([{ x: 0, y: 0, t: 0 }, { x: 50, y: 0, t: 50 }, { x: 100, y: 0, t: 100 }], 110, 90, 70);
    out.velStill = Mind.velocity([{ x: 0, y: 0, t: 0 }, { x: 100, y: 0, t: 100 }], 400, 90, 70);
    // strokes: back and forth gives beats, a single pass gives none
    const st = {}; let beats = 0;
    for (let i = 0; i < 60; i++) beats += Math.abs(Mind.stroke(st, Math.abs((i % 20) - 10) * 3, i * 16, 12));
    const pass = {}; let passBeats = 0;
    for (let i = 0; i < 30; i++) passBeats += Math.abs(Mind.stroke(pass, i * 3, i * 16, 12));
    out.strokes = [beats, passBeats];
    let same = 0, lastA = "";
    for (let i = 0; i < 200; i++) { const a = Mind.pickWeighted(Mind.actWeights(fond, 100, 1, false), [lastA]); if (a === lastA) same++; lastA = a; }
    out.actRepeats = same;
    const hs = Mind.hideSpot(50, 500, 1920, 1080, 20);
    out.hide = [hs.side, hs.x < 0];
    let jitterOk = true;
    for (let i = 0; i < 100; i++) { const j = Mind.jitter(1000, 0.3); if (!(j > 0)) jitterOk = false; }
    out.jitter = jitterOk;
    // the run: it reaches a far goal, slows into it, never overshoots far
    let p = { x: 0, y: 0, vx: 0, vy: 0, dist: 0 }, top = 0, over = 0;
    for (let i = 0; i < 600; i++) {
      p = Steer.step(p.x, p.y, p.vx, p.vy, 400, 300, 1 / 60, 500, 6, 9);
      top = Math.max(top, Math.hypot(p.vx, p.vy));
      over = Math.max(over, p.x - 400);
    }
    out.run = { x: p.x, y: p.y, top: top, over: over, still: Math.hypot(p.vx, p.vy) };
    const so = Steer.standOff(100, 100, 300, 100, 50);
    out.standOff = [so.x, so.y];
    const orb = Steer.orbit(100, 100, 50, 0);
    out.orbit = [orb.x, orb.y];
    out.clamp = [Steer.clamp(5, 10, 20), Steer.clamp(15, 10, 20), Steer.clamp(25, 10, 20)];
    let repeats = 0, last = "";
    for (let i = 0; i < 200; i++) { const w = Steer.pick(Steer.phrases.idle, last); if (w === last) repeats++; last = w; }
    out.repeats = repeats;
    const A = { x: 64, y: 0, w: 1536, h: 864 }, B = { x: 1600, y: 0, w: 1920, h: 1080 };
    const ab = Steer.edgeExit(A, B, 500, 1500, 21), ba = Steer.edgeExit(B, A, 1000, 1700, 21);
    out.edge = [ab.side, ab.ex, ab.ey, ab.nx > 1600, ba.side, ba.ex, ba.ey < 864 && ba.ey > 0, ba.nx < 1600];
    out.screenAt = [Steer.screenAt([A, B], 100, 100).w, Steer.screenAt([A, B], 3000, 900).w, Steer.screenAt([A, B], 100, 900)];
    // monitors that overlap in the layout (as on this machine): the walls open where a screen lies behind
    const rb = Steer.reachBounds(A, [B], 1400, 400, 20), rt = Steer.reachBounds(A, [], 1400, 400, 20);
    out.reach = [rb.x0, rb.x1, rb.y0, rb.y1, rt.x1];
    out.coax = [Steer.coax(40, 60, 1, 21), Steer.coax(40, 400, 1, 21), Steer.coax(40, 60, -1, 21), Steer.coax(400, 60, 1, 21)];
    out.clean = [Steer.cleanLine("«Кимми: привет, друг!»\nлишнее"), Steer.cleanLine("hello there"), Steer.cleanLine("см. https://x.y"), Steer.cleanLine("   "),
                 Steer.cleanLine("а" + " слово".repeat(30)).length <= 81, Steer.witPrompt("факт").indexOf("факт") > 0];
    out.kinds = Object.keys(Steer.phrases);
    console.warn("BALL_RESULT:" + JSON.stringify(out));
    Qt.quit();
  } }
}
'''


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class CompanionBall(unittest.TestCase):
    def test_reactions(self):
        with tempfile.TemporaryDirectory(prefix="shell-companion-") as tmp:
            root = Path(tmp)
            shutil.copytree(SHELL, root, dirs_exist_ok=True, ignore=shutil.ignore_patterns("__pycache__"))
            shutil.copy(SHELL.parent.parent.parent / "themes/gruvbox/quickshell/shell/config/Colors.qml", root / "config/Colors.qml")
            (root / "shell.qml").write_text(FIXTURE)
            output = run_quickshell(root, timeout=30)
        line = [l.split("BALL_RESULT:", 1)[1] for l in output.splitlines() if "BALL_RESULT:" in l]
        self.assertEqual(len(line), 1, output)
        r = json.loads(line[0])
        self.assertEqual(r["happy"], "happy")
        self.assertEqual(r["curiousCut"], "happy")       # a weaker reaction cannot cut a stronger one
        self.assertEqual(r["error"], "error")
        self.assertEqual(r["happyCut"], "error")
        self.assertGreater(r["gaze"][0], 0.5)            # the gaze goes to the pointer
        self.assertEqual(r["express"], "purr")
        self.assertEqual(r["eyes"], ["arc", "spiral", 0.46, -24])
        self.assertEqual(r["pokes"], ["playful", "offended", "dizzy"])
        self.assertEqual(r["throws"], ["delighted", "grumpy", "dizzy"])
        self.assertNotEqual(r["trick"], "flip")          # never the same trick twice
        self.assertAlmostEqual(r["drift"][0], 0.62, delta=0.01)
        self.assertAlmostEqual(r["drift"][1], 0.18, delta=0.01)
        self.assertLessEqual(r["nudge"], 1)
        fly = r["fly"]
        self.assertGreaterEqual(fly["walls"], 1)         # it bounced off the wall
        self.assertGreaterEqual(fly["grounds"], 1)
        self.assertLess(fly["frames"], 2000)             # and came to rest
        self.assertTrue(20 <= fly["x"] <= 800)
        self.assertEqual(fly["z"], 0)
        self.assertAlmostEqual(r["vel"]["vx"], 1000, delta=1)
        self.assertEqual(r["velStill"]["vx"], 0)         # stopped before letting go: put down, not thrown
        self.assertGreater(r["strokes"][0], 3)
        self.assertEqual(r["strokes"][1], 0)
        self.assertEqual(r["actRepeats"], 0)
        self.assertEqual(r["hide"], ["left", True])
        self.assertTrue(r["jitter"])
        run = r["run"]
        self.assertAlmostEqual(run["x"], 400, delta=1)
        self.assertAlmostEqual(run["y"], 300, delta=1)
        self.assertLessEqual(run["top"], 520)
        self.assertLess(run["over"], 25)                 # an overshoot, but a small one
        self.assertLess(run["still"], 1)                 # and it comes to rest
        self.assertEqual(r["standOff"], [150, 100])      # on the side it comes from
        self.assertEqual(r["orbit"], [150, 100])
        self.assertEqual(r["clamp"], [10, 15, 20])
        # a slow hand coming close coaxes it; a fast one, one moving away or a far one does not
        self.assertGreater(r["coax"][0], 0.35)
        self.assertEqual(r["coax"][1:], [0, 0, 0])
        # B lies behind A's right edge: the wall opens to B's far side; alone, A keeps its own walls
        self.assertEqual(r["reach"][:4], [20, 3436, 20, 844])
        self.assertEqual(r["reach"][4], 1516)
        # the model's line: first line, no quotes or name, Russian only, no links, short
        self.assertEqual(r["clean"], ["привет, друг!", "", "", "", True, True])
        self.assertEqual(r["repeats"], 0)                # never the same mumble twice in a row
        # the border between two monitors: leaves by the right side on the shared edge, enters inside the other
        self.assertEqual(r["edge"], ["right", 1600, 500, True, "left", 1600, True, True])
        self.assertEqual(r["screenAt"], [1536, 1920, None])
        for kind in ("hello", "idle", "bored", "out", "pester", "happy", "yawn", "zzz", "back", "purr", "thrown", "again", "pokeMad", "caught", "boo"):
            self.assertIn(kind, r["kinds"])
        for bad in ("TypeError", "ReferenceError", "Binding loop", "is not a function"):
            self.assertNotIn(bad, output)


if __name__ == "__main__":
    unittest.main()
