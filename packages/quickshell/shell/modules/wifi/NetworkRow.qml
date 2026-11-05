import QtQuick
import qs.config
import qs.kit

// One nearby network: name, lock for secured ones, check on the current one,
// signal bars. The current row sits in the raised tone; click connects.
Rectangle {
  radius: Theme.radiusControl
  id: root

  required property var modelData

  readonly property bool current: WifiService.connected && modelData.ssid === WifiService.ssid
  readonly property bool connecting: WifiService.connectingSsid === modelData.ssid
  readonly property bool available: WifiService.radioOn && !current && !WifiService.connectionBusy
  activeFocusOnTab: true
  enabled: available
  Accessible.role: Accessible.Button
  Accessible.name: modelData.ssid + (modelData.secure ? ", secured network" : ", open network")
      + (current ? ", connected" : "")
  Accessible.onPressAction: activate()
  Keys.onSpacePressed: event => { if (!event.isAutoRepeat) activate(); }
  Keys.onReturnPressed: event => { if (!event.isAutoRepeat) activate(); }

  function activate() {
    if (available) WifiService.connectTo(modelData);
  }

  height: 30
  color: current ? Theme.selectedFill : hover.hovered ? Theme.background1 : Theme.clear
  Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

  HoverHandler { id: hover }

  Rectangle {
    anchors.fill: parent
    radius: parent.radius
    color: Theme.clear
    border.width: Theme.focusWidth
    border.color: Theme.focusRing
    visible: root.activeFocus
  }

  KitText {
    id: name
    x: 10
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, check.x - x - 8 - (lock.visible ? lock.width + 6 : 0))
    text: root.modelData.ssid
    elide: Text.ElideRight
    color: root.current ? Theme.selectedText : hover.hovered ? Theme.foreground0 : Theme.foreground2
    Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
    font.weight: root.current ? Font.ExtraBold : Font.DemiBold
  }

  KitIcon {
    id: lock
    visible: root.modelData.secure
    anchors { left: name.right; leftMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
    name: "lock"
    tint: Theme.muted
    size: 12
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: root.current ? Qt.ArrowCursor : Qt.PointingHandCursor
    onClicked: { root.forceActiveFocus(); root.activate(); }
  }

  KitIcon {
    id: check
    anchors { right: bars.left; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
    opacity: root.current ? 1 : 0
    name: "check"
    tint: Theme.green
    size: Theme.iconSmall
  }

  Item {
    id: bars
    anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
    width: 18
    height: 14

    SignalBars {
      anchors.centerIn: parent
      visible: !root.connecting
      strength: root.modelData.signal
    }

    KitSpinner {
      anchors.centerIn: parent
      visible: root.connecting
    }
  }
}
