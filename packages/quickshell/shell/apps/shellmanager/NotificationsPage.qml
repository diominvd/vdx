import QtQuick
import qs.config
import qs.kit
import qs.modules.notifications

// Notifications: how new ones arrive, the app colours, the centre and the bar's marks
// (modules/notifications/NotificationsSettings.qml: ModuleSettings
// "notifications" and ShellSettings' unseen dot). Reset in the window's header
// brings the module's defaults and the dot's back. Bar modules lists it as a link here.
Column {
  id: root
  readonly property Item previewItem: null

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "bell"
  readonly property string title: "Notifications"
  readonly property string description: "How notifications arrive and look."
  readonly property int toast: ModuleSettings.get("notifications", "toastSeconds", 5)
  readonly property var jumps: []

  // the header's Reset: every "notifications" key but `appear` (a card or a live line: the
  // Messages activity's switch, Live activities resets it)
  readonly property var keys: Object.keys(ModuleSettings.values.notifications ?? {}).filter(k => k !== "appear")
  readonly property bool changed: ModuleSettings.changed("notifications", keys) || ShellSettings.changed(["barFolderDot", "barDotColor"])
  function reset() {
    ModuleSettings.reset("notifications", keys);
    ShellSettings.reset(["barFolderDot", "barDotColor"]);
  }

  NotificationsSettings { width: parent.width }

  KitGrouper {}
}
