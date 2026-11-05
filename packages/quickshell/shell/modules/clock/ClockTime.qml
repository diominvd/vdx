import QtQuick
import qs.config

// The time and the format of Modules › Clock, for the bar's clock and the island's.
// It ticks on the minute; on the second only while seconds are shown.
QtObject {
  id: root

  property bool forceSeconds: false            // the popup's long form shows them
  property date now: new Date()

  readonly property bool seconds: forceSeconds || ModuleSettings.get("clock", "seconds", false)
  readonly property string format: (ModuleSettings.get("clock", "date", false) ? "ddd dd · " : "")
    + (ModuleSettings.get("clock", "twelveHour", false) ? "h:mm" : "HH:mm")
    + (ModuleSettings.get("clock", "seconds", false) ? ":ss" : "")
    + (ModuleSettings.get("clock", "twelveHour", false) ? " AP" : "")

  function tick() {
    const d = new Date();
    now = d;
    ticker.interval = seconds ? 1000 : 60000 - d.getSeconds() * 1000 - d.getMilliseconds() + 50;
  }
  onSecondsChanged: tick()

  property Timer ticker: Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.tick()
  }
}
