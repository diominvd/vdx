import QtQuick
import QtTest
import qs.kit

TestCase {
  name: "TimerState"
  Component { id: factory; TestTimerState {} }

  function test_pause_samples_time_between_ticks() {
    const timer = createTemporaryObject(factory, this);
    timer.startStopwatch();
    timer.since = Date.now() - 1000;
    timer.now = timer.since;
    timer.pause();
    verify(timer.paused); verify(timer.elapsed >= 1000);
    const elapsed = timer.elapsed;
    timer.pause(); compare(timer.elapsed, elapsed);
  }

  function test_lap_samples_time_between_ticks() {
    const timer = createTemporaryObject(factory, this);
    timer.startStopwatch();
    timer.since = Date.now() - 1000;
    timer.now = timer.since;
    timer.lap();
    compare(timer.laps.length, 1); verify(timer.laps[0] >= 1000);
    timer.pause();
    timer.lap(); compare(timer.laps.length, 1);
  }

  function test_pause_after_deadline_finishes_once() {
    const timer = createTemporaryObject(factory, this);
    timer.begin("countdown", 50, "sample");
    timer.since = Date.now() - 100;
    timer.now = timer.since;
    timer.pause();
    verify(!timer.active); compare(timer.notifications.calls, 1);
    compare(timer.notifications.command[6], "sample");
    timer.finish(); compare(timer.notifications.calls, 1);
  }

  function test_finish_keeps_the_ended_state_until_restart_or_stop() {
    const timer = createTemporaryObject(factory, this);
    timer.begin("countdown", 60000, "tea");
    timer.finish();
    verify(!timer.active); verify(timer.ended);
    timer.restart();
    verify(timer.active); verify(!timer.ended); compare(timer.label, "tea");
    timer.finish(); timer.stop();
    verify(!timer.ended);
  }
}
