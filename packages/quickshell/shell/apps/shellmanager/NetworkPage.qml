import QtQuick
import qs.config
import qs.kit
import qs.modules.wifi

// Network, a tab each for Wi-Fi (the radio, the connection in use, the saved
// networks, a hidden network to join), the hotspot and the wired connection.
// Each group has the same order: its switch or state first, then the settings,
// then the facts.
KitColumn {
  id: root

  property string tab: "wifi"                 // wifi | hotspot | ethernet
  // the tabs the window's header shows
  readonly property var tabs: [{ label: "Wi-Fi", value: "wifi" }, { label: "Hotspot", value: "hotspot" }, { label: "Ethernet", value: "ethernet" }]

  readonly property var ws: WifiService
  readonly property var eth: ws.ethernet
  readonly property var hs: ws.hotspot

  // ---- the saved networks: those in range now, or all of them ----
  property string scope: "range"
  property string selected: ""
  readonly property var inRange: ws.saved.filter(p => ws.networks.some(n => n.ssid === p.ssid))
  readonly property var listed: scope === "range" ? inRange : ws.saved
  readonly property var chosen: listed.find(p => p.uuid === selected) ?? listed.find(p => p.active) ?? listed[0] ?? null

  // two-step actions: the first click asks, the second one does it
  property bool disconnectArmed: false
  property bool hotspotArmed: false
  property bool manualPick: false
  property bool showDetails: false        // the connection's facts, folded
  property bool showJoin: false           // a network by name, folded

  readonly property bool manual: eth?.method === "manual" || manualPick

  // DNS: the provider's label for some servers, and the servers of a label
  readonly property var dnsChoices: ws.dnsProviders.map(p => ({ label: p.label, value: p.label }))
  function dnsLabel(servers) { return ws.dnsProviders.find(p => p.servers === (servers ?? ""))?.label ?? "CUSTOM"; }
  function dnsServers(label) { return ws.dnsProviders.find(p => p.label === label)?.servers ?? ""; }

  function applyManual() {
    if (eth?.uuid) ws.setSaved(eth.uuid, "ipv4", "manual", ethAddr.text + " " + ethGateway.text);
  }

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "wifi"
  readonly property string title: "Network"
  readonly property string subtitle: !ws.radioOn ? "OFF" : ws.connected ? ws.ssid.toUpperCase() : "NOT CONNECTED"

  // groups for the Shell Manager's sidebar: a click scrolls to `y`
  // (only the open tab's: the others are not on the page)
  readonly property var jumps: tab !== "wifi" ? [] : [
    { key: "wifi",       label: "Wi-Fi",      y: wifiGroup.y + wifiTab.y },
    { key: "connection", label: "Connection", y: ws.connected ? connectionGroup.y + wifiTab.y : -2 },
    { key: "saved",      label: "Saved",      y: savedGroup.y + wifiTab.y },
    { key: "new",        label: "Other",      y: newGroup.y + wifiTab.y }
  ].filter(j => j.y > -2)

  // a link from another page (a module's Open) lands on the tab that holds the group
  function jump(key) {
    tab = key === "hotspot" || key === "ethernet" ? key : "wifi";
  }

  spacing: Theme.gapGroup

  onVisibleChanged: {
    if (visible) {
      ws.popupShown();
      ws.refreshSaved();
      ws.refreshDetails();
      ws.refreshEthernet();
      ws.refreshHotspot();
    } else {
      ws.popupHidden();
    }
  }

  Timer { id: disarmDisconnect; interval: 3000; onTriggered: root.disconnectArmed = false }
  Timer { id: disarmHotspot; interval: 3000; onTriggered: root.hotspotArmed = false }

  // ---- wi-fi tab ----
  KitColumn {
    id: wifiTab
    width: parent.width
    visible: root.tab === "wifi"
    spacing: Theme.gapGroup

    // ---- wi-fi ----
    KitLabel { id: wifiGroup; text: "WI-FI" }

    KitRow {
      label: "Wi-Fi"
      hint: !ws.radioOn ? "Off: nothing connects" : ws.connected ? "Connected to " + ws.ssid : "On, not connected"

      KitSwitch {
        accessibleName: "Wi-Fi"
        checked: ws.radioOn
        disabled: ws.toggling
        onToggled: ws.toggleRadio()
      }
    }

    KitLine {}

    // ---- the connection in use: its name and state, actions, facts folded ----
    KitLabel { id: connectionGroup; visible: ws.connected; text: "CONNECTION" }

    KitRow {
      visible: ws.connected
      label: ws.ssid
      hint: "Connected" + (root.ws.details ? " · " + (root.ws.details.freq >= 5000 ? "5 GHz" : "2.4 GHz") + " · " + (root.ws.details.security || "Open") : "")

      KitButton {
        width: Theme.buttonWidth
        text: root.disconnectArmed ? "Sure?" : "Disconnect"
        onClicked: {
          if (root.disconnectArmed) {
            root.disconnectArmed = false;
            ws.disconnectNetwork();
          } else {
            root.disconnectArmed = true;
            disarmDisconnect.restart();
          }
        }
      }
    }

    KitRow {
      visible: ws.connected
      label: "Speed test"
      hint: ws.speedtestBusy ? "Measuring…" : ws.speedtestError !== "" ? "Failed, try again"
        : ws.speedtest ? Math.round(ws.speedtest.down) + " down · " + Math.round(ws.speedtest.up) + " up Mbps"
        : "Download, upload and ping"

      KitButton {
        width: Theme.buttonWidth
        text: "Run"
        busy: ws.speedtestBusy
        disabled: ws.speedtestBusy
        onClicked: ws.measure()
      }
    }

    KitRow {
      visible: ws.connected
      label: "Details"
      hint: ws.ipAddress || "Address, gateway, channel, rate"

      KitButton {
        width: Theme.buttonWidth
        text: root.showDetails ? "Hide" : "Show"
        onClicked: root.showDetails = !root.showDetails
      }
    }

    Repeater {
      model: [
        { label: "Address",  value: ws.ipAddress || "—" },
        { label: "Gateway",  value: ws.gateway || "—" },
        { label: "Channel",  value: root.ws.details ? root.ws.details.chan + " · " + root.ws.details.freq + " MHz" : "—" },
        { label: "Rate",     value: ws.details?.rate ?? "—" },
        { label: "Security", value: ws.details?.security || "Open" },
        { label: "BSSID",    value: ws.details?.bssid ?? "—" }
      ]

      KitRow {
        required property var modelData
        visible: ws.connected && root.showDetails
        label: modelData.label
        labelColor: Theme.foreground2
        KitText { text: modelData.value; color: Theme.foreground0 }
      }
    }

    KitLine { visible: ws.connected }

    // ---- saved networks ----
    KitLabel { id: savedGroup; text: "SAVED"; value: root.inRange.length + " IN RANGE · " + ws.saved.length + " SAVED" }

    KitRow {
      visible: ws.saved.length > 0
      wide: true
      label: "Show"

      KitSegments {
        model: [{ label: "In range", value: "range" }, { label: "All", value: "all" }]
        current: root.scope
        onPicked: value => root.scope = value
      }
    }

    KitSelect {
      visible: root.listed.length > 0
      label: "Network"
      model: root.listed.map(p => ({
        label: p.ssid + (p.active ? " · connected" : (root.inRange.indexOf(p) >= 0) ? " · in range" : ""),
        value: p.uuid
      }))
      current: root.chosen?.uuid ?? ""
      onPicked: value => root.selected = value
    }

    KitText {
      visible: root.scope === "range" && root.inRange.length === 0 && ws.saved.length > 0
      width: parent.width
      text: "None in range. All lists " + ws.saved.length + " saved."
      color: Theme.muted
      wrapMode: Text.WordWrap
    }

    KitRow {
      visible: root.chosen !== null && !root.chosen.active
      label: "Connection"
      hint: (root.inRange.indexOf(root.chosen) >= 0) ? "Joins it now" : "Out of range"

      KitButton {
        width: Theme.buttonWidth
        text: "Connect"
        busy: ws.connectingSsid !== "" && ws.connectingSsid === root.chosen?.ssid
        disabled: !(root.inRange.indexOf(root.chosen) >= 0) || ws.connectingSsid !== ""
        onClicked: ws.connect(root.chosen.ssid, "")
      }
    }

    KitRow {
      visible: root.chosen !== null
      label: "Connect automatically"
      hint: "Joins when it is in range"

      KitSwitch {
        accessibleName: "Connect automatically"
        checked: root.chosen?.autoconnect ?? false
        onToggled: ws.setSaved(root.chosen.uuid, "autoconnect", root.chosen.autoconnect ? "no" : "yes")
      }
    }

    KitRow {
      visible: root.chosen !== null
      wide: true
      label: "Priority"
      hint: "Higher joins first"

      KitSegments {
        model: [{ label: "Low", value: -10 }, { label: "Normal", value: 0 }, { label: "High", value: 10 }]
        current: root.chosen?.priority ?? 0
        onPicked: value => ws.setSaved(root.chosen.uuid, "priority", String(value))
      }
    }

    KitSelect {
      visible: root.chosen !== null
      label: "DNS"
      hint: "Applies at the next connect"
      model: root.dnsChoices
      current: root.dnsLabel(root.chosen?.dns)
      onPicked: value => ws.setSaved(root.chosen.uuid, "dns", root.dnsServers(value) || "auto")
    }

    KitRow {
      visible: root.chosen !== null
      wide: true
      label: "Metered"
      hint: "Yes: apps save data"

      KitSegments {
        model: [{ label: "Auto", value: "unknown" }, { label: "Yes", value: "yes" }, { label: "No", value: "no" }]
        current: root.chosen?.metered ?? "unknown"
        onPicked: value => ws.setSaved(root.chosen.uuid, "metered", value)
      }
    }

    KitText {
      visible: ws.saveError !== ""
      width: parent.width
      text: ws.saveError
      color: Theme.red
      wrapMode: Text.WordWrap
    }

    KitLine {}

    // ---- a network by name (a hidden one), folded ----
    KitLabel { id: newGroup; text: "OTHER" }

    KitRow {
      label: "Join by name"
      hint: "A network that does not show"

      KitButton {
        width: Theme.buttonWidth
        text: root.showJoin ? "Hide" : "Join…"
        onClicked: root.showJoin = !root.showJoin
      }
    }

    KitRow {
      visible: root.showJoin
      wide: true
      label: "Name"
      hint: "A hidden one is typed here"

      KitInput {
        id: newName
        placeholder: "SSID"
      }
    }

    KitRow {
      visible: root.showJoin
      wide: true
      label: "Password"
      hint: "Empty: an open network"

      KitInput {
        id: newPass
        placeholder: "password"
        echoMode: TextInput.Password
      }
    }

    KitRow {
      visible: root.showJoin
      label: "Join"
      hint: ws.hiddenError !== "" ? ws.hiddenError : "Saved once it joins"

      KitButton {
        width: Theme.buttonWidth
        text: "Connect"
        busy: ws.hiddenBusy
        disabled: !ws.radioOn || newName.text === ""
        onClicked: {
          ws.connectHidden(newName.text, newPass.text);
          newPass.text = "";
        }
      }
    }

    KitGrouper {}
  }

  // ---- hotspot tab ----
  KitColumn {
    width: parent.width
    visible: root.tab === "hotspot"
    spacing: Theme.gapGroup

    // ---- hotspot: this machine shares its connection over Wi-Fi ----
    KitLabel {
      id: hotspotGroup
      text: "HOTSPOT"
      value: root.hs?.active ? "ON · " + root.hs.clients + " CLIENTS" : "OFF"
    }

    KitRow {
      label: "Hotspot"
      hint: !root.hs?.supported ? "This Wi-Fi card cannot host one"
        : !root.hs?.uuid ? "Set a password first"
        : "Wi-Fi drops while it is on"

      KitButton {
        width: Theme.buttonWidth
        text: root.hs?.active ? "Stop" : root.hotspotArmed ? "Sure?" : "Start"
        busy: ws.hotspotBusy
        disabled: !ws.radioOn || !(root.hs?.supported ?? false) || !(root.hs?.uuid ?? "") || ws.hotspotBusy
        onClicked: {
          if (root.hs?.active) {
            ws.setHotspot(false);
          } else if (ws.connected && !root.hotspotArmed) {
            root.hotspotArmed = true;
            disarmHotspot.restart();
          } else {
            root.hotspotArmed = false;
            ws.setHotspot(true);
          }
        }
      }
    }

    KitRow {
      wide: true
      label: "Name"
      hint: "The network the phones see"

      KitInput {
        text: root.hs?.ssid ?? ""
        placeholder: "name"
        onAccepted: ws.setHotspotSetting("ssid", text)
      }
    }

    KitRow {
      wide: true
      label: "Password"
      hint: "8 characters or more"

      KitInput {
        placeholder: "password"
        echoMode: TextInput.Password
        onAccepted: {
          ws.setHotspotSetting("password", text);
          text = "";
        }
      }
    }

    KitRow {
      wide: true
      label: "Channel"
      hint: "Auto picks a free one"

      KitSegments {
        model: [{ label: "Auto", value: "auto" }, { label: "1", value: "1" }, { label: "6", value: "6" }, { label: "11", value: "11" }]
        current: (root.hs?.channel ?? "0") === "0" ? "auto" : root.hs?.channel
        onPicked: value => ws.setHotspotSetting("channel", value)
      }
    }

    KitText {
      visible: ws.hotspotError !== ""
      width: parent.width
      text: ws.hotspotError
      color: Theme.red
      wrapMode: Text.WordWrap
    }

    KitGrouper {}
  }

  // ---- ethernet tab ----
  KitColumn {
    width: parent.width
    visible: root.tab === "ethernet"
    spacing: Theme.gapGroup

    // ---- wired ----
    KitLabel {
      id: ethernetGroup
      text: "ETHERNET"
      value: !root.eth ? "NO DEVICE" : root.eth.state === "connected" ? "CONNECTED" : root.eth.carrier ? "CABLE IN" : "NO CABLE"
    }

    KitRow {
      visible: root.eth !== null
      label: "Wired"
      hint: "Off until you connect again"

      KitButton {
        width: Theme.buttonWidth
        text: root.eth?.state === "connected" ? "Disconnect" : "Connect"
        busy: ws.ethernetBusy
        disabled: ws.ethernetBusy
        onClicked: ws.setEthernet(root.eth?.state !== "connected")
      }
    }

    KitRow {
      visible: root.eth !== null
      label: "Connect automatically"
      hint: "Joins when the cable is in"

      KitSwitch {
        accessibleName: "Connect automatically"
        checked: root.eth?.autoconnect ?? false
        disabled: !root.eth?.uuid
        onToggled: ws.setSaved(root.eth.uuid, "autoconnect", root.eth.autoconnect ? "no" : "yes")
      }
    }

    KitRow {
      visible: root.eth !== null
      wide: true
      label: "Addressing"
      hint: "Manual: a fixed address"

      KitSegments {
        model: [{ label: "Auto", value: "auto" }, { label: "Manual", value: "manual" }]
        current: root.manual ? "manual" : "auto"
        onPicked: value => {
          if (value === "auto") {
            root.manualPick = false;
            if (root.eth?.uuid) ws.setSaved(root.eth.uuid, "ipv4", "auto");
          } else {
            root.manualPick = true;
          }
        }
      }
    }

    KitRow {
      visible: root.eth !== null && root.manual
      wide: true
      label: "Address"
      hint: "Address and prefix"

      KitInput {
        id: ethAddr
        text: root.eth?.addresses ?? ""
        placeholder: "192.168.1.10/24"
        onAccepted: root.applyManual()
      }
    }

    KitRow {
      visible: root.eth !== null && root.manual
      wide: true
      label: "Gateway"
      hint: "Press Enter to apply"

      KitInput {
        id: ethGateway
        text: root.eth?.gw ?? ""
        placeholder: "192.168.1.1"
        onAccepted: root.applyManual()
      }
    }

    KitSelect {
      visible: root.eth !== null
      label: "DNS"
      hint: "Applies now while connected"
      model: root.dnsChoices
      current: root.dnsLabel(root.eth?.dns)
      onPicked: value => ws.setSaved(root.eth.uuid, "dns", root.dnsServers(value) || "auto")
    }

    KitRow {
      visible: root.eth !== null
      label: "IPv6"
      hint: "Off: IPv4 only"

      KitSwitch {
        accessibleName: "IPv6"
        checked: root.eth?.ipv6 ?? true
        disabled: !root.eth?.uuid
        onToggled: ws.setSaved(root.eth.uuid, "ipv6", root.eth.ipv6 ? "off" : "auto")
      }
    }

    KitRow {
      visible: root.eth !== null
      wide: true
      label: "Metered"
      hint: "Yes: apps save data"

      KitSegments {
        model: [{ label: "Auto", value: "unknown" }, { label: "Yes", value: "yes" }, { label: "No", value: "no" }]
        current: root.eth?.metered ?? "unknown"
        onPicked: value => ws.setSaved(root.eth.uuid, "metered", value)
      }
    }

    KitRow {
      visible: root.eth !== null
      label: "Address"
      KitText { text: root.eth?.ip || "—"; color: Theme.foreground2 }
    }

    KitRow {
      visible: root.eth !== null
      label: "Gateway"
      KitText { text: root.eth?.gateway || "—"; color: Theme.foreground2 }
    }

    KitRow {
      visible: root.eth !== null
      label: "Speed"
      KitText { text: root.eth?.speed || "—"; color: Theme.foreground2 }
    }

    KitRow {
      visible: root.eth !== null
      label: "MAC"
      KitText { text: root.eth?.mac ?? "—"; color: Theme.foreground2 }
    }

    KitText {
      visible: root.ws.ethernetError !== ""
      width: parent.width
      text: root.ws.ethernetError
      color: Theme.red
      wrapMode: Text.WordWrap
    }

    KitGrouper {}
  }

  KitGrouper {}
}
