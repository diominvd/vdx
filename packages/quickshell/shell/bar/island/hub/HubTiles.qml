import QtQuick
import qs.apps.shellmanager
import qs.bar
import qs.config
import qs.kit
import qs.modules.bluetooth
import qs.modules.focus
import qs.modules.mihomo
import qs.modules.timer
import qs.modules.wifi

// The hub's tiles: the modules of the hub row that can be one (BarLayout `tile`),
// in the row's order: bare discs, as many as fit a row (Bezel: a state is a disc), or
// tiles two or four to a row (Hub › Toggles › Shown as). A tile
// shows the module's state; the icon switches it, the rest opens its popup. The
// module itself is made here, out of sight, so its own popup answers.
Item {
  id: root

  signal settings(string id)                    // a right click on a tile
  property var ids: []                          // tile modules, in order
  property var modules: ({})                    // Bar's module id -> Component
  readonly property int shape: ModuleSettings.get("hub", "tileColumns", 6)   // 6: discs; 2 | 4: tiles
  readonly property bool discs: shape !== 2 && shape !== 4
  readonly property int columns: discs ? Math.max(3, Math.floor((width + Theme.gapMedium) / (Theme.ringCell + Theme.gapMedium))) : shape

  implicitHeight: grid.implicitHeight
  visible: ids.length > 0

  // what each tile shows and does
  function spec(id) {
    switch (id) {
    case "wifi": return {
      icon: WifiService.connected ? "wifi" : "wifi-off", title: "Wi-Fi", on: WifiService.connected,
      detail: WifiService.connected ? WifiService.ssid : WifiService.radioOn ? "Not connected" : "Off",
      toggle: () => WifiService.toggleRadio() };
    case "bluetooth": return {
      icon: BluetoothService.powered ? "bluetooth" : "bluetooth-off", title: BluetoothService.mainDevice ? BluetoothService.mainDevice.name : "Bluetooth",
      on: BluetoothService.powered && BluetoothService.mainDevice !== null,
      detail: BluetoothService.mainDevice ? (BluetoothService.mainDevice.battery != null ? BluetoothService.mainDevice.battery + "%" : "Connected")
                                          : BluetoothService.powered ? "No device" : "Off",
      toggle: () => BluetoothService.togglePower() };
    case "mihomo": return {
      icon: "public", title: "VPN", on: MihomoService.serviceOn,
      detail: MihomoService.serviceOn ? "On" : "Off",
      toggle: () => MihomoService.toggleService() };
    case "focus": return {
      icon: "moon", title: "Focus", on: FocusService.on, detail: FocusService.on ? "On" : "Off",
      toggle: () => FocusService.toggle(), noPopup: true };
    case "timer": return {
      icon: "clock", title: TimerService.active ? TimerService.title : "Timer", on: TimerService.active,
      detail: TimerService.active ? TimerService.text + (TimerService.paused ? " · paused" : "") : "Not running",
      toggle: () => TimerService.active ? TimerService.togglePause() : root.open("timer") };
    case "mode": return {
      icon: "paint-bucket", title: "Dark mode", on: !ThemeService.light,
      detail: ThemeService.light ? "Off" : "On",
      toggle: () => { if (!ThemeService.busy) ThemeService.setLight(!ThemeService.light); }, noPopup: true };
    }
    return { icon: "grid", title: id, on: false, detail: "", toggle: () => {}, noPopup: true };
  }

  // the modules, made once each, hidden: a popup opens through `openPopup()`
  property var hosts: ({})
  Repeater {
    model: root.ids
    Loader {
      required property string modelData
      visible: false
      sourceComponent: root.modules[modelData] ?? null
      onLoaded: root.hosts[modelData] = item
    }
  }
  function open(id) { root.hosts[id]?.openPopup?.(); }

  Grid {
    id: grid
    width: parent.width
    columns: root.columns
    spacing: Theme.gapMedium

    Repeater {
      model: root.ids

      HubTile {
        required property string modelData
        readonly property var s: root.spec(modelData)
        width: (grid.width - (root.columns - 1) * grid.spacing) / root.columns
        compact: root.columns > 2
        bare: root.discs
        icon: s.icon
        title: s.title
        detail: s.detail
        on: s.on
        canOpen: !s.noPopup
        onToggled: s.toggle()
        onOpened: root.open(modelData)
        onContext: root.settings(modelData)
      }
    }
  }
}
