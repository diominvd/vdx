"""Small guards for costly UI that must exist only while its surface is open."""
from pathlib import Path
import shutil
import tempfile
import unittest

from tests.check_shell_ui import qml_function
from tests.qml_runtime import run_quickshell


SHELL = Path(__file__).resolve().parent.parent / "packages/quickshell/shell"


class IslandHubLifecycle(unittest.TestCase):
    source = (SHELL / "bar/island/IslandHub.qml").read_text()

    def test_hidden_hub_does_not_instantiate_blocks_or_query_block_services(self):
        self.assertIn(
            "root.built ? HubBlocks.order.filter(id => HubBlocks.shown(id) && wants(id)) : []",
            self.source,
        )
        self.assertIn(
            "active: root.built && HubBlocks.shown(modelData) && root.wants(modelData)",
            self.source,
        )

    def test_hub_stays_built_under_a_popup_opened_from_it(self):
        # the popup belongs to the tile or chip: the hub's fade must not take it along
        self.assertIn("readonly property bool built: visible || keep", self.source)
        island = (SHELL / "bar/island/Island.qml").read_text()
        self.assertIn("keep: root.fromHub && root.popup !== null", island)

    def test_hub_keeps_no_hosts_of_its_own_for_module_popups(self):
        # a module popup comes up by id (BarLayout.openModule), made by the bar on demand
        for host in ("musicHost", "mediaHost", "tunerHost"):
            self.assertNotIn(f"id: {host}", self.source)
        self.assertIn("BarLayout.openModule(", self.source)


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class HubPopupRouting(unittest.TestCase):
    def test_hub_owns_child_module_popup_and_keeps_its_return_route(self):
        source = (SHELL / "bar/Bar.qml").read_text()
        island = (SHELL / "bar/island/Island.qml").read_text()
        with tempfile.TemporaryDirectory(prefix="hub-popup-route-") as tmp:
            root = Path(tmp)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
Scope {
  id: root
  property QtObject islandItem: QtObject { property string view: "hub" }
  property string view: "hub"
  property bool fromHub: false
  property bool pinned: false
  property string flash: ""
  property var popup: null
  Timer { id: restoreTimer }
  QtObject { id: moduleHost; function attach(p) { root.popup = p; } }
  QtObject { id: fakePopup; property bool visible: true; property var originHost: null }
  QtObject { id: otherPopup; property bool visible: true; property var originHost: null }
  Item { id: moduleSlot }
  Item { id: child; property bool hostsPopups: true; Item { id: face } }
  Item { id: detached }
  ''' + qml_function(source, "popupHost")
                + qml_function(island, "showPopup") + qml_function(island, "backToHub") + '''
  Timer { interval: 1; running: true; onTriggered: {
    if (popupHost(face) !== islandItem) throw new Error("Hub action opened in child island");
    // The Hub may already have collapsed by the time its popup appears.
    view = "compact";
    fakePopup.originHost = root;
    showPopup(fakePopup);
    if (!fromHub || view !== "module" || !pinned) throw new Error("Hub back bubble was lost");
    fakePopup.originHost = null;
    showPopup(fakePopup);
    if (!fromHub) throw new Error("Repeated showPopup erased the Hub return route");
    backToHub();
    if (view !== "hub" || fakePopup.visible) throw new Error("Back did not restore Hub and close popup");
    view = "compact";
    showPopup(otherPopup);
    if (fromHub) throw new Error("A new bar popup inherited an unrelated Hub return route");
    islandItem.view = "compact";
    if (popupHost(face) !== child) throw new Error("Child bar lost its own popup host");
    if (popupHost(detached) !== islandItem) throw new Error("Unplaced module lost main island");
    console.warn("HUB_POPUP_ROUTE_OK"); Qt.quit();
  } }
}
''')
            self.assertIn("HUB_POPUP_ROUTE_OK", run_quickshell(root))

    def test_player_origin_reaches_existing_and_lazy_popups(self):
        source = (SHELL / "bar/BarLayout.qml").read_text()
        with tempfile.TemporaryDirectory(prefix="hub-player-origin-") as tmp:
            root = Path(tmp)
            (root / "shell.qml").write_text('''import QtQuick
import Quickshell
Scope {
  id: root
  property var popupTargets: ({music: "player"})
  property var modules: []
  property var received: null
  property string receivedId: ""
  signal hostRequested(string id, string screen, var origin)
  onHostRequested: (id, screen, origin) => { receivedId = id; received = origin; }
  function usable(id) { return true; }
  QtObject { id: popupManager; property var owner: popup; function ipcOwner(target) { return owner; } }
  QtObject { id: popup; function openFrom(origin) { root.received = origin; } }
  QtObject { id: theme; property bool island: true }
  QtObject { id: hyprland; property var focusedMonitor: ({name: "test"}) }
  QtObject { id: shellIpc; function call(target, method, args) { throw new Error("Hub player used asynchronous IPC"); } }
  Item { id: hub }
  ''' + qml_function(source, "popupTarget") + qml_function(source, "openModule")
                .replace("PopupManager", "popupManager").replace("Theme", "theme")
                .replace("Hyprland", "hyprland").replace("ShellIpc", "shellIpc") + '''
  Timer { interval: 1; running: true; onTriggered: {
    openModule("music", hub);
    if (received !== hub) throw new Error("Existing popup lost Hub origin");
    received = null;
    popupManager.owner = null;
    openModule("music", hub);
    if (received !== hub || receivedId !== "music") throw new Error("Lazy popup lost Hub origin");
    console.warn("HUB_PLAYER_ORIGIN_OK"); Qt.quit();
  } }
}
''')
            self.assertIn("HUB_PLAYER_ORIGIN_OK", run_quickshell(root))


if __name__ == "__main__":
    unittest.main()
