import QtQuick
import qs.config
import qs.kit
import qs.modules.notifications

// One forwarding destination; connection controls exist only while unfolded.
Column {
  id: root
  spacing: Theme.sectionGap
  property string target: ""

  function open(key) {
    target = key.startsWith("telegram-") ? key.slice(9) : "";
    fold.open = "telegram";
  }
  function rowOf(key) {
    if (!key.startsWith("telegram")) return null;
    const row = fold.rowOf("telegram");
    return row?.settingsItem?.rowOf(key.slice(9)) ?? row;
  }

  KitLabel { text: "FORWARDING"; about: "Send new notifications to another service" }

  KitReorderList {
    id: fold
    width: root.width
    keys: ["telegram"]
    rowHeight: Theme.rowHeight
    delegate: KitFoldRow {
      id: row
      readonly property Item settingsItem: loader.item
      label: "Telegram"
      hint: TelegramService.error ? (TelegramService.connected ? "Delivery needs attention" : "Connection needs attention")
          : !TelegramService.stateKnown ? "Checking connection…"
          : TelegramService.connected ? "@" + TelegramService.username + (TelegramService.enabled ? " · Forwarding on" : " · Forwarding off")
          : TelegramService.configured ? (TelegramService.pairUrl === "" ? "Chat link expired" : "Finish connecting @" + TelegramService.username) : "Not connected"
      draggable: false
      hasSwitch: false
      checked: true
      foldable: true
      flush: true
      sunken: true
      leading: Component {
        Image {
          width: Theme.iconLarge
          height: width
          // Official artwork: https://telegram.org/img/t_logo.svg
          source: "assets/telegram.svg"
          sourceSize { width: Theme.iconLarge * 2; height: Theme.iconLarge * 2 }
          fillMode: Image.PreserveAspectFit
        }
      }
      Item {
        readonly property bool kitUnboxed: true
        readonly property bool kitFlat: true
        width: parent.width
        implicitHeight: loader.item ? loader.item.implicitHeight : 0
        height: implicitHeight
        Loader {
          id: loader
          width: parent.width
          active: row.unfolded
          sourceComponent: Component { TelegramSettings { revealGroup: root.target } }
        }
      }
    }
  }
  KitGrouper {}
}
