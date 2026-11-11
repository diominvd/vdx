import QtQuick
import QtTest
import qs.config
import qs.kit

Item {
  TestIslandNoticeQueue { id: queue }

  TestCase {
    name: "IslandLiveNoticeQueue"

    function cleanup() { ShellSettings.setLook("liveNoticeMs", 5000, "island"); }

    function init() {
      ShellSettings.setLook("liveNoticeMs", 5000, "island");
      queue.noticeQueue = [];
      queue.noticeItem = null;
      queue.markedSeen = 0;
    }

    function notice(key, urgency, body) {
      return { key: key, app: "Chat", summary: "Message", body: body ?? "Hello", urgency: urgency, time: 1 };
    }

    function test_critical_notice_preempts_and_restores_previous_order() {
      queue.noticeItem = notice("a", "normal");
      queue.noticeQueue = [notice("b", "normal")];
      queue.enqueueLiveNotices([notice("c", "critical")]);
      compare(queue.noticeItem.key, "c");
      compare(queue.noticeQueue.length, 2);
      compare(queue.noticeQueue[0].key, "a");
      compare(queue.noticeQueue[1].key, "b");
      queue.showNextLiveNotice(false);
      compare(queue.noticeItem.key, "a");
      queue.showNextLiveNotice(false);
      compare(queue.noticeItem.key, "b");
    }

    function test_identical_notices_increment_the_visible_count() {
      queue.noticeItem = notice("a", "normal");
      queue.enqueueLiveNotices([notice("b", "normal")]);
      compare(queue.noticeItem.repeats, 2);
      compare(queue.noticeQueue.length, 0);
    }

    function test_replacement_updates_a_queued_notice_in_place() {
      queue.noticeItem = notice("current", "critical");
      queue.noticeQueue = [notice("same-id", "normal", "Old text")];
      queue.enqueueLiveNotices([notice("same-id", "normal", "Updated text")]);
      compare(queue.noticeQueue.length, 1);
      compare(queue.noticeQueue[0].body, "Updated text");
    }

    function test_critical_items_are_first_when_the_slot_is_empty() {
      queue.enqueueLiveNotices([notice("ordinary", "normal"), notice("critical", "critical")]);
      compare(queue.noticeItem.key, "critical");
      compare(queue.noticeQueue.length, 1);
      compare(queue.noticeQueue[0].key, "ordinary");
    }

    function test_held_notifications_show_latest_without_backlog() {
      ShellSettings.setLook("liveNoticeMs", 0, "island");
      for (let i = 0; i < 100; i++)
        queue.enqueueLiveNotices([notice("message-" + i, "normal", "Body " + i)]);
      compare(queue.noticeItem.key, "message-99");
      compare(queue.noticeQueue.length, 0);
      verify(!queue.timerRunning);
      queue.dismissLiveNotice();
      compare(queue.noticeItem, null);
      compare(queue.noticeQueue.length, 0);
      compare(queue.markedSeen, 1);
      queue.enqueueLiveNotices([notice("new", "normal", "After dismissal")]);
      compare(queue.noticeItem.key, "new");
    }

    function test_held_batch_keeps_latest_critical() {
      ShellSettings.setLook("liveNoticeMs", 0, "island");
      queue.enqueueLiveNotices([notice("first", "normal"), notice("urgent", "critical"),
        notice("ordinary", "normal", "Later"), notice("latest-urgent", "critical", "Latest"),
        notice("last", "normal", "Last")]);
      compare(queue.noticeItem.key, "latest-urgent");
      compare(queue.noticeQueue.length, 0);
      verify(!queue.timerRunning);
    }

    function test_held_dismissal_clears_existing_timed_backlog() {
      queue.enqueueLiveNotices([notice("first", "normal"), notice("second", "normal", "Different")]);
      compare(queue.noticeQueue.length, 1);
      ShellSettings.setLook("liveNoticeMs", 0, "island");
      queue.dismissLiveNotice();
      compare(queue.noticeItem, null);
      compare(queue.noticeQueue.length, 0);
      verify(!queue.timerRunning);
      compare(queue.markedSeen, 1);
    }
  }
}
