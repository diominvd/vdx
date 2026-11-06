"""Run production process grouping/tree functions with synthetic rows only."""
from __future__ import annotations

import json
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.check_shell_ui import qml_function
from tests.qml_runtime import SHELL, run_quickshell


def process(pid, name, ppid=0, user="one", mine=True, kernel=False):
    return dict(pid=pid, ppid=ppid, name=name, user=user, mine=mine, kernel=kernel,
                cpu=2, mem=10, threads=1, cmd=name + " --test")


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class TaskManagerView(unittest.TestCase):
    def view(self, procs, query="", only_mine=False):
        source = (SHELL / "apps/taskmanager/TaskManagerService.qml").read_text()
        with tempfile.TemporaryDirectory(prefix="shell-tasks-") as tmp:
            root = Path(tmp)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
Scope {
  QtObject {
    id: model
    property var procs: ''' + json.dumps(procs) + '''
    property string query: ''' + json.dumps(query) + '''
    property bool kernel: false
    property bool onlyMine: ''' + str(only_mine).lower() + '''
    property string sortBy: "name"
''' + qml_function(source, "build") + '\n' + qml_function(source, "treePids") + '''
  }
  Component.onCompleted: {
    console.warn("TASKS_RESULT:" + JSON.stringify({rows: model.build(true), tree: model.treePids(1)}));
    Qt.quit();
  }
  Timer { interval: 1000; running: true; onTriggered: Qt.quit() }
}
''')
            output = run_quickshell(root)
            lines = [line.split("TASKS_RESULT:", 1)[1] for line in output.splitlines() if "TASKS_RESULT:" in line]
            self.assertEqual(len(lines), 1, output)
            return json.loads(lines[0])

    def test_process_names_do_not_collide_with_object_prototype(self):
        names = ["constructor", "toString", "__proto__"]
        rows = self.view([process(i + 1, name) for i, name in enumerate(names)])["rows"]
        self.assertEqual({row["name"] for row in rows}, set(names))
        self.assertTrue(all(row["count"] == 1 for row in rows))

    def test_groups_aggregate_resources_and_apply_filters(self):
        procs = [process(1, "editor"), process(2, "editor", user="two", mine=False),
                 process(3, "hidden", kernel=True)]
        rows = self.view(procs)["rows"]
        self.assertEqual(len(rows), 1)
        self.assertEqual((rows[0]["count"], rows[0]["cpu"], rows[0]["mem"], rows[0]["user"]),
                         (2, 4, 20, "—"))
        self.assertEqual(self.view(procs, only_mine=True)["rows"][0]["pids"], [1])
        self.assertEqual(self.view(procs, query="2")["rows"][0]["pids"], [2])

    def test_tree_handles_cycles_and_shared_ancestors_once(self):
        result = self.view([process(1, "parent", ppid=3), process(2, "child", ppid=1),
                            process(3, "cycle", ppid=2), process(4, "other")])
        self.assertEqual(result["tree"], [1, 2, 3])
