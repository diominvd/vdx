import QtQuick
import qs.config
import qs.kit

// Mihomo: the tunnel's state and traffic, provider and server choice, and
// the actions (ping all, update subscriptions, open the config) in the footer.
KitFrame {
  id: root

  readonly property bool listed: MihomoService.serviceOn && MihomoService.providers.length > 0

  signal closeRequested()

  // ---- header ----
  KitHeader {
    icon: "public"
    iconColor: MihomoService.serviceOn ? Theme.foreground0 : Theme.muted
    title: "Mihomo"
    subtitle: MihomoService.serviceOn
      ? "CONNECTED · " + (MihomoService.mode || "—").toUpperCase()
      : "OFF"

    KitBadge {
      anchors.verticalCenter: parent.verticalCenter
      visible: MihomoService.serviceOn && MihomoService.nodes.length > 0
      text: MihomoService.nodes.length + " SERVERS"
    }

    KitSwitch {
      accessibleName: "Proxy service"
      anchors.verticalCenter: parent.verticalCenter
      checked: MihomoService.serviceOn
      onToggled: MihomoService.toggleService()
    }
  }

  KitLine {}

  // ---- connection ----
  Column {
    width: parent.width
    visible: MihomoService.serviceOn
    spacing: Theme.gapLoose

    KitLabel {
      text: "CONNECTION"
      value: MihomoService.currentDelay > 0 ? "PING " + MihomoService.currentDelay + " MS" : "PING —"
      valueColor: Theme.pingColor(MihomoService.currentDelay)
    }

    Column {
      width: parent.width
      spacing: 3

      KitText {
        width: parent.width
        text: MihomoService.current || "—"
        wrapMode: Text.Wrap
        font.weight: Font.ExtraBold
      }

      KitText {
        width: parent.width
        text: "via " + (MihomoService.currentProvider || "—") + " · group " + MihomoService.group
        elide: Text.ElideRight
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 2
      }
    }

    KitInfo {
      label: "Traffic now"
      value: "↓ " + Format.humanRate(MihomoService.down) + "   ↑ " + Format.humanRate(MihomoService.up)
    }

    KitInfo {
      label: "Session total"
      value: "↓ " + Format.humanSize(MihomoService.downTotal) + "   ↑ " + Format.humanSize(MihomoService.upTotal)
      valueColor: Theme.foreground2
    }
  }

  KitLine { visible: MihomoService.serviceOn }

  // ---- routing ----
  KitText {
    visible: !root.listed
    text: MihomoService.serviceOn ? "No providers configured." : "Mihomo is off. Switch it on to pick a server."
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 1
  }

  Column {
    width: parent.width
    visible: root.listed
    spacing: Theme.gapLoose

    KitSelect {
      label: "Provider"
      hint: "Subscription in use"
      model: MihomoService.providers.map(p => ({ label: p.name, value: p.name }))
      current: MihomoService.provider
      onPicked: value => MihomoService.provider = value
    }

    KitLabel {
      text: "SERVERS (" + MihomoService.nodes.length + ")"
      value: "PING"
    }

    Flickable {
      width: parent.width
      visible: MihomoService.nodes.length > 0
      height: Math.min(contentHeight, 30 * Theme.visibleRows)
      contentHeight: servers.implicitHeight
      interactive: contentHeight > height
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: servers
        width: parent.width

        Repeater {
          model: MihomoService.nodes

          Rectangle {
            radius: Theme.radiusControl
            id: server

            required property var modelData

            readonly property bool current: modelData.name === MihomoService.current
            readonly property int delay: modelData.alive ? modelData.delay : 0

            width: servers.width
            height: 30
            color: current ? Theme.background3 : area.containsMouse ? Theme.background1 : Theme.clear
            Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

            KitText {
              anchors { left: parent.left; leftMargin: Theme.gapLoose; right: ping.left; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
              text: server.modelData.name
              elide: Text.ElideRight
              color: server.current || area.containsMouse ? Theme.foreground0 : Theme.foreground2
              Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
              font.weight: server.current ? Font.ExtraBold : Font.DemiBold
            }

            KitText {
              id: ping
              anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
              text: server.delay > 0 ? server.delay + " ms" : "—"
              color: Theme.pingColor(server.delay)
              font.pixelSize: Theme.fontSize - 1
            }

            MouseArea {
              id: area
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: server.current ? Qt.ArrowCursor : Qt.PointingHandCursor
              onClicked: if (!server.current) MihomoService.selectNode(server.modelData.name)
            }
          }
        }
      }
    }
  }

  KitText {
    width: parent.width
    visible: MihomoService.error !== ""
    text: MihomoService.error
    color: Theme.red
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSize - 1
  }

  KitLine {}

  // ---- actions ----
  Item {
    width: parent.width
    height: 30

    Row {
      spacing: Theme.gapMedium

      KitButton {
        icon: "zap"
        text: "Ping"
        busy: MihomoService.pinging
        disabled: !MihomoService.serviceOn
        onClicked: MihomoService.pingNodes()
      }

      KitButton {
        icon: "refresh"
        text: "Update"
        busy: MihomoService.updating
        disabled: !MihomoService.serviceOn
        onClicked: MihomoService.runUpdate()
      }
    }

    // open in the editor: the provider's subscription, mihomo's config
    Row {
      anchors.right: parent.right
      spacing: Theme.gapMedium

      KitButton {
        icon: "server"
        disabled: !root.listed || MihomoService.provider === ""
        onClicked: {
          root.closeRequested();
          MihomoService.openProviderConfig(MihomoService.provider);
        }
      }

      KitButton {
        icon: "sliders"
        onClicked: {
          root.closeRequested();
          MihomoService.openMihomoConfig();
        }
      }
    }
  }
}
