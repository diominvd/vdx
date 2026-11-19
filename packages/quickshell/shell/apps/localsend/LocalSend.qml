import QtQuick
import qs.config
import qs.kit

// LocalSend workspace. Draft selection survives page changes; pages load on demand.
Rectangle {
  id: root

  color: Theme.background0

  readonly property var svc: LocalSendService
  property string page: "send"
  QtObject {
    id: sendDraft
    property string query: ""
    property string fingerprint: ""
    property var queue: []
    function addPaths(paths) {
      const next = queue.slice();
      for (const picked of paths) {
        const path = String(picked && typeof picked === "object" ? picked.path : picked);
        if (path === "" || next.some(file => file.path === path)) continue;
        if (next.length >= 100) break;
        const clean = path.replace(/\\/g, "/").replace(/\/$/, "");
        next.push({path: path, name: clean.slice(clean.lastIndexOf("/") + 1) || clean,
          size: picked && typeof picked === "object" ? Number(picked.size) || 0 : 0});
      }
      queue = next;
    }
  }

  // transfers change through setProperty: the copies below are taken again on dataChanged
  property int transferRevision: 0

  // the newest transfer still running, for the foot
  readonly property var activeJob: {
    const revision = root.transferRevision;
    for (let i = svc.transfers.count - 1; i >= 0; i--) {
      const t = svc.transfers.get(i);
      if (t.state === "active" || t.state === "starting") return t;
    }
    return null;
  }

  function subtitle() {
    if (!svc.serviceAvailable)
      return svc.processStatus === "starting" ? "STARTING…" : "UNAVAILABLE";
    if (root.page === "send")
      return svc.deviceByFingerprint(sendDraft.fingerprint) ? "TO " + svc.deviceByFingerprint(sendDraft.fingerprint).alias.toUpperCase() : "FILES ON YOUR LOCAL NETWORK";
    if (root.page === "transfers")
      return svc.transfers.count > 0 ? Format.count(svc.transfers.count, "TRANSFER") : "THIS SESSION";
    return svc.incomingRequests.count > 0 ? Format.count(svc.incomingRequests.count, "REQUEST") : "NOTHING PENDING";
  }

  // ---- sidebar: the pages ----
  KitSidebar {
    id: side
    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
    icon: "repeat"
    title: "LocalSend"
    subtitle: root.svc.serviceAvailable ? "READY" : root.svc.processStatus === "starting" ? "STARTING…" : "UNAVAILABLE"
    lineY: head.y + head.height - Theme.dividerThickness
    model: [
      { label: "Send", value: "send", icon: "arrow-up" },
      { label: "Transfers", value: "transfers", icon: "repeat", hint: svc.transfers.count > 0 ? String(svc.transfers.count) : "" },
      { label: "Incoming", value: "incoming", icon: "download", hint: svc.incomingRequests.count > 0 ? String(svc.incomingRequests.count) : "" }
    ]
    current: root.page
    onPicked: value => root.page = value
  }

  KitLine { vertical: true; anchors { left: side.right; top: parent.top; bottom: parent.bottom } }

  // ---- header ----
  Column {
    id: head
    anchors { left: side.right; right: parent.right; top: parent.top; margins: Theme.windowPadding; topMargin: Theme.windowPadding - Theme.headerInset }
    spacing: Theme.sectionGap

    KitHeader {
      icon: root.page === "transfers" ? "repeat" : root.page === "incoming" ? "download" : "arrow-up"
      title: root.page === "transfers" ? "Transfers" : root.page === "incoming" ? "Incoming" : "Send"
      subtitle: root.subtitle()
    }

    KitLine { sectionBreak: false }
  }

  // ---- the service's banner: what the pages wait for ----
  KitNotice {
    id: banner
    anchors { left: side.right; right: parent.right; top: head.bottom; leftMargin: Theme.windowPadding; rightMargin: Theme.windowPadding; topMargin: Theme.gapGroup }
    shown: !root.svc.serviceAvailable || root.svc.error !== ""
    icon: root.svc.processStatus === "error" ? "info" : "repeat"
    title: root.svc.serviceAvailable ? "LocalSend needs attention" : root.svc.processStatus === "starting" ? "Starting LocalSend" : "LocalSend is unavailable"
    text: root.svc.error !== "" ? root.svc.error : "Check that the optional LocalSend component is installed."
    tone: root.svc.processStatus === "error" ? Theme.red : Theme.yellow
    action: root.svc.processStatus === "error" ? "Retry" : ""
    onActed: root.svc.retry()
  }

  // ---- pages ----
  Item {
    id: pages
    anchors {
      left: side.right; right: parent.right
      top: banner.shown ? banner.bottom : head.bottom
      bottom: foot.visible ? foot.top : parent.bottom
      leftMargin: Theme.windowPadding; rightMargin: Theme.windowPadding
      topMargin: Theme.gapGroup; bottomMargin: foot.visible ? Theme.sectionGap : Theme.windowPadding
    }

    Loader {
      anchors.fill: parent
      sourceComponent: root.page === "send" ? sendView : root.page === "transfers" ? transfersView : incomingView
    }
    Component {
      id: sendView
      LocalSendSend {
        draft: sendDraft
        onSent: root.page = "transfers"
      }
    }
    Component { id: transfersView; LocalSendTransfers {} }
    Component { id: incomingView; LocalSendIncoming {} }
  }

  // ---- foot: the running transfer, with its cancel ----
  Column {
    id: foot
    visible: root.activeJob !== null && root.page !== "transfers"
    anchors { left: side.right; right: parent.right; bottom: parent.bottom; margins: Theme.windowPadding; bottomMargin: Theme.windowPadding }
    spacing: Theme.sectionGap

    KitLine {}

    Item {
      width: parent.width
      height: cancel.visible ? cancel.height : msg.implicitHeight

      KitText {
        id: msg
        anchors { left: parent.left; right: cancel.visible ? cancel.left : parent.right; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
        elide: Text.ElideRight
        font.pixelSize: Theme.fontSize - 2
        color: root.svc.error !== "" ? Theme.red : Theme.muted
        text: {
          const job = root.activeJob;
          if (job) {
            const what = (job.direction === "receive" ? "Receiving from " : "Sending to ") + (job.deviceAlias || "a device");
            const percent = job.totalBytes > 0 ? Math.round(Math.min(1, job.transferredBytes / job.totalBytes) * 100) + "%" : "starting";
            const size = job.totalBytes > 0 ? Format.humanSize(job.transferredBytes) + " of " + Format.humanSize(job.totalBytes) : "";
            return what + " · " + percent + (size !== "" ? " · " + size : "");
          }
          return root.svc.error;
        }
      }

      KitButton {
        id: cancel
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        visible: root.activeJob !== null
        text: "Cancel"
        onClicked: root.svc.cancelTransfer(root.activeJob.transferId)
      }
    }
  }

  Connections {
    target: root.svc.transfers
    function onCountChanged() { root.transferRevision += 1; }
    function onDataChanged() { root.transferRevision += 1; }
  }
}
