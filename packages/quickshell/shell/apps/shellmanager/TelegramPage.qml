import QtQuick
import qs.config
import qs.kit
import qs.modules.notifications

// Phone's first page: private-chat pairing, delivery and literal app rules.
Column {
  id: root
  readonly property string icon: "message"
  readonly property string title: "Telegram"
  readonly property string description: "Send new shell notifications to your phone."
  readonly property var jumps: [
    { key: "connection", label: "Connection", y: connectionGroup.y },
    { key: "delivery", label: "Delivery", y: deliveryGroup.y },
    { key: "rules", label: "Rules", y: rulesGroup.y }
  ]
  readonly property var resetKeys: ["enabled", "body", "silent", "urgency", "filter", "apps"]
  readonly property bool changed: ModuleSettings.changed("telegram", resetKeys)
  function reset() { ModuleSettings.reset("telegram", resetKeys); }
  function connectBot() {
    if (TelegramService.connect(token.text)) token.text = "";
  }

  spacing: Theme.sectionGap
  Component.onCompleted: TelegramService.refresh()

  KitLabel { id: connectionGroup; text: "CONNECTION"; value: TelegramService.username ? "@" + TelegramService.username : "" }
  KitRow {
    wide: true
    label: "Bot token"
    hint: "From BotFather, for any bot you own"
    KitInput { id: token; echoMode: TextInput.Password; enabled: !TelegramService.busy; onAccepted: root.connectBot() }
  }
  KitRow {
    label: "Connect a bot"
    hint: "Replacing it pauses forwarding"
    KitButton { text: "Connect"; primary: true; busy: TelegramService.busy; disabled: token.text.trim() === ""; onClicked: root.connectBot() }
  }
  KitRow {
    label: "Open the pairing link"
    hint: "Press Start in the private chat"
    needs: TelegramService.pairUrl !== "" ? "" : TelegramService.connected ? "Chat already paired" : "Connect a bot first"
    KitButton { text: "Open Telegram"; disabled: TelegramService.busy; onClicked: Qt.openUrlExternally(TelegramService.pairUrl) }
  }
  KitRow {
    label: "Confirm your chat"
    hint: "After pressing Start in Telegram"
    needs: TelegramService.pairUrl !== "" ? "" : TelegramService.connected ? "Chat already paired" : "Connect a bot first"
    KitButton { text: "Check"; busy: TelegramService.busy; onClicked: TelegramService.run("pair", {}) }
  }
  KitRow {
    label: "Send a test"
    needs: TelegramService.connected ? "" : "Pair your private chat first"
    KitButton { text: "Send"; busy: TelegramService.busy; onClicked: TelegramService.run("test", {}) }
  }
  KitRow {
    label: "Disconnect"
    hint: "Remove the saved bot and chat"
    KitButton { text: "Disconnect"; busy: TelegramService.busy; disabled: !TelegramService.configured; onClicked: TelegramService.disconnect() }
  }
  KitText {
    width: parent.width
    text: TelegramService.error || TelegramService.status
    visible: text !== ""
    color: TelegramService.error ? Theme.red : Theme.muted
    wrapMode: Text.WordWrap
  }

  KitLine {}
  KitLabel { id: deliveryGroup; text: "DELIVERY" }
  KitToggleRow {
    module: "telegram"; key: "enabled"; fallback: false
    label: "Forward notifications"
    hint: "New arrivals only, no saved history"
    needs: TelegramService.connected ? "" : "Pair your private chat first"
  }
  KitToggleRow {
    module: "telegram"; key: "body"; fallback: true
    label: "Include message text"
    hint: "Off: app and title only"
  }
  KitToggleRow {
    module: "telegram"; key: "silent"; fallback: false
    label: "Send without sound"
    hint: "Keep Telegram alerts quiet"
  }

  KitLine {}
  KitLabel { id: rulesGroup; text: "RULES"; about: "Telegram notifications are always excluded to prevent loops. Desktop Focus mode does not pause forwarding." }
  KitOptionRow {
    module: "telegram"; key: "urgency"; fallback: "all"
    label: "Importance"
    model: [{ label: "All", value: "all" }, { label: "Normal and critical", value: "normal" }, { label: "Critical", value: "critical" }]
  }
  KitOptionRow {
    module: "telegram"; key: "filter"; fallback: "all"
    label: "Applications"
    model: [{ label: "All", value: "all" }, { label: "Only listed", value: "only" }, { label: "Except listed", value: "except" }]
  }
  KitRow {
    wide: true
    label: "Application names"
    hint: "Exact names, separated by commas"
    tip: "Use the app name shown in Notifications or its desktop ID. Matching ignores case. An empty Only listed rule sends nothing."
    KitInput {
      text: ModuleSettings.get("telegram", "apps", "")
      onAccepted: ModuleSettings.set("telegram", "apps", text.trim())
    }
  }
  KitGrouper {}
}
