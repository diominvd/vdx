import QtQuick
import qs.config

// A settings row with a switch bound to one module option (ModuleSettings):
// `module`, `key`, `fallback` (the default), label and hint.
KitRow {
  id: root

  property string module
  property string key
  property bool fallback: true

  readonly property bool checked: ModuleSettings.get(module, key, fallback)

  KitSwitch {
    accessibleName: root.label
    checked: root.checked
    onToggled: ModuleSettings.set(root.module, root.key, !root.checked)
  }
}
