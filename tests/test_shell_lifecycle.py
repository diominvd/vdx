"""Small guards for costly UI that must exist only while its surface is open."""
from pathlib import Path
import unittest


SHELL = Path(__file__).resolve().parent.parent / "packages/quickshell/shell"


class IslandHubLifecycle(unittest.TestCase):
    source = (SHELL / "bar/island/IslandHub.qml").read_text()

    def test_hidden_hub_does_not_instantiate_blocks_or_query_block_services(self):
        self.assertIn(
            "root.visible ? HubBlocks.order.filter(id => HubBlocks.shown(id) && wants(id)) : []",
            self.source,
        )
        self.assertIn(
            "active: root.visible && HubBlocks.shown(modelData) && root.wants(modelData)",
            self.source,
        )

    def test_hub_keeps_no_hosts_of_its_own_for_module_popups(self):
        # a module popup comes up by id (BarLayout.openModule), made by the bar on demand
        for host in ("musicHost", "mediaHost", "tunerHost"):
            self.assertNotIn(f"id: {host}", self.source)
        self.assertIn("BarLayout.openModule(", self.source)


if __name__ == "__main__":
    unittest.main()
