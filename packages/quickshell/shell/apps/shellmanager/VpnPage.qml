import QtQuick
import qs.config
import qs.kit
import qs.modules.mihomo

// VPN: Mihomo, the proxy the shell drives — the tunnel's switch, the subscription it
// takes servers from, and its files. Picking a server is the bar popup's.
KitColumn {
  id: root

  readonly property var vpn: MihomoService
  readonly property bool listed: vpn.serviceOn && vpn.providers.length > 0

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "public"
  readonly property string title: "VPN"
  readonly property string description: "The Mihomo proxy: the tunnel, its subscription and its files."

  readonly property var jumps: [
    { key: "tunnel",       label: "Tunnel",       y: tunnelGroup.y },
    { key: "subscription", label: "Subscription", y: subscriptionGroup.y },
    { key: "files",        label: "Files",        y: filesGroup.y }
  ]

  spacing: Theme.sectionGap

  // ---- tunnel ----
  KitLabel { id: tunnelGroup; text: "TUNNEL"; value: vpn.serviceOn ? "ON · " + (vpn.mode || "—").toUpperCase() : "OFF" }

  KitRow {
    label: "Mihomo"
    hint: "The proxy service; off: nothing uses it"

    KitSwitch {
      checked: vpn.serviceOn
      onToggled: vpn.toggleService()
    }
  }

  KitGrouper {}

  // ---- subscription ----
  KitLabel { id: subscriptionGroup; text: "SUBSCRIPTION"; value: root.listed ? Format.count(vpn.nodes.length, "SERVER") : "" }

  KitText {
    visible: !root.listed
    width: parent.width
    text: vpn.serviceOn ? "No providers configured." : "Switch the tunnel on to see its providers."
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 1
  }

  KitRow {
    visible: root.listed
    wide: true
    label: "Provider"
    hint: "The subscription the servers come from"

    KitSelect {
      model: vpn.providers.map(p => ({ label: p.name, value: p.name }))
      current: vpn.provider
      onPicked: value => vpn.provider = value
    }
  }

  KitRow {
    label: "Update subscriptions"
    hint: "Fetches the server lists again"
    dimmed: !vpn.serviceOn

    KitButton {
      icon: "refresh"
      text: "Update"
      busy: vpn.updating
      disabled: !vpn.serviceOn
      onClicked: vpn.runUpdate()
    }
  }

  KitGrouper {}

  // ---- files ----
  KitLabel { id: filesGroup; text: "FILES"; about: "Open in the editor" }

  KitRow {
    label: "Subscription"
    hint: "The provider's file"
    dimmed: !root.listed || vpn.provider === ""

    KitButton {
      icon: "server"
      text: "Open"
      disabled: !root.listed || vpn.provider === ""
      onClicked: vpn.openProviderConfig(vpn.provider)
    }
  }

  KitRow {
    label: "Mihomo config"
    hint: "The proxy's own settings"

    KitButton {
      icon: "sliders"
      text: "Open"
      onClicked: vpn.openMihomoConfig()
    }
  }

  KitGrouper {}
}
