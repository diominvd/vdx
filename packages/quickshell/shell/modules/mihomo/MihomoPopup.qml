import QtQuick
import qs.components
import qs.config
import qs.kit

// Mihomo: the tunnel's switch, its state and traffic and the choice of a server. The provider
// and the files are the VPN page of the Shell Manager (the button at the foot).
KitFrame {
  id: root

  // how many servers show before the list scrolls: VPN › Servers shown
  readonly property int rows: ModuleSettings.get("mihomo", "serverRows", Theme.visibleRows)
  // Modules › VPN › Compact popup: no connection details (ping, provider, traffic)
  readonly property bool compact: ModuleSettings.get("mihomo", "compact", false)
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
      text: Format.count(MihomoService.nodes.length, "SERVER")
    }

    KitSwitch {
      anchors.verticalCenter: parent.verticalCenter
      checked: MihomoService.serviceOn
      onToggled: MihomoService.toggleService()
    }
  }

  KitLine {}

  // ---- connection ----
  Column {
    width: parent.width
    visible: MihomoService.serviceOn && !root.compact
    spacing: Theme.gapLoose

    KitLabel {
      text: "CONNECTION"
      value: MihomoService.currentDelay > 0 ? "PING " + MihomoService.currentDelay + " MS" : "PING —"
      valueColor: Theme.pingColor(MihomoService.currentDelay)
    }

    Column {
      width: parent.width
      spacing: Theme.gapHair

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

  KitLine { visible: MihomoService.serviceOn && !root.compact }

  // ---- routing ----
  KitText {
    visible: !root.listed
    text: MihomoService.serviceOn ? "No providers configured." : "Mihomo is off. Switch it on above."
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 1
  }

  Column {
    width: parent.width
    visible: root.listed
    spacing: Theme.gapLoose

    KitLabel {
      text: "SERVERS (" + MihomoService.nodes.length + ")"
      value: "PING"
    }

    Flickable {
      width: parent.width
      visible: MihomoService.nodes.length > 0
      height: Math.min(contentHeight, 30 * root.rows)
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
            color: current ? Theme.selectedFill : area.containsMouse ? Theme.background1 : Theme.clear
            Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

            KitText {
              anchors { left: parent.left; leftMargin: Theme.gapLoose; right: ping.left; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
              text: server.modelData.name
              elide: Text.ElideRight
              color: server.current ? Theme.selectedText : area.containsMouse ? Theme.foreground0 : Theme.foreground2
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
  Row {
    width: parent.width
    spacing: Theme.gapMedium

    KitButton {
      id: pingButton
      icon: "zap"
      text: "Ping"
      busy: MihomoService.pinging
      disabled: !MihomoService.serviceOn
      onClicked: MihomoService.pingNodes()
    }

    KitButton {
      width: parent.width - pingButton.width - parent.spacing
      icon: "sliders"
      text: "Open settings"
      onClicked: {
        root.closeRequested();
        ShellIpc.call("shell", "open", ["vpn"]);
      }
    }
  }
}
