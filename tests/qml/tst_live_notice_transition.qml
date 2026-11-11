import QtQuick
import QtTest
import qs.config
import qs.kit

Item {
  TestIslandLiveTransition { id: live }

  TestCase {
    name: "IslandLiveNoticeTransition"

    function init() {
      ShellSettings.set("motion", true);
      ShellSettings.set("motionIsland", true);
      ShellSettings.set("motionSpeed", "normal");
      live.currentKind = "";
      live.currentNotice = null;
      live.syncFace();
      wait(0);
    }

    function cleanup() {
      live.currentKind = "";
      live.currentNotice = null;
      live.syncFace();
      ShellSettings.set("motionIsland", true);
    }

    function showFirst() {
      live.currentNotice = { key: "first", summary: "Old text" };
      live.currentKind = "notice";
      live.syncFace();
      verify(!live.sliding);
      compare(live.frontFace.notice.summary, "Old text");
    }

    function test_message_change_preserves_outgoing_text() {
      showFirst();
      live.currentNotice = { key: "second", summary: "New text" };
      live.syncFace();
      verify(live.sliding);
      compare(live.frontFace.notice.summary, "Old text");
      compare(live.backFace.notice.summary, "New text");
      tryCompare(live, "sliding", false);
      compare(live.frontFace.notice.key, "second");
      compare(live.backFace.notice, null);
      compare(live.backFace.kind, "");
    }

    function test_burst_finishes_on_latest_message() {
      showFirst();
      for (let i = 0; i < 20; i++) {
        live.currentNotice = { key: "message-" + i };
        live.syncFace();
        verify(live.sliding);
        compare(live.backFace.notice.key, "message-" + i);
      }
      tryCompare(live, "sliding", false);
      compare(live.frontFace.notice.key, "message-19");
      compare(live.backFace.notice, null);
    }

    function test_disabled_motion_updates_immediately() {
      showFirst();
      ShellSettings.set("motionIsland", false);
      live.currentNotice = { key: "second" };
      live.syncFace();
      verify(!live.sliding);
      compare(live.frontFace.notice.key, "second");
      compare(live.backFace.notice, null);
    }

    function test_activity_switch_during_notice_transition() {
      showFirst();
      live.currentNotice = { key: "second" };
      live.syncFace();
      live.currentKind = "music";
      live.syncFace();
      tryCompare(live, "sliding", false);
      compare(live.frontFace.kind, "music");
      compare(live.frontFace.notice, null);
      compare(live.backFace.notice, null);
    }
  }
}
