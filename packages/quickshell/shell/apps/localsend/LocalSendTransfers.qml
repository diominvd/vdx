import QtQuick
import QtQuick.Controls
import qs.config
import qs.kit

// Transfers of this session: the ones still running (with their progress and
// cancel), then the finished ones. The service owns the list; the page only
// draws it.
Item {
  id: root

  readonly property var svc: LocalSendService
  // transfers change through setProperty: the copies below are taken again on dataChanged
  property int revision: 0

  readonly property var active: {
    const change = root.revision;
    const rows = [];
    for (let i = 0; i < svc.transfers.count; i++) {
      const t = svc.transfers.get(i);
      if (t.state === "active" || t.state === "starting") rows.push(t);
    }
    return rows;
  }

  readonly property var finished: {
    const change = root.revision;
    const rows = [];
    for (let i = 0; i < svc.transfers.count; i++) {
      const t = svc.transfers.get(i);
      if (t.state === "completed" || t.state === "failed" || t.state === "cancelled") rows.push(t);
    }
    return rows;
  }

  function details(t) {
    const count = Math.max(svc.copyFiles(t.files).length, Number(t.totalFiles) || 0);
    const size = Number(t.totalBytes) || Number(t.transferredBytes) || 0;
    const parts = [];
    if (count > 0) parts.push(Format.count(count, "file"));
    if (size > 0) parts.push(Format.humanSize(size));
    return parts.join(" · ");
  }

  // what a row's second line says
  function stateText(t) {
    const info = root.details(t);
    let what;
    if (t.state === "active" || t.state === "starting")
      what = t.direction === "receive" ? "Receiving" : "Sending";
    else if (t.state === "completed")
      what = t.direction === "receive" ? "Received" : "Sent";
    else if (t.state === "failed") return "Failed";
    else return "Cancelled";
    return info !== "" ? what + " · " + info : what;
  }

  Connections {
    target: root.svc.transfers
    function onCountChanged() { root.revision += 1; }
    function onDataChanged() { root.revision += 1; }
  }

  ListView {
    id: list
    anchors.fill: parent
    clip: true
    model: root.active.concat(root.finished.slice().reverse())
    spacing: Theme.sectionGap
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: KitScrollBar {}

    delegate: Column {
      id: row
      required property var modelData
      readonly property bool running: modelData.state === "active" || modelData.state === "starting"
      readonly property real progress: Math.max(0, Math.min(1, Number(modelData.totalBytes) > 0
        ? modelData.transferredBytes / modelData.totalBytes : 0))
      width: ListView.view.width
      spacing: Theme.gapSmall

      LocalSendEntry {
        title: row.modelData.deviceAlias || "A device"
        detail: row.modelData.error || root.stateText(row.modelData)
        detailColor: row.modelData.state === "failed" ? Theme.red : Theme.muted
        icon: row.modelData.direction === "receive" ? "download" : "arrow-up"
        tone: row.modelData.state === "failed" ? Theme.red : row.modelData.state === "completed" ? Theme.green : Theme.foreground2
        KitText {
          anchors.verticalCenter: parent.verticalCenter
          visible: row.running && row.modelData.totalBytes > 0
          text: Math.round(row.progress * 100) + "%"
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 2
        }
        KitButton {
          visible: row.running
          icon: "x"
          Accessible.name: "Cancel transfer with " + (row.modelData.deviceAlias || "device")
          onClicked: root.svc.cancelTransfer(row.modelData.transferId)
        }
      }

      Rectangle {
        visible: row.running
        width: parent.width
        height: Theme.gapHair
        radius: Theme.radiusFor(height)
        color: Theme.background1
        Rectangle {
          width: parent.width * row.progress
          height: parent.height
          radius: parent.radius
          color: Theme.foreground0
          Behavior on width { enabled: Motion.controls; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
        }
      }
      KitLine { visible: !row.running; sectionBreak: false }
    }

    KitEmptyState {
      anchors.centerIn: parent
      width: parent.width
      visible: list.count === 0
      centered: true
      title: "No transfers yet"
      hint: "Sent and received files will appear here"
    }
  }
}
