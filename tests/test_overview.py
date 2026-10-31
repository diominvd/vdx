"""Overview geometry and compositor transactions, without moving desktop windows."""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from tests.qml_runtime import run_quickshell

ROOT = Path(__file__).resolve().parent.parent
LOGIC = ROOT / "packages/quickshell/shell/apps/overview/overview.js"


def window(address, workspace, width=1566, x=17):
    return dict(address=address, workspace=workspace, x=x, y=52,
                width=width, height=836, floating=False)


@unittest.skipUnless(shutil.which("node"), "node is not installed")
class OverviewGeometry(unittest.TestCase):
    def call(self, name, *args):
        program = """const fs = require('fs'), vm = require('vm'), scope = {};
vm.createContext(scope); vm.runInContext(fs.readFileSync(process.argv[1], 'utf8'), scope);
console.log(JSON.stringify(scope[process.argv[2]](...JSON.parse(process.argv[3]))));"""
        result = subprocess.run(["node", "-e", program, str(LOGIC), name, json.dumps(args)],
                                capture_output=True, text=True, check=True)
        return json.loads(result.stdout)

    def setUp(self):
        self.target = window("0x1", 1)
        self.carried = window("0x2", 3)
        self.windows = [self.target, self.carried]

    def hit(self, x, y=300, carried=None, scrolling=True):
        return self.call("intent", self.windows, [1, 2, 3, 4], carried or self.carried,
                         dict(x=x, y=y), 1600, 900, 990, 14, scrolling, 0.5, False)

    def test_wide_slot_is_next_to_window_and_keeps_width(self):
        slot = self.call("appendSlot", self.windows, 1, self.carried, 1600, 900, 14)
        self.assertEqual((slot["x"], slot["width"], slot["height"]), (1597, 1566, 836))
        self.assertEqual(slot["anchor"], "0x1")
        self.assertEqual(self.hit(2200)["kind"], "append")

    def test_narrow_slot_keeps_its_own_width(self):
        narrow = window("0x2", 3, width=510)
        slot = self.call("appendSlot", self.windows, 1, narrow, 1600, 900, 14)
        self.assertEqual(slot["width"], 510)
        self.assertEqual(self.hit(1800, carried=narrow)["kind"], "append")
        self.assertIsNone(self.hit(2200, carried=narrow))

    def test_inside_workspace_shares_space_between_both_windows(self):
        drop = self.hit(500)
        self.assertEqual(drop["kind"], "join")
        self.assertEqual(drop["existing"]["width"], 776)
        self.assertEqual(drop["width"], 776)
        self.assertEqual(drop["x"], 807)
        self.assertEqual(drop["y"], 52)
        self.assertEqual(drop["height"], 836)
        self.assertEqual(self.target["width"], 1566)

    def test_gaps_and_source_workspace_do_not_accept_drop(self):
        self.assertIsNone(self.hit(100, y=950))
        self.assertIsNone(self.hit(100, y=2280))
        self.assertIsNone(self.hit(-200))
        self.assertIsNone(self.hit(5000))
        self.assertEqual(self.hit(100, y=1300)["workspace"], 2)

    def test_slot_follows_rightmost_column_ignoring_floating_windows(self):
        self.windows += [window("0x3", 1, width=600, x=1597),
                         dict(window("0x4", 1, width=500, x=4000), floating=True)]
        slot = self.call("appendSlot", self.windows, 1, self.carried, 1600, 900, 14)
        self.assertEqual(slot["x"], 2211)
        self.assertEqual(slot["anchor"], "0x3")
        self.assertNotIn("existing", self.hit(100))

    def test_tiling_does_not_offer_scrolling_slot(self):
        self.assertIsNone(self.hit(2200, scrolling=False))
        self.assertEqual(self.hit(500, scrolling=False)["kind"], "join")

    def test_workspace_gaps_and_spare_workspaces_are_present(self):
        self.assertEqual(self.call("rows", self.windows, 1), [1, 2, 3, 4])
        self.assertEqual(self.call("rows", [window("0xa", 10)], 10), [9, 10])
        self.assertEqual(self.call("rows", [], 2), [2])

    @unittest.skipUnless(shutil.which("lua"), "lua is not installed")
    def test_compositor_applies_width_policy_and_restores_focus_even_on_error(self):
        fixture = """
local mon = { x = 0, width = 1920, scale = 1.2, reserved = {0,35,0,0}, active_workspace = { id = 1 } }
local wins = {
 ['address:0x1'] = { address = '0x1', at = {17,52}, workspace = { id = 1 }, monitor = mon },
 ['address:0x2'] = { address = '0x2', at = {17,52}, workspace = { id = 3 }, monitor = mon },
}
local active, warps, widths = wins['address:0x1'], false, {}
hl = { dsp = {window = {}} }
function hl.get_window(s) return wins[s] end
function hl.get_active_window() return active end
function hl.get_active_monitor() return mon end
function hl.get_config(k)
  if k == 'cursor.no_warps' then return warps end
  if k == 'general.gaps_out' then return {left=10, right=10} end
  if k == 'general.gaps_in' then return {left=5, right=5} end
  if k == 'general.border_size' then return 2 end
end
function hl.config(c) warps = c.cursor.no_warps end
function hl.dsp.focus(o) return {op='focus', opts=o} end
function hl.dsp.layout(msg) return {op='layout', msg=msg} end
function hl.dsp.window.move(o) return {op='move', opts=o} end
function hl.dispatch(a)
  if a.op == 'focus' then
    if a.opts.window then active=wins[a.opts.window]; mon.active_workspace=active.workspace
    else mon.active_workspace={id=a.opts.workspace} end
  elseif a.op == 'move' then
    assert(a.opts.follow == false)
    if APPEND then assert(math.abs(widths['0x1'] - 1) < 0.001, 'neighbor width was not pinned before insertion') end
    if FAIL then error('simulated compositor failure') end
    wins[a.opts.window].workspace={id=a.opts.workspace}
  elseif a.op == 'layout' then
    widths[active.address]=tonumber(a.msg:match('colresize (.*)'))
  end
end
local ok = pcall(function()
COMMAND
end)
assert(warps == false, 'cursor policy leaked')
assert(mon.active_workspace.id == 1, 'workspace changed')
assert(active.address == '0x1', 'focus changed')
if FAIL then assert(not ok) else
  assert(ok); assert(wins['address:0x2'].workspace.id == 1)
  EXPECT
end
"""
        for kind in ("append", "join"):
            command = self.call("moveCommand", self.carried,
                                dict(kind=kind, workspace=1, anchor="0x1"), self.windows, True)
            expected = ("assert(math.abs(widths['0x1'] - 1) < 0.001); assert(math.abs(widths['0x2'] - 1) < 0.001)"
                        if kind == "append" else "assert(widths['0x1'] == 0.5); assert(widths['0x2'] == 0.5)")
            for fail in (False, True):
                with self.subTest(kind=kind, fail=fail):
                    source = f"local FAIL = {str(fail).lower()}; local APPEND = {str(kind == 'append').lower()}\n" + fixture.replace("COMMAND", command).replace("EXPECT", expected)
                    result = subprocess.run(["lua", "-"], input=source, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class OverviewRuntime(unittest.TestCase):
    def run_view(self, failure=False):
        with tempfile.TemporaryDirectory(prefix="shell-overview-") as tmp:
            root = Path(tmp)
            mocks = root / "mocks"
            mocks.mkdir()
            source = LOGIC.with_name("Overview.qml").read_text()
            source = "\n".join(line for line in source.splitlines()
                               if not line.startswith("import qs.") and line != "import Quickshell.Hyprland")
            source = source.replace('import QtQuick', 'import QtQuick\nimport "mocks"', 1)
            source = source.replace('TaskView { overview: root }', 'Item { function reset() {} }')
            (root / "Overview.qml").write_text(source)
            shutil.copy(LOGIC, root / "overview.js")
            definitions = {
                "Hyprland": '''QtObject {
  id: h
  property var focusedMonitor: QtObject { property int width: 1920; property int height: 1080; property real scale: 1.2; property int x: 0; property int y: 0; property var activeWorkspace: ({id:1}) }
  property var first: QtObject { property string address: "0x1"; property string title: "First"; property var workspace: ({id:1, monitor:h.focusedMonitor}); property var wayland: null; property var lastIpcObject: ({at:[17,52], size:[1566,836], class:"first", floating:false}) }
  property var second: QtObject { property string address: "0x2"; property string title: "Second"; property var workspace: ({id:3, monitor:h.focusedMonitor}); property var wayland: null; property var lastIpcObject: ({at:[17,52], size:[1566,836], class:"second", floating:false}) }
  property var toplevels: QtObject { property var values: [h.first,h.second] }
  property var activeToplevel: first
  signal rawEvent(var event)
  function refreshToplevels() {}
}''',
                "Hypr": '''QtObject { function call(s) {} function target(t) {return t.address} function iconOf(t) {return ""} function classOf(t) {return t?.lastIpcObject?.class ?? ""} }''',
                "ModuleSettings": 'QtObject { function get(id, key, fallback) { return key === "previews" ? false : fallback } }',
                "WindowsService": '''QtObject { property string mode: "scrolling"; property var opts: ({gapsIn:5,borders:true,mfact:0.5,newStatus:"slave"}) }''',
                "ShellSettings": 'QtObject { property string wallpaperMode: "none"; property color wallpaperColor: "#101010" }',
                "Motion": '''QtObject { property bool panels:false; property bool controls:false; property int normal:1; property int slow:1; property int quick:1; property int easing:0; property int morph:0 }''',
                "Theme": '''QtObject { property color background1:"#101010"; property color background2:"#202020"; property color clear:"transparent"; property color foreground0:"#ffffff"; property color gray:"#606060"; property color muted:"#cccccc"; property color popupFrame:"#666666"; property color scrim:"#101010"; property int radiusControl:8; property int radiusCard:12; property int gapWide:16; property int gapMedium:8; property int fontSize:14; property int hairline:1; property int ring:2; function pill(h) {return h/2} }'''
            }
            qmldir = ["module mocks"]
            for name, body in definitions.items():
                (mocks / f"{name}.qml").write_text("pragma Singleton\nimport QtQuick\n" + body)
                qmldir.append(f"singleton {name} 1.0 {name}.qml")
            (mocks / "ScrimWindow.qml").write_text('''import QtQuick
Item { property bool open:false; property bool dim:true; property string namespace:""; signal dismissed(); visible:open; default property alias content:stage.data; Item {id:stage; anchors.fill:parent} }''')
            (mocks / "KitText.qml").write_text("import QtQuick\nText {}")
            qmldir += ["ScrimWindow 1.0 ScrimWindow.qml", "KitText 1.0 KitText.qml"]
            (mocks / "qmldir").write_text("\n".join(qmldir))
            fake = root / "hyprctl"
            fake.write_text(f"#!/bin/sh\nexit {1 if failure else 0}\n")
            fake.chmod(0o700)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
import "mocks"
Scope {
 id: fixture
 property var original: null
 property int tick: 0
 property bool failed: false
 function check(value, message) { if (!value) { console.warn("FAILED: " + message); failed=true; } }
 function card(item, address) {
   if (item.address === address && item.picture !== undefined) return item;
   for (const child of item.children ?? []) { const found=card(child,address); if (found) return found; }
   return null;
 }
 function point(x, y) { return Qt.point(view.width/2+(x-view.camX)*view.zoom, view.height/2+(y-view.camY)*view.zoom); }
 Window { visible:true; width:1600; height:900; Overview {id:view; anchors.fill:parent} }
 Timer { interval:70; running:true; repeat:true; onTriggered: {
   fixture.tick++;
   if (fixture.tick === 1) view.open=true;
   if (fixture.tick === 3) {
     fixture.original=fixture.card(view,"0x2");
     fixture.check(fixture.original !== null,"missing window card");
     fixture.check(view.beginDrag(fixture.original,200,100),"drag did not start");
     view.dragPos=fixture.point(2200,300);
     fixture.check(view.dropIntent?.kind === "append","right-hand slot is not hittable");
     fixture.check(view.dropIntent?.width === 1566,"wide slot lost its width");
     fixture.check(view.carriedWindow.width === 1566,"drag picture resized while hovering");
     fixture.check(fixture.card(view,"0x1").width === 1566,"append hover squeezed neighboring window");
     view.cancelDrag();
   }
   if (fixture.tick === 5) {
     fixture.check(view.dragPhase === "","cancel did not finish");
     fixture.check(view.beginDrag(fixture.original,200,100),"second drag did not start");
     view.dragPos=fixture.point(500,300);
     fixture.check(view.dropIntent?.kind === "join","workspace did not accept a pair");
     fixture.check(view.dropIntent.width === 776,"pair placeholder has wrong width");
     fixture.check(fixture.card(view,"0x1").width === 1566,"crossing a workspace squeezed its window before drop");
     view.releaseDrag();
     APPLY_MOVE
   }
   if (fixture.tick > 7 && view.dragPhase === "") {
     fixture.check(fixture.original === fixture.card(view,"0x2"),"moving recreated the captured window card");
     CHECK_MOVE
     view.open=false;
     fixture.check(fixture.card(view,"0x2") === null,"closed overview retained its cards");
     console.warn(fixture.failed ? "OVERVIEW_FAILED" : "OVERVIEW_OK"); Qt.quit();
   }
   if (fixture.tick > 40) { console.warn("OVERVIEW_TIMEOUT"); Qt.quit(); }
 }}
}'''.replace("APPLY_MOVE", "" if failure else '''Hyprland.second.workspace={id:1,monitor:Hyprland.focusedMonitor};
       Hyprland.second.lastIpcObject={at:[807,52],size:[776,836],class:"second",floating:false};
       Hyprland.first.lastIpcObject={at:[17,52],size:[776,836],class:"first",floating:false};''')
                .replace("CHECK_MOVE", 'fixture.check(view.moveError !== "","move failure was not reported");' if failure else
                         'fixture.check(view.displayRects["0x2"].workspace === 1,"drop never reached target"); fixture.check(view.displayRects["0x1"].width === 776,"pair geometry was lost");'))
            output = run_quickshell(root, environment={"PATH": str(root) + os.pathsep + os.environ["PATH"]})
            self.assertIn("OVERVIEW_OK", output, output)
            for error in ("TypeError", "ReferenceError", "FAILED:", "Binding loop"):
                self.assertNotIn(error, output, output)

    def test_drag_cancel_drop_and_card_lifetime(self):
        self.run_view()

    def test_failed_move_returns_the_card(self):
        self.run_view(failure=True)
