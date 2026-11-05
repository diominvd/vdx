"""Small guards for costly UI that must exist only while its surface is open."""
from pathlib import Path
import unittest


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


if __name__ == "__main__":
    unittest.main()
