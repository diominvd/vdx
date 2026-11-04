import QtQuick
import qs.config
import qs.kit
import qs.modules.battery
import qs.modules.sysmon

// The hub's Machine widget (Bezel): the fills of one machine share a centre —
// battery outside, memory, then the root disk — with their numbers beside them, and
// the CPU load as a bare gauge. Rings with no plate: one value each.
// The full system sample runs only while the hub shows it (`live`, a Sysmon holder).
Item {
  id: root

  property bool live: false                     // the hub is open

  implicitHeight: Theme.ringLarge

  // ---- the hold: full samples only while seen ----
  property bool holding: false
  function sync() {
    if (live === holding) return;
    holding = live;
    if (holding) SysmonService.hold();
    else SysmonService.release();
  }
  onLiveChanged: sync()
  Component.onCompleted: sync()
  Component.onDestruction: if (holding) SysmonService.release()

  // ---- values ----
  function load(p) { return p >= 90 ? Theme.red : p >= 70 ? Theme.yellow : null; }
  readonly property int memPercent: SysmonService.mem.total > 0 ? Math.round(100 * SysmonService.memUsed / SysmonService.mem.total) : -1
  readonly property var rootDisk: SysmonService.disks.find(d => d.mount === "/") ?? null
  readonly property int diskPercent: rootDisk && rootDisk.size > 0 ? Math.round(100 * rootDisk.used / rootDisk.size) : -1
  readonly property int cpuTemp: SysmonService.temps.cpu === null ? -1 : Math.round(SysmonService.temps.cpu)
  function timeLeft(m) { return m <= 0 ? "" : (m >= 60 ? Math.floor(m / 60) + " h " : "") + m % 60 + " min"; }

  // outside in; by lightness, a state colour wins
  readonly property var fills: {
    const list = [];
    if (BatteryService.present) {
      const c = BatteryService.capacity;
      list.push({ name: "Bat", value: c, tint: c <= BatteryService.critical ? Theme.red : BatteryService.charging ? Theme.green : null,
                  note: BatteryService.charging ? "charging" : timeLeft(BatteryService.minutesLeft) });
    }
    if (memPercent >= 0)
      list.push({ name: "Mem", value: memPercent, tint: load(memPercent),
                  note: Format.shortSize(SysmonService.memUsed) + " / " + Format.shortSize(SysmonService.mem.total) });
    if (diskPercent >= 0)
      // a full disk is news only near the top
      list.push({ name: "Disk", value: diskPercent, tint: diskPercent >= 90 ? Theme.red : null,
                  note: Format.shortSize(rootDisk.size - rootDisk.used) + " free" });
    return list;
  }
  readonly property var shades: [Theme.foreground1, Theme.mix(Theme.background0, Theme.foreground1, 0.72), Theme.mix(Theme.background0, Theme.foreground1, 0.5)]
  readonly property real stroke: Theme.ringStroke(Theme.ringWide)
  readonly property real step: stroke + 3              // one ring to the next, a hairline apart

  // ---- concentric fills ----
  Item {
    id: dial
    width: Theme.ringLarge
    height: Theme.ringLarge
    anchors.verticalCenter: parent.verticalCenter

    Repeater {
      model: root.fills.length
      KitRing {
        required property int index
        readonly property var spec: root.fills[index] ?? ({})
        anchors.centerIn: parent
        size: Theme.ringLarge - 2 * root.step * index
        stroke: root.stroke
        kind: "fill"
        value: (spec.value ?? 0) / 100
        tint: spec.tint ?? root.shades[index]
      }
    }
  }

  // ---- their numbers ----
  Column {
    anchors { left: dial.right; leftMargin: Theme.gapWide; right: cpu.left; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
    spacing: Theme.gapMedium

    Repeater {
      model: root.fills.length
      Row {
        required property int index
        readonly property var spec: root.fills[index] ?? ({})
        width: parent.width
        spacing: Theme.gapSmall

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 6; height: 6; radius: width / 2
          color: spec.tint ?? root.shades[index]
        }
        KitText { anchors.verticalCenter: parent.verticalCenter; text: spec.name ?? ""; color: Theme.muted; font.pixelSize: Theme.fontSize - 2 }
        KitText { anchors.verticalCenter: parent.verticalCenter; text: (spec.value ?? 0) + "%"; font.weight: Font.Bold; font.features: { "tnum": 1 } }
        KitText {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(0, parent.width - x)
          text: spec.note ?? ""
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 2
          elide: Text.ElideRight
        }
      }
    }
  }

  // ---- the CPU: a level with zones ----
  Column {
    id: cpu
    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
    spacing: Theme.gapHair

    KitRing {
      anchors.horizontalCenter: parent.horizontalCenter
      size: Theme.ringWide
      kind: "gauge"
      value: SysmonService.cpu / 100
      text: String(SysmonService.cpu)
      icon: "cpu"
      tint: root.load(SysmonService.cpu) ?? Theme.foreground1
    }
    KitText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: (root.cpuTemp >= 0 ? root.cpuTemp + "° · " : "") + (SysmonService.freq > 0 ? (SysmonService.freq / 1000).toFixed(1) + " GHz" : "CPU")
      color: Theme.muted
      font.pixelSize: Theme.fontSize - 2
    }
  }
}
