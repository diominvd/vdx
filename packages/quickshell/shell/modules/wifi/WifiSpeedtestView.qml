import QtQuick
import qs.config
import qs.kit

// Speed test result: the path machine → router → internet with the latency of
// each leg, the spread of the latency, download / upload / ping in large type
// with level bars, and the live throughput beside Run again.
Column {
  id: root

  readonly property var result: WifiService.speedtest
  readonly property real wan: result ? Math.max(0, result.ping - (result.lan || 0)) : 0

  function num(value) {
    return value < 10 ? value.toFixed(1) : String(Math.round(value));
  }

  function ms(value) {
    return root.result && value > 0 ? root.num(value) + " ms" : "—";
  }

  // speed on a log scale: 1 Mbps is a sliver, 1 Gbps is full
  function speedLevel(mbps) {
    return Math.log(1 + mbps) / Math.log(1001);
  }

  spacing: Theme.gapGroup

  KitLine {}

  // ---- path ----
  Column {
    width: parent.width
    spacing: Theme.gapWide

    KitLabel { text: "PATH" }

    Row {
      id: path

      // legs keep room for "9999 ms"; the stops keep their names and share
      // the rest for the addresses, which shrink in proportion
      readonly property real legMin: Math.ceil(legMetrics.advanceWidth) + 4
      readonly property real names: machine.nameWidth + router.nameWidth + internet.nameWidth
      readonly property real hints: machine.naturalWidth + router.naturalWidth + internet.naturalWidth - names
      readonly property real hintScale: hints > 0 ? Math.max(0, Math.min(1, (width - 2 * legMin - 4 * spacing - names) / hints)) : 1
      readonly property real linkWidth: Math.max(0, (width - names - hintScale * hints - 4 * spacing) / 2)

      function stopWidth(stop) {
        return stop.nameWidth + hintScale * (stop.naturalWidth - stop.nameWidth);
      }

      width: parent.width
      spacing: Theme.gapSmall

      TextMetrics { id: legMetrics; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 1; text: "9999 ms" }

      SpeedtestStop { id: machine; width: path.stopWidth(machine); icon: "laptop"; name: "This PC"; hint: root.result?.dev || "—" }
      SpeedtestLeg { width: path.linkWidth; ms: root.result?.lan ?? 0; label: root.ms(ms); caption: "LOCAL" }
      SpeedtestStop { id: router; width: path.stopWidth(router); icon: "wifi"; name: "Router"; hint: root.result?.gateway || "—" }
      SpeedtestLeg { width: path.linkWidth; ms: root.wan; label: root.ms(ms); caption: "WAN" }
      SpeedtestStop { id: internet; width: path.stopWidth(internet); icon: "server"; name: "Internet"; hint: root.result?.ip || "—" }
    }

    KitLabel {
      text: "LAG"
      value: root.result
        ? "min " + root.num(root.result.best) + " · avg " + root.num(root.result.ping) + " · max " + root.num(root.result.worst) + " ms"
        : "—"
      valueColor: Theme.foreground2
    }
  }

  KitLine {}

  // ---- result ----
  Row {
    id: metrics

    readonly property int gap: 16

    width: parent.width
    spacing: gap

    Repeater {
      model: [
        { label: "DOWNLOAD", value: root.result?.down ?? 0, unit: "Mbps",
          level: root.speedLevel(root.result?.down ?? 0),
          tint: Theme.qualityColor(root.result?.down ?? 0, 50, 10) },
        { label: "UPLOAD", value: root.result?.up ?? 0, unit: "Mbps",
          level: root.speedLevel(root.result?.up ?? 0),
          tint: Theme.qualityColor(root.result?.up ?? 0, 20, 5) },
        { label: "PING", value: root.result?.ping ?? 0,
          unit: "jitter " + root.ms(root.result?.jitter ?? 0),
          level: 1 - Math.min(1, (root.result?.ping ?? 0) / 200),
          tint: Theme.pingColor(root.result?.ping ?? 0) }
      ]

      Column {
        required property var modelData

        width: Math.max(0, (metrics.width - 2 * metrics.gap) / 3)
        spacing: Theme.gapSmall

        KitLabel { text: modelData.label }

        KitText {
          width: parent.width
          elide: Text.ElideRight
          text: root.result ? (modelData.value < 10 ? modelData.value.toFixed(1) : Math.round(modelData.value)) : "—"
          color: root.result ? Theme.foreground0 : Theme.gray
          font.pixelSize: Theme.fontSize + 9
          font.weight: Font.ExtraBold
        }

        KitBar {
          value: root.result ? modelData.level : 0
          tint: modelData.tint
        }

        KitText {
          width: parent.width
          text: modelData.unit
          color: Theme.muted
          elide: Text.ElideRight
          font.pixelSize: Theme.fontSize - 2
        }
      }
    }
  }

  KitText {
    width: parent.width
    visible: WifiService.speedtestError !== "" && !WifiService.speedtestBusy
    text: WifiService.speedtestError
    color: Theme.red
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSize - 1
  }

  KitLine {}

  // ---- footer ----
  Item {
    width: parent.width
    height: Math.max(throughput.implicitHeight, runButton.height)

    Column {
      id: throughput
      anchors { left: parent.left; verticalCenter: parent.verticalCenter }
      width: Math.max(0, parent.width - runButton.width - Theme.gapMedium)
      spacing: Theme.gapHair

      KitLabel { width: Math.min(140, parent.width); text: "THROUGHPUT NOW" }

      KitText {
        width: parent.width
        elide: Text.ElideRight
        text: "↓ " + Format.humanRate(WifiService.down) + "   ↑ " + Format.humanRate(WifiService.up)
        font.pixelSize: Theme.fontSize - 1
      }
    }

    KitButton {
      id: runButton
      anchors { right: parent.right; verticalCenter: parent.verticalCenter }
      icon: "refresh"
      text: "Run again"
      busy: WifiService.speedtestBusy
      onClicked: WifiService.showSpeedtest()
    }
  }
}
