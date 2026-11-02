import QtQuick
import QtTest
import qs.kit

Item {
  TestIslandLiveSelection { id: selection }

  TestCase {
    name: "IslandLiveSelection"

    function init() {
      selection.activities = ["timer", "music", "vpn"];
      selection.flashKind = "";
      selection.liveViews = ({});
    }

    function test_wheel_choice_is_per_screen() {
      selection.liveStep(1, "HDMI-A-1");
      compare(selection.liveFor("HDMI-A-1"), "music");
      compare(selection.liveFor("eDP-1"), "timer");
    }

    function test_activity_reordering_keeps_the_selected_id() {
      selection.liveStep(1, "HDMI-A-1");
      selection.activities = ["vpn", "timer", "music"];
      compare(selection.liveFor("HDMI-A-1"), "music");
    }

    function test_flash_temporarily_overlays_the_selection() {
      selection.liveStep(1, "HDMI-A-1");
      selection.activities = ["timer", "music", "volume"];
      selection.flashKind = "volume";
      compare(selection.liveFor("HDMI-A-1"), "volume");
      selection.flashKind = "";
      compare(selection.liveFor("HDMI-A-1"), "music");
    }

    function test_wheel_direction_is_per_screen() {
      selection.liveStep(-1, "HDMI-A-1");
      selection.liveStep(1, "eDP-1");
      compare(selection.liveDirection("HDMI-A-1"), -1);
      compare(selection.liveDirection("eDP-1"), 1);
    }
  }
}
