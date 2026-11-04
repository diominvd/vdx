pragma Singleton
import QtQuick

// The hub's blocks under the clock and day (which is always there): which there are, in what
// order, and which are shown. Bar › Hub sets them, the island's hub reads them. Stored in
// ModuleSettings "hub": `blocks` (the order) and `blocksOff` (the hidden ones).
QtObject {
  id: root

  // id -> what it is, in the default order
  readonly property var all: ["machine", "tiles", "week", "volume", "microphone", "brightness", "night", "dimming", "player", "modules"]
  readonly property var names: ({ machine: "Machine", tiles: "Toggles", week: "Calendar", player: "Player", volume: "Volume", microphone: "Microphone", brightness: "Brightness", night: "Night light", dimming: "Dimming", modules: "Module chips" })
  readonly property var notes: ({
    machine: "Battery, memory and disk as rings, the CPU gauge",
    tiles: "The tiles of the Hub row: Wi-Fi, Bluetooth, VPN, Focus",
    week: "The week, or the whole month",
    player: "Opens the Music popup",
    volume: "Output volume slider",
    microphone: "Microphone volume slider",
    brightness: "Backlight slider; its icon switches night mode",
    night: "Warmth slider, always or only while night mode is on",
    dimming: "Software dimming slider",
    modules: "The Hub row's other modules, as chips"
  })

  readonly property var saved: ModuleSettings.get("hub", "blocks", []) ?? []
  readonly property var off: ModuleSettings.get("hub", "blocksOff", []) ?? []

  // the saved order first, then what it did not name (a block added later lands at the end)
  // (the sliders were one block, "sliders": it stands for the five)
  readonly property var sliderIds: ["volume", "microphone", "brightness", "night", "dimming"]
  readonly property var order: saved.reduce((list, id) => list.concat(id === "sliders" ? sliderIds : [id]), [])
    .filter((id, i, list) => all.includes(id) && list.indexOf(id) === i)
    .concat(all.filter(id => !saved.includes(id) && !(saved.includes("sliders") && sliderIds.includes(id))))

  // the toggles above the module chips: the Bar page lists the two rows in this order
  readonly property bool tilesFirst: order.indexOf("tiles") < order.indexOf("modules") || order.indexOf("modules") < 0

  // a slider's switch is its own key (volume, microphone, ...), on by default for volume and brightness
  // (the player once had a switch of its own, ShellSettings look hubPlayer: off there is off here)
  function shown(id) {
    if (sliderIds.includes(id)) return ModuleSettings.get("hub", id, id === "volume" || id === "brightness");
    return !off.includes(id) && !(id === "player" && ShellSettings.look("hubPlayer", "island") === false);
  }
  function setOrder(list) { ModuleSettings.set("hub", "blocks", list); }
  function setShown(id, on) {
    if (sliderIds.includes(id)) { ModuleSettings.set("hub", id, on); return; }
    if (id === "player" && on) ShellSettings.setLook("hubPlayer", true, "island");
    const rest = off.filter(x => x !== id);
    ModuleSettings.set("hub", "blocksOff", on ? rest : rest.concat([id]));
  }
}
