pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../../kit/reply.js" as Reply

// Bluetooth state and actions on top of scripts/bluetooth.sh. The bar module and
// the popup only read these properties and call these functions.
Singleton {
  id: root

  // ---- tuning ----
  readonly property int statusPollMs: 5000     // while the popup is open
  readonly property int idlePollMs: 30000      // closed: the face (changes come by --listen)
  readonly property int changeMs: 500         // the least gap between two re-reads on events
  readonly property int barMaxLength: 14  // the device's name on the bar, in characters
  readonly property string script: Paths.scriptsDir + "/bluetooth.sh"

  // ---- adapter ----
  property bool powered: false
  property bool toggling: false                // power switch in flight
  property bool discovering: false
  // alias, discoverable, timeout (s; 0 is forever), pairable: see `bluetooth.sh --devices`
  property var adapter: ({ alias: "", discoverable: false, timeout: 0, pairable: false })
  property string error: ""                    // why there is no list (no adapter, bad reply)

  // ---- devices ----
  property var devices: []                     // see `bluetooth.sh --devices`
  readonly property var connectedDevices: devices.filter(d => d.connected)
  readonly property var pairedDevices: devices.filter(d => d.paired && !d.connected)
  readonly property var nearbyDevices: devices.filter(d => !d.paired)
  readonly property var mainDevice: connectedDevices[0] ?? null

  // ---- state of the work ----
  property string busyMac: ""                  // device with a connect, pair or forget in flight
  property bool scanning: false
  property bool adapterBusy: false
  property var adapterQueue: []
  property string actionError: ""

  // ---- lifecycle ----
  property bool popupOpen: false
  function popupShown() { popupOpen = true; refresh(); }
  function popupHidden() { popupOpen = false; }

  Component.onCompleted: refreshStatus()

  // ---- actions ----
  function togglePower() {
    if (toggling) return;
    toggling = true;
    powered = !powered;
    run(powerProc, ["--power", powered ? "on" : "off"]);
  }

  function scan() {
    if (!powered || scanning) return;
    scanning = true;
    actionError = "";
    run(scanProc, ["--scan"]);
  }

  // A connected device is disconnected, any other one connected (paired first if new).
  function toggleDevice(device) {
    if (busyMac !== "" || adapterBusy || adapterQueue.length > 0 || !powered) return;
    busyMac = device.mac;
    actionError = "";
    run(deviceProc, [device.connected ? "--disconnect" : "--connect", device.mac]);
  }

  // ---- adapter and devices settings ----
  function setAdapter(args) {
    adapterQueue = adapterQueue.concat([args.slice()]);
    flushAdapter();
  }

  function flushAdapter() {
    if (adapterBusy || busyMac !== "" || adapterQueue.length === 0) return;
    const args = adapterQueue[0];
    adapterQueue = adapterQueue.slice(1);
    adapterBusy = true;
    actionError = "";
    run(adapterProc, args);
  }
  function setTrusted(device, on) { setAdapter(["--trust", device.mac, on ? "on" : "off"]); }
  function setBlocked(device, on) { setAdapter(["--block", device.mac, on ? "on" : "off"]); }

  // ---- internals ----
  function run(proc, args) {
    proc.command = ["bash", root.script].concat(args);
    proc.running = true;
  }

  function parse(text) {
    return Reply.parse(text, "bluetooth.sh", null);
  }

  function refresh() { refreshStatus(); }
  function refreshStatus() { if (!statusProc.running) statusProc.running = true; }

  // ---- events ----
  // BlueZ signals each change (a device connects, its battery or RSSI moves, a scan
  // finds one): the first re-reads at once, the ones after it in changeMs come as one more.
  property bool changePending: false

  function changed() {
    if (changeTimer.running) { changePending = true; return; }
    refresh();
    changeTimer.restart();
  }

  Process {
    id: listenProc
    command: ["bash", root.script, "--listen"]
    running: true
    stdout: SplitParser { onRead: root.changed() }
    onExited: listenRestart.restart()
  }

  Timer {
    id: listenRestart
    interval: 3000
    onTriggered: listenProc.running = true
  }

  Timer {
    id: changeTimer
    interval: root.changeMs
    onTriggered: if (root.changePending) {
      root.changePending = false;
      root.refresh();
      changeTimer.restart();
    }
  }

  // ---- polling ----
  // the fallback when no event comes: the status every statusPollMs (idlePollMs with the popup closed)
  Timer {
    interval: root.popupOpen ? root.statusPollMs : root.idlePollMs
    running: true
    repeat: true
    onTriggered: root.refreshStatus()
  }

  // ---- processes ----
  Process {
    id: statusProc
    command: ["bash", root.script, "--devices"]
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        if (!o) return;
        if (!o.ok) {
          root.error = o.error;
          root.powered = false;
          root.devices = [];
          return;
        }
        if (typeof o.powered !== "boolean" || typeof o.discovering !== "boolean" ||
            !Array.isArray(o.devices) || !o.adapter || typeof o.adapter !== "object" ||
            Array.isArray(o.adapter)) {
          root.error = "bad bluetooth status reply";
          return;
        }
        root.error = "";
        if (!root.toggling) root.powered = o.powered;
        root.discovering = o.discovering;
        root.adapter = o.adapter;
        root.devices = o.devices;
      }
    }
  }

  Process {
    id: powerProc
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.toggling = false;
      root.actionError = "could not start bluetooth power request";
      root.refresh();
    }
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        root.toggling = false;
        root.actionError = o?.ok ? "" : (o?.error ?? "could not switch bluetooth");
        root.refresh();
      }
    }
  }

  Process {
    id: scanProc
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.scanning = false;
      root.actionError = "could not start bluetooth scan";
    }
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        root.actionError = o?.ok ? "" : (o?.error ?? "could not scan for devices");
        root.refresh();
        root.scanning = false;
      }
    }
  }

  Process {
    id: adapterProc
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.adapterQueue = [];
      root.adapterBusy = false;
      root.actionError = "could not start bluetooth settings request";
      root.refresh();
    }
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        if (!o?.ok) {
          root.adapterQueue = [];
          root.actionError = o?.error ?? "bluetooth.sh failed";
          root.adapterBusy = false;
          root.refresh();
          return;
        }
        root.adapterBusy = false;
        if (root.adapterQueue.length > 0) {
          root.flushAdapter();
          return;
        }
        root.actionError = "";
        root.refresh();
      }
    }
  }

  Process {
    id: deviceProc
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.busyMac = "";
      root.actionError = "could not start bluetooth device request";
      root.refresh();
      root.flushAdapter();
    }
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        root.busyMac = "";
        root.actionError = o?.ok ? "" : (o?.error ?? "bluetooth.sh failed");
        root.refresh();
        root.flushAdapter();
      }
    }
  }
}
