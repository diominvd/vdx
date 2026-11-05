import QtQuick
import qs.kit

// Header of the password view: what it is about and a Back button to the list.
KitHeader {
  icon: "lock"
  title: "Connect"
  subtitle: (WifiService.selected?.ssid ?? "").toUpperCase()

  KitButton {
    icon: "arrow-left"
    text: "Back"
    onClicked: WifiService.showList()
  }
}
