import QtQuick
import Quickshell
import qs.bar
import qs.components
import qs.config
import qs.kit

// Bar module: charge with a state icon (charging, plugged, power saver).
Item {
  id: root

  required property PanelWindow bar

  // the Folder opens this module's popup when its tile is clicked
  function openPopup() { popup.toggle(); }

  visible: BatteryService.present
  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  activeFocusOnTab: true
  Accessible.role: Accessible.Button
  Accessible.name: BarLayout.label("battery")
  Accessible.description: "Open battery and power details"

  Keys.onPressed: event => {
    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
    if (!event.isAutoRepeat) popup.toggle();
    event.accepted = true;
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusControl
    color: "transparent"
    border.width: root.activeFocus ? 2 : 0
    border.color: Theme.foreground0
  }

  // Content with "Charge only" drops the icon; Name and Icon keep it
  readonly property bool showIcon: ModuleSettings.get("battery", "text", "content") !== "content"
    || ModuleSettings.get("battery", "shows", "both") !== "charge"

  KitBarItem {
    id: label
    icon: !root.showIcon ? "" : BatteryService.saver ? "battery-saver" : BatteryService.charging ? "battery-bolt"
        : BatteryService.plugged ? "battery-plugged" : BatteryService.levelIcon
    // Charge only: a plus while charging (Plus while charging)
    text: BarLayout.faceText("battery", String(BatteryService.capacity)
      + (!root.showIcon && BatteryService.charging && ModuleSettings.get("battery", "plus", true) ? "+" : ""))
    tint: BatteryService.saver ? Theme.accentFor("modules", Theme.green)
         : BatteryService.charging ? Theme.accentFor("modules", Theme.green)
         : BatteryService.capacity <= BatteryService.critical ? Theme.red
         : BatteryService.capacity <= BatteryService.warning ? Theme.yellow
         : Theme.foreground0
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); popup.toggle(); }
  }

  BarPopup {
    id: popup
    anchorItem: root
    ipcTarget: "battery"
    bar: root.bar
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    onShown: BatteryService.popupShown()
    onHidden: BatteryService.popupHidden()

    BatteryPopup {
      id: content
      anchors.fill: parent
    }
  }
}
