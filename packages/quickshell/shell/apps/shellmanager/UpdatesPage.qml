import QtQuick
import qs.apps.packages
import qs.components
import qs.config
import qs.kit

// Updates: when the shell looks for package updates and how careful it is when removing.
// It was Apps › Packages (UPDATES and SAFETY); the keys are the same ModuleSettings
// "packages" ones. The Packages window itself is an app.
Column {
  id: root
  readonly property Item previewItem: null

  readonly property string icon: "download"
  readonly property string title: "Updates"
  readonly property string description: "When the shell looks for updates, and how careful it is."
  readonly property var jumps: []

  readonly property var resetKeys: ["checkOnOpen", "interval", "aur", "autoInstall", "confirm"]
  readonly property bool changed: ModuleSettings.changed("packages", resetKeys)
  function reset() { ModuleSettings.reset("packages", resetKeys); }

  KitLabel { text: "CHECKING" }

  KitToggleRow { module: "packages"; key: "checkOnOpen"; label: "Check on open"; hint: "Once in ten minutes at most" }

  KitOptionRow {
    module: "packages"; key: "interval"; fallback: 30
    label: "Background check"; hint: "How often to check; Off: only on request"
    model: [{ label: "Off", value: 0 }, { label: "30 min", value: 30 }, { label: "1 h", value: 60 }]
  }

  KitToggleRow { module: "packages"; key: "aur"; label: "Include the AUR"; hint: "Counted and listed with the repos" }

  KitLine {}

  KitLabel { text: "INSTALLING" }

  KitToggleRow { module: "packages"; key: "autoInstall"; label: "Install right after the download"; hint: "Off: asks again after the download" }

  KitLine {}

  KitLabel { text: "SAFETY" }

  KitToggleRow { module: "packages"; key: "confirm"; label: "Ask before uninstalling"; hint: "Uninstall asks “Sure?” once" }

  KitLine {}

  KitLabel { text: "PACKAGES" }

  KitRow {
    label: "Open Packages"
    hint: "Updates, installed packages and the cache"
    KitButton { text: "Open"; onClicked: ShellIpc.call("packages", "toggle") }
  }

  KitGrouper {}
}
