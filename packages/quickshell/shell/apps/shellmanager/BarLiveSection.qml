import QtQuick
import qs.bar
import qs.config
import qs.kit
import qs.modules.battery

// One block of Bar › Live, a settings section: a small-caps caption, then a KitReorderList of
// KitFoldRow — a handle, a same-size sample of the pill, the name, a switch. The row order is
// the priority; drag a row by its handle to move it.
Column {
  id: root

  property string section: ""
  property string title: ""
  property string about: ""
  property var info: ({})                      // kind -> { label, hint }

  readonly property var kinds: ShellSettings.liveOrdered(section)

  KitLabel { text: root.title; about: root.about }

  // `live:<kind>` from a right click on the pill: unfold that activity's options
  function jump(kind) { if (kinds.includes(kind)) list.open = kind; }

  KitReorderList {
    id: list
    width: root.width
    keys: root.kinds
    onOrdered: list => ShellSettings.liveSetOrder(root.section, list)

    delegate: KitFoldRow {
      id: row
      // what is not here cannot run: the row says so and keeps its switch out of reach
      readonly property string missing: key === "vpn" && !BarLayout.installed("mihomo") ? "Not installed"
        : key === "backup" && !BarLayout.installed("backup") ? "Not installed"
        : key === "battery" && !BatteryService.present ? "No battery in this machine"
        : key === "radio" && !BarLayout.installed("radio") ? "Not installed"
        : key === "music" && !BarLayout.installed("music") ? "Not installed" : ""

      label: root.info[key]?.label ?? key
      hint: missing !== "" ? missing : (root.info[key]?.hint ?? "")
      checked: ShellSettings.liveKind(key)
      switchEnabled: missing === ""
      foldable: options.any && missing === ""
      sunken: true
      leading: Component {
        LivePreview {
          kind: row.key
          surface: row.unfolded ? Theme.foldHeader : Theme.sectionFill
          opacity: row.checked && ShellSettings.liveEnabled && row.missing === "" ? 1 : 0.45
        }
      }
      onToggled: key === "notice"
        ? ModuleSettings.set("notifications", "appear", checked ? "card" : "live")
        : ShellSettings.setLook("live" + key.charAt(0).toUpperCase() + key.slice(1), !checked, "island")

      LiveOptions { id: options; kind: row.key; shown: row.unfolded; inset: row.indent + row.edge }
    }
  }

  KitGrouper {}
}
