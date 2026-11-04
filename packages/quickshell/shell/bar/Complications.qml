pragma Singleton
import QtQuick
import Quickshell
import qs.config
import qs.modules.audio
import qs.modules.battery
import qs.modules.bluetooth
import qs.modules.brightness
import qs.modules.focus
import qs.modules.mihomo
import qs.modules.sysmon
import qs.modules.timer
import qs.modules.wifi

// Each bar module's value as a complication (Bezel): its data kind, its share of a
// whole, its numeral, its icon. One source for every distance: the resting pill
// (ring 22, kit/KitRing), the peek (40) and the hub (64 and up).
// `of(id)` returns a list of rings (System has one per metric it shows); an empty
// list means the module has no whole to draw (the clock, a layout, a rate, the
// workspaces) and keeps its face of words. Reads only what the faces already read:
// no poll of its own.
Singleton {
  id: root

  // the lit part at rest: the theme's ink, or the accent where it marks what is on (APPLIES TO › Bar modules)
  readonly property color ink: Theme.foreground1
  readonly property color onInk: Theme.accentFor("modules", Theme.foreground1)

  function ring(kind, value, text, icon, tint, words, extra) {
    const r = { kind: kind, value: value, text: text, icon: icon, tint: tint ?? ink, words: words ?? "", on: true, quiet: false, steps: 5 };
    return Object.assign(r, extra ?? {});
  }
  function pct(v) { return Math.max(0, Math.min(1, v / 100)); }
  function heat(t) { return t >= 85 ? Theme.red : t >= 70 ? Theme.yellow : ink; }
  function load(p) { return p >= 90 ? Theme.red : p >= 70 ? Theme.yellow : ink; }

  function of(id) {
    switch (id) {
    case "battery": {
      if (!BatteryService.present) return [];
      const c = BatteryService.capacity;
      const tint = c <= BatteryService.critical ? Theme.red : BatteryService.charging ? Theme.green
                 : BatteryService.saver ? Theme.yellow : ink;
      return [ring("fill", pct(c), String(c), BatteryService.levelIcon, tint,
                   BatteryService.charging ? "Charging" : BatteryService.plugged ? "Plugged in" : "Battery")];
    }
    case "audio": {
      const v = AudioService.volume;
      if (AudioService.muted)
        return [ring("disc", 0, "", "volume-x", Theme.red, "Muted", { on: true, quiet: true })];
      return [ring("fill", pct(v), String(v), AudioService.headphones ? "headphones" : "volume",
                   v > 100 ? Theme.orange : ink, "Volume")];
    }
    case "brightness": {
      if (!BrightnessService.available) return [];
      const b = BrightnessService.brightness;
      return [ring("fill", pct(b), String(b), BrightnessService.nightActive ? "moon" : "sun",
                   BrightnessService.nightActive ? Theme.orange : ink, "Brightness")];
    }
    case "sysmon": {
      const list = [ring("gauge", pct(SysmonService.cpu), String(SysmonService.cpu), "cpu", load(SysmonService.cpu), "CPU")];
      if (ModuleSettings.get("sysmon", "barMemory", false) && SysmonService.mem.total > 0) {
        const m = Math.round(100 * SysmonService.memUsed / SysmonService.mem.total);
        list.push(ring("fill", pct(m), String(m), "grid", load(m), "Memory"));
      }
      if (ModuleSettings.get("sysmon", "barTemp", false) && SysmonService.temps.cpu !== null) {
        const t = Math.round(SysmonService.temps.cpu);
        list.push(ring("gauge", pct(t), String(t), "gauge", heat(t), "Temperature"));
      }
      return list;
    }
    case "timer": {
      if (!TimerService.active || TimerService.kind !== "countdown")
        return [ring("disc", 0, "", "clock", ink, "Timer", { on: TimerService.active, quiet: true })];
      const left = Math.ceil(TimerService.remaining / 60000);
      return [ring("ticks", 1 - TimerService.progress, String(left), "clock",
                   TimerService.paused ? Theme.muted : Theme.orange, "Timer")];
    }
    case "wifi":
      return [ring("disc", 0, "", WifiService.radioOn ? "wifi" : "wifi-off", onInk, WifiService.ssid || "Wi-Fi",
                   { on: WifiService.connected, quiet: true })];
    case "bluetooth":
      return [ring("disc", 0, "", BluetoothService.powered ? "bluetooth" : "bluetooth-off", onInk,
                   BluetoothService.mainDevice?.name ?? "Bluetooth",
                   { on: BluetoothService.powered, quiet: !BluetoothService.mainDevice })];
    case "mihomo":
      return [ring("disc", 0, "", "public", onInk, MihomoService.current || "VPN", { on: MihomoService.serviceOn })];
    case "focus":
      return [ring("disc", 0, "", "moon", Theme.accentFor("modules", Theme.purple), "Focus", { on: FocusService.on })];
    }
    return [];
  }
}
