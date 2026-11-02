pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config
import "../../kit/reply.js" as Reply

// Battery state, charge limit, power profile and GPU mode on top of
// scripts/battery.sh. The bar module and the popup only read these properties
// and call these functions. The charge limit resets on reboot, so the chosen
// one persists in the shell's state dir and is re-applied on start.
Singleton {
  id: root

  // ---- tuning ----
  readonly property int pollMs: 3000              // while the popup is open
  readonly property int idlePollMs: 30000         // closed; UPower changes read it at once
  readonly property int warning: 30               // %, yellow
  readonly property int critical: 15              // %, red
  readonly property var notifyLevels: [15, 5]     // %, low-battery notifications
  readonly property var limits: [60, 80, 100]     // %, charge limit choices
  readonly property string saverProfile: "quiet"  // platform profile of the power saver
  readonly property string script: Paths.scriptsDir + "/battery.sh"

  // ---- battery ----
  property var info: ({})                      // see `battery.sh --status`
  property bool ready: false

  readonly property bool present: info.present ?? false
  readonly property int capacity: info.capacity ?? 0
  readonly property bool plugged: info.plugged ?? false
  readonly property bool charging: info.status === "Charging"
  readonly property bool discharging: info.status === "Discharging"
  readonly property string capacityLabel: present ? capacity + "%" : "—"
  readonly property real power: info.power ?? 0                // W
  readonly property real voltage: info.voltage ?? 0            // V
  readonly property real energy: info.energy ?? 0              // Wh
  readonly property real energyFull: info.energyFull ?? 0      // Wh
  readonly property real energyDesign: info.energyDesign ?? 0  // Wh
  readonly property int cycles: info.cycles ?? 0
  readonly property string cyclesLabel: info.cycles == null ? "—" : String(cycles)
  readonly property int threshold: info.threshold ?? 100
  readonly property bool limitSupported: info.limit ?? false   // the kernel takes a charge limit
  readonly property int health: energyDesign > 0 ? Math.round(energyFull / energyDesign * 100) : 0
  readonly property string healthLabel: energyDesign > 0 ? health + "%" : "—"
  readonly property string energyLabel: energyDesign > 0
    ? energy.toFixed(1) + " / " + energyDesign.toFixed(1) + " Wh" : "—"

  // Minutes until empty (discharging) or until the charge limit (charging); -1 when unknown.
  readonly property int minutesLeft: {
    if (power <= 0) return -1;
    if (discharging) return Math.round(energy / power * 60);
    if (charging) return Math.max(0, Math.round((energyFull * threshold / 100 - energy) / power * 60));
    return -1;
  }

  // ---- power profile / GPU ----
  readonly property string profile: info.profile ?? ""
  readonly property var profiles: info.profiles ?? []
  readonly property bool saver: profile === root.saverProfile
  // Material battery_android by charge: empty under 10, then 2, 4, 5 and 6 bars, full at 100
  readonly property string levelIcon: capacity >= 100 ? "battery-full"
    : capacity >= 70 ? "battery-6" : capacity >= 50 ? "battery-5"
    : capacity >= 30 ? "battery-4" : capacity >= 10 ? "battery-2" : "battery-0"

  property string gpuMode: ""
  property string gpuPending: ""
  property string gpuAction: ""                // supergfxctl's required user action

  // ---- actions ----
  property var busy: null                      // value being applied, for its spinner
  property string actionError: ""
  property string statusError: ""
  readonly property string error: actionError || statusError

  property bool popupOpen: false
  function popupHidden() { popupOpen = false; }
  function popupShown() {
    popupOpen = true;
    actionError = "";
    refresh();
    run(gpuProc, ["--gpu"]);
  }

  function setThreshold(percent) {
    if (apply(["--threshold", String(percent)], percent)) state.threshold = percent;
  }

  function setProfile(name) { apply(["--profile", name], name); }

  // Power saver is the quiet profile; turning it off restores the one before.
  function setSaver(on) {
    if (on) {
      if (apply(["--profile", root.saverProfile], root.saverProfile)) state.lastProfile = profile;
    } else {
      setProfile(state.lastProfile !== root.saverProfile ? state.lastProfile : "balanced");
    }
  }
  function setGpuMode(mode) { apply(["--gpu-mode", mode], mode); }

  // ---- internals ----
  property var notified: []                    // notify levels already shown this discharge

  function run(proc, args) {
    proc.command = ["bash", root.script].concat(args);
    proc.running = true;
  }

  function apply(args, value) {
    if (busy !== null || actionProc.running) return false;
    busy = value;
    actionError = "";
    run(actionProc, args);
    return true;
  }

  function refresh() {
    if (!statusProc.running) run(statusProc, ["--status"]);
  }

  function checkLevel() {
    if (!discharging) {
      notified = [];
      return;
    }
    for (const level of root.notifyLevels) {
      if (capacity > level || notified.includes(level)) continue;
      notified = notified.concat(level);
      Quickshell.execDetached(["notify-send", "-u", level <= 5 ? "critical" : "normal",
                               "Battery low", capacity + "% remaining"]);
      break;
    }
  }

  onCapacityChanged: checkLevel()
  onDischargingChanged: checkLevel()

  // ---- polling ----
  // UPower tells of a plug, an unplug or a new percentage: read it now, not at
  // the next tick (the details — limit, health, profile — are battery.sh's)
  Connections {
    target: UPower.displayDevice
    function onStateChanged() { root.refresh(); }
    function onPercentageChanged() { root.refresh(); }
  }
  Connections {
    target: UPower
    function onOnBatteryChanged() { root.refresh(); }
  }

  Timer {
    interval: root.popupOpen ? root.pollMs : root.idlePollMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // ---- processes ----
  Process {
    id: statusProc
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.ready = true;
      root.statusError = "could not start battery status query";
    }
    stdout: StdioCollector {
      onStreamFinished: {
        const o = Reply.parse(text, "battery.sh", null);
        if (typeof o?.present !== "boolean") {
          root.ready = true;
          root.statusError = o?.error ?? "could not read battery status";
          return;
        }
        root.info = o;
        root.statusError = "";
        root.ready = true;
      }
    }
  }

  Process {
    id: gpuProc
    stdout: StdioCollector {
      onStreamFinished: {
        const o = Reply.parse(text, "battery.sh", null);
        if (!o) return;
        root.gpuMode = o.mode;
        root.gpuPending = o.pending;
        root.gpuAction = o.action;
      }
    }
  }

  Process {
    id: actionProc
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.actionError = "could not start battery action";
      root.busy = null;
    }
    stdout: StdioCollector {
      onStreamFinished: {
        const o = Reply.parse(text, "battery.sh");
        if (!o?.ok) root.actionError = o?.error ?? "action failed";
        root.refresh();
        root.run(gpuProc, ["--gpu"]);
        root.busy = null;
      }
    }
  }

  // ---- files ----
  FileView {
    id: stateFile
    path: Quickshell.statePath("battery.json")
    printErrors: false
    onAdapterUpdated: writeAdapter()
    onLoaded: if (state.threshold < 100) root.setThreshold(state.threshold)
    onLoadFailed: writeAdapter()

    JsonAdapter {
      id: state
      property int threshold: 100
      property string lastProfile: "balanced"
    }
  }
}
