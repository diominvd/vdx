import QtQuick
import QtTest
import qs.config
import qs.kit

Item {
  width: 800; height: 1000
  TestTerminalPage { id: page; width: parent.width }
  TestCase {
    name: "TerminalPage"
    when: windowShown
    function row(label) {
      return Array.from(page.children).find(c => c.label === label);
    }
    function init() {
      ShellSettings.motion = true;
      ShellSettings.motionControls = true;
      page.busy = false;
      page.calls = [];
      page.info = {selected: "zellij", default: "zellij", padding: {horizontal: 6, vertical: 6},
        zen: false, zenAvailable: true, zenChanged: false, restoreSessions: false};
      wait(Motion.normal + 80);
    }
    function test_restore_switch_requests_opposite_of_saved_value() {
      const toggle = row("Restore sessions").trailing[0];
      verify(toggle.visible);
      toggle.toggled();
      compare(page.calls[0].join(" "), "restore on");
      page.info = Object.assign({}, page.info, {restoreSessions: true});
      compare(toggle.checked, true);
      toggle.toggled();
      compare(page.calls[1].join(" "), "restore off");
    }
    function test_layout_is_final_during_row_fade_data() {
      return [{tag: "strict", material: false}, {tag: "material", material: true}];
    }
    function test_layout_is_final_during_row_fade(data) {
      ShellSettings.material = data.material;
      page.info = Object.assign({}, page.info, {selected: "none"});
      wait(Motion.normal + 40);
      page.info = Object.assign({}, page.info, {selected: "zellij"});
      wait(30);
      const zen = row("Zen mode"), restore = row("Restore sessions");
      verify(zen.visible && restore.visible);
      const positions = [zen.y, restore.y, page.height];
      for (let i = 0; i < 6; i++) {
        wait(30);
        compare(zen.y, positions[0]);
        compare(restore.y, positions[1]);
        compare(page.height, positions[2]);
      }
      verify(restore.y >= zen.y + zen.height);
      tryCompare(zen, "opacity", 1);
      tryCompare(restore, "opacity", 1);
    }
    function test_save_does_not_dim_selector() {
      const selector = row("Multiplexer").trailing[0];
      page.busy = true;
      verify(!selector.enabled);
      compare(selector.opacity, 1);
      page.busy = false;
      verify(selector.enabled);
      compare(selector.opacity, 1);
    }
  }
}
