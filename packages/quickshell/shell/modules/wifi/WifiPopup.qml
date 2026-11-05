import QtQuick
import qs.kit

// Wi-Fi popup: the overview, or a nested view (password) by WifiService.view.
KitFrame {
  id: root

  signal closeRequested()

  focus: true
  Keys.onEscapePressed: WifiService.view === "list" ? root.closeRequested() : WifiService.showList()

  WifiHeader {
    width: parent.width
    visible: WifiService.view !== "list"
  }

  WifiOverview {
    width: parent.width
    visible: WifiService.view === "list"
    onCloseRequested: root.closeRequested()
  }

  WifiPasswordView {
    width: parent.width
    visible: WifiService.view === "password"
  }
}
