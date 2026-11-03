import QtQuick
import qs.config
import qs.kit
import qs.modules.wifi

// Network: Wi-Fi (the radio, the connection in use, the saved networks, a hidden
// network to join), the wired connection and the hotspot, one after another.
// Each group has the same order: its switch or state first, then the settings,
// then the facts.
KitColumn {
  id: root

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
  property bool showDetails: false        // the connection's facts, folded
  property bool showJoin: false           // a network by name, folded

  // DNS: the provider's label for some servers, and the servers of a label
  readonly property var dnsChoices: ws.dnsProviders.map(p => ({ label: p.label, value: p.label }))
  function dnsLabel(servers) { return ws.dnsProviders.find(p => p.servers === (servers ?? ""))?.label ?? "CUSTOM"; }
  function dnsServers(label) { return ws.dnsProviders.find(p => p.label === label)?.servers ?? ""; }

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "wifi"
  readonly property string title: "Network"
  readonly property string description: "Wi-Fi, wired connections and sharing this computer's connection."

  // groups for the Shell Manager's sidebar: a click scrolls to `y`
  readonly property var jumps: [
    { key: "wifi",       label: "Wi-Fi",      y: wifiGroup.y + wifiTab.y },
    { key: "connection", label: "Connection", y: ws.connected ? connectionGroup.y + wifiTab.y : -2 },
    { key: "saved",      label: "Saved",      y: savedGroup.y + wifiTab.y },
    { key: "new",        label: "Other",      y: newGroup.y + wifiTab.y },
    { key: "ethernet",   label: "Ethernet",   y: ethernetPart.y },
    { key: "hotspot",    label: "Hotspot",    y: hotspotPart.y }
  ].filter(j => j.y > -2)

  spacing: Theme.gapGroup

  // the page opens first, the system is asked a moment later: the replies (and the scan) landing in one
  // burst while the page builds and fades in made it stutter
  // the Loader makes the page already visible: the first show is not a change
  Component.onCompleted: visibleChanged()
  onVisibleChanged: {
    if (visible) loadSoon.restart();
    else {
      loadSoon.stop();
      ws.popupHidden();
    }
  }

  Timer {
    id: loadSoon
    interval: 300
    onTriggered: {
      ws.popupShown();      // status, networks, dns, details, ethernet, hotspot and a scan
      ws.refreshSaved();
    }
  }

  Timer { id: disarmDisconnect; interval: 3000; onTriggered: root.disconnectArmed = false }

  // ---- wi-fi ----
  KitColumn {
    id: wifiTab
    width: parent.width
    spacing: Theme.sectionGap

    // ---- wi-fi ----
    KitLabel { id: wifiGroup; text: "WI-FI" }

    KitRow {
      label: "Wi-Fi"
      hint: !ws.radioOn ? "Off: nothing connects" : ws.connected ? "Connected to " + ws.ssid : "On, not connected"

      KitSwitch {
        checked: ws.radioOn
        disabled: ws.toggling
        onToggled: ws.toggleRadio()
      }
    }

    KitLine {}

    KitText {
      width: parent.width
      visible: ws.statusError !== "" || ws.networkError !== "" || ws.radioError !== "" ||
               ws.connectError !== "" || ws.disconnectError !== ""
      text: ws.statusError || ws.networkError || ws.radioError || ws.connectError || ws.disconnectError
      color: Theme.red
      wrapMode: Text.WordWrap
    }

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
    KitLabel { id: savedGroup; text: "SAVED"; value: ws.savedLoaded ? root.inRange.length + " IN RANGE · " + ws.saved.length + " SAVED" : "" }

    KitText {
      visible: ws.savedError !== ""
      width: parent.width
      text: ws.savedError
      color: Theme.red
      wrapMode: Text.WordWrap
    }

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

    KitEmptyState {
      visible: ws.savedLoaded && ws.savedError === "" && ws.saved.length === 0
      icon: "wifi"
      title: "No saved networks"
      hint: "Join from the Wi-Fi popup or by name below"
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
        disabled: !(root.inRange.indexOf(root.chosen) >= 0) || ws.connectionBusy
        onClicked: ws.connect(root.chosen.ssid, "")
      }
    }

    KitRow {
      visible: root.chosen !== null
      label: "Connect automatically"
      hint: "Joins when it is in range"

      KitSwitch {
        checked: root.chosen?.autoconnect ?? false
        disabled: ws.savedBusy
        onToggled: ws.setSaved(root.chosen.uuid, "autoconnect", root.chosen.autoconnect ? "no" : "yes")
      }
    }

    KitRow {
      visible: root.chosen !== null
      wide: true
      label: "Priority"
      hint: "Higher joins first"

      KitSegments {
        disabled: ws.savedBusy
        model: [{ label: "Low", value: -10 }, { label: "Normal", value: 0 }, { label: "High", value: 10 }]
        current: root.chosen?.priority ?? 0
        onPicked: value => ws.setSaved(root.chosen.uuid, "priority", String(value))
      }
    }

    KitSelect {
      disabled: ws.savedBusy
      visible: root.chosen !== null
      label: "DNS"
      hint: "Applies at the next connect"
      model: root.dnsChoices
      current: root.dnsLabel(root.chosen?.dns)
      onPicked: value => ws.setSaved(root.chosen.uuid, "dns", root.dnsServers(value) || "auto")
    }

    MeteredRow { connection: root.chosen; service: ws }

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

      KitInput {
        id: newName
        placeholder: "SSID"
      }
    }

    KitRow {
      visible: root.showJoin
      wide: true
      label: "Password"
      hint: "Empty: an open network, not encrypted"
      hintLevel: "warn"

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
        busy: ws.connectionBusy
        disabled: !ws.radioOn || ws.connectionBusy || newName.text === ""
        onClicked: {
          ws.connectHidden(newName.text, newPass.text);
          newPass.text = "";
        }
      }
    }

    KitGrouper {}
  }

  NetworkEthernet {
    id: ethernetPart
    page: root
    width: parent.width
  }

  NetworkHotspot {
    id: hotspotPart
    page: root
    width: parent.width
  }

  KitGrouper {}
}
