import QtQuick
import qs.config
import qs.kit

// Network › Ethernet: the wired connection, its address and DNS.
KitColumn {
  id: root

  required property var page    // the Network page

  readonly property var ws: page.ws
  readonly property var eth: page.eth

  property bool manualPick: false
  readonly property bool manual: eth?.method === "manual" || manualPick

  function applyManual() {
    if (eth?.uuid) ws.setSaved(eth.uuid, "ipv4", "manual", ethAddr.text + " " + ethGateway.text);
  }

  spacing: Theme.gapGroup

  // ---- wired ----
  KitLabel {
    id: ethernetGroup
    text: "ETHERNET"
    value: !eth ? "NO DEVICE" : eth.state === "connected" ? "CONNECTED" : eth.carrier ? "CABLE IN" : "NO CABLE"
  }

  KitEmptyState {
    visible: eth === null
    icon: "public"
    title: "No Ethernet adapter"
    hint: "Plug in an adapter to configure it"
  }

  KitRow {
    visible: eth !== null
    label: "Wired"
    hint: "Off until you connect again"

    KitButton {
      width: Theme.buttonWidth
      text: eth?.state === "connected" ? "Disconnect" : "Connect"
      busy: ws.ethernetBusy
      disabled: ws.ethernetBusy
      onClicked: ws.setEthernet(eth?.state !== "connected")
    }
  }

  KitRow {
    visible: eth !== null
    label: "Connect automatically"
    hint: "Joins when the cable is in"

    KitSwitch {
      checked: eth?.autoconnect ?? false
      disabled: !eth?.uuid || ws.savedBusy
      onToggled: ws.setSaved(eth.uuid, "autoconnect", eth.autoconnect ? "no" : "yes")
    }
  }

  KitRow {
    visible: eth !== null
    wide: true
    label: "Addressing"
    hint: "Manual: a fixed address"

    KitSegments {
      disabled: ws.savedBusy
      model: [{ label: "Auto", value: "auto" }, { label: "Manual", value: "manual" }]
      current: root.manual ? "manual" : "auto"
      onPicked: value => {
        if (value === "auto") {
          root.manualPick = false;
          if (eth?.uuid) ws.setSaved(eth.uuid, "ipv4", "auto");
        } else {
          root.manualPick = true;
        }
      }
    }
  }

  KitRow {
    visible: eth !== null && root.manual
    wide: true
    label: "Address"
    hint: "Address and prefix"

    KitInput {
      id: ethAddr
      enabled: !ws.savedBusy
      text: eth?.addresses ?? ""
      placeholder: "192.168.1.10/24"
      onAccepted: root.applyManual()
    }
  }

  KitRow {
    visible: eth !== null && root.manual
    wide: true
    label: "Gateway"
    hint: "Press Enter to apply"

    KitInput {
      id: ethGateway
      enabled: !ws.savedBusy
      text: eth?.gw ?? ""
      placeholder: "192.168.1.1"
      onAccepted: root.applyManual()
    }
  }

  KitSelect {
    disabled: ws.savedBusy
    visible: eth !== null
    label: "DNS"
    hint: "Applies now while connected"
    model: page.dnsChoices
    current: page.dnsLabel(eth?.dns)
    onPicked: value => ws.setSaved(eth.uuid, "dns", page.dnsServers(value) || "auto")
  }

  KitRow {
    visible: eth !== null
    label: "IPv6"
    hint: "Off: IPv4 only"

    KitSwitch {
      checked: eth?.ipv6 ?? true
      disabled: !eth?.uuid || ws.savedBusy
      onToggled: ws.setSaved(eth.uuid, "ipv6", eth.ipv6 ? "off" : "auto")
    }
  }

  KitRow {
    visible: eth !== null
    wide: true
    label: "Metered"
    hint: "Yes: apps save data"

    KitSegments {
      disabled: ws.savedBusy
      model: [{ label: "Auto", value: "unknown" }, { label: "Yes", value: "yes" }, { label: "No", value: "no" }]
      current: eth?.metered ?? "unknown"
      onPicked: value => ws.setSaved(eth.uuid, "metered", value)
    }
  }

  KitRow {
    visible: eth !== null
    label: "Address"
    KitText { text: eth?.ip || "—"; color: Theme.foreground2 }
  }

  KitRow {
    visible: eth !== null
    label: "Gateway"
    KitText { text: eth?.gateway || "—"; color: Theme.foreground2 }
  }

  KitRow {
    visible: eth !== null
    label: "Speed"
    KitText { text: eth?.speed || "—"; color: Theme.foreground2 }
  }

  KitRow {
    visible: eth !== null
    label: "MAC"
    KitText { text: eth?.mac ?? "—"; color: Theme.foreground2 }
  }

  KitText {
    visible: page.ws.ethernetError !== "" || page.ws.saveError !== ""
    text: page.ws.ethernetError || page.ws.saveError
    color: Theme.red
    wrapMode: Text.WordWrap
  }

  KitGrouper {}
}
