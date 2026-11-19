import QtQuick
import qs.config
import qs.kit
import qs.modules.notifications

// Guided setup follows the saved bot/chat state. Only view progress is local.
KitColumn {
  id: root
  property bool editingBot: false
  property bool tokenEntry: false
  property bool chatOpened: false
  property bool manageConnection: false
  property bool connecting: false
  property string linkError: ""
  property string revealGroup: ""
  readonly property int setupStep: !TelegramService.stateKnown ? -1
    : TelegramService.connected && !editingBot ? 4
    : TelegramService.configured && !editingBot ? (chatOpened ? 3 : 2)
    : tokenEntry || editingBot ? 1 : 0
  readonly property bool showDelivery: TelegramService.connected || ["delivery", "rules"].includes(revealGroup)
  readonly property bool showRules: TelegramService.enabled || ["delivery", "rules"].includes(revealGroup)
  readonly property var jumps: [
    { key: "connection", label: "Connection", y: connectionGroup.y },
    { key: "delivery", label: "Delivery", y: deliveryGroup.y },
    { key: "rules", label: "Rules", y: rulesGroup.y }
  ]
  readonly property var resetKeys: TelegramService.settingsKeys
  readonly property bool changed: ModuleSettings.changed("telegram", resetKeys)
  function reset() { ModuleSettings.reset("telegram", resetKeys); }
  function rowOf(key) {
    return key === "connection" ? connectionGroup : key === "delivery" ? deliveryGroup : key === "rules" ? rulesGroup : null;
  }
  function connectBot() {
    if (setupStep !== 1) return;
    if (TelegramService.connect(token.text)) { token.text = ""; connecting = true; }
  }
  function openExternal(url) {
    const opened = Qt.openUrlExternally(url);
    linkError = opened ? "" : "Could not open Telegram. Open the link in your Telegram app.";
    return opened;
  }
  onRevealGroupChanged: if (revealGroup === "connection") tokenEntry = true
  Component.onCompleted: if (revealGroup === "connection") tokenEntry = true
  Connections {
    target: TelegramService
    function onBusyChanged() {
      if (TelegramService.busy || !root.connecting) return;
      root.connecting = false;
      if (TelegramService.error === "" && TelegramService.configured) {
        root.editingBot = false;
        root.tokenEntry = false;
        root.chatOpened = false;
        root.manageConnection = false;
      }
    }
  }

  spacing: Theme.sectionGap

  KitLabel {
    id: connectionGroup
    keepInFlat: true
    text: "CONNECTION"
    value: root.setupStep < 0 ? "" : root.setupStep === 4 ? "Connected"
         : "Step " + (root.setupStep === 0 ? 1 : root.setupStep === 1 ? 2 : 3) + " of 3"
  }
  KitNotice {
    shown: root.setupStep < 0
    title: TelegramService.busy ? "Reading connection…" : "Could not read the connection"
    text: "Your saved bot and chat are checked on this computer."
    action: TelegramService.busy ? "" : "Try again"
    onActed: TelegramService.refresh()
  }
  KitNotice {
    shown: root.setupStep === 0
    title: "1. Create a Telegram bot"
    text: "Notifications will arrive in your private chat with a bot you own. Open @BotFather, send /newbot and follow its prompts. It will give you a bot token to copy here."
  }
  KitRow {
    visible: root.setupStep === 0
    label: "Create a bot"
    KitButton {
      text: "Open BotFather"; primary: true
      onClicked: if (root.openExternal("https://t.me/BotFather")) root.tokenEntry = true
    }
  }
  KitRow {
    visible: root.setupStep === 0
    label: "Already have a bot?"
    KitButton { text: "Use its token"; onClicked: root.tokenEntry = true }
  }

  KitNotice {
    shown: root.setupStep === 1
    title: "2. Paste the bot token"
    text: "Copy the entire API token from BotFather and paste it below. Continue checks which bot it belongs to."
  }
  KitRow {
    visible: root.setupStep === 1
    wide: true
    label: "Bot token"
    hint: "Saved only on this computer"
    KitInput {
      id: token
      placeholder: "Paste token from BotFather"
      echoMode: TextInput.Password
      enabled: !TelegramService.busy
      onAccepted: root.connectBot()
    }
  }
  KitRow {
    visible: root.setupStep === 1
    label: "Check the bot"
    hint: "Changing bots pauses forwarding"
    KitButton {
      text: root.editingBot ? "Cancel" : "Back"
      disabled: TelegramService.busy
      onClicked: { token.text = ""; root.editingBot = false; root.tokenEntry = false; }
    }
    KitButton { text: "Continue"; primary: true; busy: TelegramService.busy; disabled: token.text.trim() === ""; onClicked: root.connectBot() }
  }

  KitNotice {
    shown: root.setupStep === 2 || root.setupStep === 3
    title: TelegramService.pairUrl === "" ? "Create a new chat link" : "3. Link your private chat"
    text: TelegramService.pairUrl === "" ? "The link has expired. Your bot token is saved; create a fresh link to continue."
        : root.chatOpened ? "Press Start in your chat with @" + TelegramService.username + ", then return here and choose Finish connection."
        : "Open @" + TelegramService.username + " using the button below and press Start. This links that private chat to your notifications."
  }
  KitRow {
    visible: (root.setupStep === 2 || root.setupStep === 3) && TelegramService.pairUrl !== ""
    label: root.chatOpened ? "After pressing Start" : "Open your bot's chat"
    KitButton {
      text: root.chatOpened ? "Open chat again" : "Open Telegram"
      primary: !root.chatOpened
      disabled: TelegramService.busy
      onClicked: if (root.openExternal(TelegramService.pairUrl)) root.chatOpened = true
    }
    KitButton {
      visible: root.chatOpened
      text: "Finish connection"; primary: true; busy: TelegramService.busy
      onClicked: TelegramService.run("pair", {})
    }
  }
  KitRow {
    visible: root.setupStep === 2 && TelegramService.pairUrl !== ""
    label: "Pressed Start already?"
    KitButton { text: "Finish connection"; busy: TelegramService.busy; onClicked: TelegramService.run("pair", {}) }
  }
  KitRow {
    visible: (root.setupStep === 2 || root.setupStep === 3) && TelegramService.pairUrl === ""
    label: "Renew the chat link"
    KitButton {
      text: "Create new link"; primary: true; busy: TelegramService.busy
      onClicked: if (TelegramService.run("renew", {})) root.chatOpened = false
    }
  }

  KitRow {
    visible: root.setupStep >= 2
    label: "Telegram bot"
    hint: "@" + TelegramService.username
    KitButton { text: root.manageConnection ? "Done" : "Manage"; disabled: TelegramService.busy; onClicked: root.manageConnection = !root.manageConnection }
  }
  KitRow {
    visible: root.setupStep === 4
    label: "Send a test notification"
    hint: "Check it arrives in your Telegram chat"
    KitButton { text: "Send test"; busy: TelegramService.busy; onClicked: TelegramService.run("test", {}) }
  }
  KitRow {
    visible: root.manageConnection && root.setupStep >= 2
    label: "Change bot"
    hint: "A different bot needs a new chat link"
    KitButton { text: "Change bot"; disabled: TelegramService.busy; onClicked: { root.editingBot = true; root.tokenEntry = true; } }
  }
  KitRow {
    visible: root.manageConnection && root.setupStep >= 2
    label: "Disconnect Telegram"
    hint: "Remove the saved bot and chat"
    KitResetButton {
      icon: "x"
      text: armed ? "Disconnect now?" : "Disconnect"
      changed: !TelegramService.busy
      onReset: { root.manageConnection = false; TelegramService.disconnect(); }
    }
  }
  KitText {
    width: parent.width
    text: root.linkError || TelegramService.error || (["Test sent", "Notification sent"].includes(TelegramService.status) ? TelegramService.status : "")
    visible: text !== ""
    color: root.linkError || TelegramService.error ? Theme.red : Theme.muted
    wrapMode: Text.WordWrap
  }

  KitLine { visible: root.showDelivery }
  KitLabel { id: deliveryGroup; visible: root.showDelivery; keepInFlat: true; text: "DELIVERY" }
  KitToggleRow {
    visible: root.showDelivery
    module: "telegram"; key: "enabled"; fallback: false
    label: "Forward notifications"
    hint: "New arrivals only, no saved history"
    needs: TelegramService.connected ? "" : "Finish connecting Telegram first"
  }
  KitToggleRow {
    visible: root.showRules
    module: "telegram"; key: "body"; fallback: true
    label: "Include message text"
    hint: "Off: app and title only"
  }
  KitToggleRow {
    visible: root.showRules
    module: "telegram"; key: "silent"; fallback: false
    label: "Send without sound"
    hint: "Keep Telegram alerts quiet"
  }

  KitLine { visible: root.showRules }
  KitLabel { visible: root.showRules; id: rulesGroup; keepInFlat: true; text: "RULES"; about: "Telegram notifications are always excluded to prevent loops. Desktop Focus mode does not pause forwarding." }
  KitOptionRow {
    visible: root.showRules
    module: "telegram"; key: "urgency"; fallback: "all"
    label: "Importance"
    model: [{ label: "All", value: "all" }, { label: "Normal and critical", value: "normal" }, { label: "Critical", value: "critical" }]
  }
  KitOptionRow {
    visible: root.showRules
    module: "telegram"; key: "filter"; fallback: "all"
    label: "Applications"
    model: [{ label: "All", value: "all" }, { label: "Only listed", value: "only" }, { label: "Except listed", value: "except" }]
  }
  KitRow {
    wide: true
    visible: root.showRules && ModuleSettings.get("telegram", "filter", "all") !== "all"
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
