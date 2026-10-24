import QtQuick
import qs.components
import qs.config
import qs.kit

// The Wi-Fi list view: header with the radio switch, the connection (address,
// signal, traffic, DNS), nearby networks, and actions in the footer.
Column {
  id: root
  // rows already on show: a new one eases in (KitAppear)
  property KitSeen seen: KitSeen {}

  readonly property var active: WifiService.networks.find(n => n.ssid === WifiService.ssid) ?? null
  readonly property int signal: active ? active.signal : 0
  readonly property string quality: signal >= 75 ? "Excellent" : signal >= 50 ? "Good"
                                  : signal >= 25 ? "Fair" : "Weak"
  readonly property bool measured: WifiService.connected && WifiService.pingMs > 0

  spacing: Theme.gapGroup

  // ---- header ----
  KitHeader {
    icon: WifiService.radioOn ? "wifi" : "wifi-off"
    iconColor: WifiService.connected ? Theme.foreground0 : Theme.muted
    title: WifiService.connected ? WifiService.ssid : "Wi-Fi"
    subtitle: !WifiService.radioOn ? "OFF"
      : WifiService.connected ? "CONNECTED"
      : "DISCONNECTED"

    KitBadge {
      anchors.verticalCenter: parent.verticalCenter
      visible: WifiService.radioOn
      text: WifiService.networks.length + " NEARBY"
      tint: Theme.muted
    }

    KitSwitch {
      accessibleName: "Wi-Fi"
      anchors.verticalCenter: parent.verticalCenter
      checked: WifiService.radioOn
      onToggled: WifiService.toggleRadio()
    }
  }

  KitLine {}

  // ---- connection ----
  Column {
    width: parent.width
    visible: WifiService.connected
    spacing: Theme.gapLoose

    KitLabel { text: "CONNECTION"; value: WifiService.gateway ? "GATEWAY " + WifiService.gateway : "" }

    Item {
      width: parent.width
      height: address.implicitHeight

      KitText {
        id: address
        width: Math.max(0, parent.width - quality.implicitWidth - 12)
        text: "This PC  " + (WifiService.ipAddress || "—")
        elide: Text.ElideRight
      }

      KitText {
        id: quality
        anchors.right: parent.right
        text: root.measured ? "ping " + Math.round(WifiService.pingMs) + " ms · loss " + Math.round(WifiService.packetLoss) + "%" : "ping —"
        color: root.measured ? Theme.pingColor(WifiService.pingMs) : Theme.muted
        font.pixelSize: Theme.fontSize - 1
      }
    }

    Column {
      width: parent.width
      spacing: 5

      Item {
        width: parent.width
        height: signalText.implicitHeight

        KitText {
          id: signalText
          text: "Signal · " + root.quality
          color: Theme.foreground2
          font.pixelSize: Theme.fontSize - 1
        }

        KitText {
          anchors.right: parent.right
          text: root.signal + " %"
          color: Theme.foreground2
          font.pixelSize: Theme.fontSize - 1
        }
      }

      KitBar {
        value: root.signal / 100
        tint: Theme.qualityColor(root.signal, 60, 35)
      }
    }

    Item {
      width: parent.width
      height: traffic.implicitHeight

      KitText {
        id: traffic
        text: "Traffic now"
        color: Theme.foreground2
        font.pixelSize: Theme.fontSize - 1
      }

      KitText {
        anchors.right: parent.right
        text: "↓ " + Format.humanRate(WifiService.down) + "   ↑ " + Format.humanRate(WifiService.up)
        font.pixelSize: Theme.fontSize - 1
      }
    }

    KitSelect {
      label: "DNS"
      hint: WifiService.dnsError !== "" ? WifiService.dnsError : "For this network"
      model: WifiService.dnsProviders.map(p => ({ label: p.label, value: p.label }))
      current: WifiService.dnsLabel
      busy: WifiService.dnsBusy
      onPicked: value => WifiService.setDns(WifiService.dnsProviders.find(p => p.label === value).servers)
    }
  }

  KitLine { visible: WifiService.connected }

  // ---- networks ----
  Column {
    width: parent.width
    spacing: Theme.gapMedium

    KitLabel {
      text: !WifiService.radioOn ? "WI-FI IS OFF" : "NETWORKS (" + WifiService.networks.length + ")"
    }

    Flickable {
      width: parent.width
      visible: WifiService.networks.length > 0
      height: Math.min(contentHeight, 30 * Theme.visibleRows)
      contentHeight: rows.implicitHeight
      interactive: contentHeight > height
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: rows
        width: parent.width

        Repeater {
          model: WifiService.networks
          // a network found by a scan eases in
          NetworkRow {
            id: net
            width: rows.width
            KitAppear { target: net; seen: root.seen; key: net.modelData.ssid }
          }
        }
      }
    }
  }

  KitLine {}

  // ---- actions ----
  Row {
    spacing: Theme.gapMedium

    KitButton {
      icon: "refresh"
      text: "Rescan"
      disabled: !WifiService.radioOn
      onClicked: WifiService.scan()
    }

    KitButton {
      icon: "gauge"
      text: "Speed test"
      disabled: !WifiService.connected
      onClicked: WifiService.showSpeedtest()
    }
  }
}
