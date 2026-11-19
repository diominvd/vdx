import QtQuick
import QtQuick.Controls
import qs.config
import qs.kit

// Incoming: one section per request — the device, its files with a box to
// tick each, and the decision. Nothing is accepted automatically; a request
// not answered in time is taken back by the service.
Item {
  id: root

  readonly property var svc: LocalSendService
  // the ticked files per request: sessionId -> [fileId], every file by default
  property var selections: ({})
  property real clockNow: Date.now()

  function remaining(expiresAt) { return Math.max(0, Math.ceil((expiresAt - root.clockNow) / 1000)); }

  function selectedIds(sessionId, files) {
    if (Object.prototype.hasOwnProperty.call(root.selections, sessionId))
      return root.selections[sessionId];
    const ids = [];
    for (const file of svc.copyFiles(files)) ids.push(file.fileId);
    return ids;
  }

  function toggle(sessionId, fileId, files) {
    const ids = root.selectedIds(sessionId, files).slice();
    const at = ids.indexOf(fileId);
    if (at >= 0) ids.splice(at, 1); else ids.push(fileId);
    const next = Object.assign({}, root.selections);
    next[sessionId] = ids;
    root.selections = next;
  }

  // forget the requests that are gone
  function prune() {
    const next = {};
    for (let i = 0; i < svc.incomingRequests.count; i++) {
      const sessionId = svc.incomingRequests.get(i).sessionId;
      if (Object.prototype.hasOwnProperty.call(root.selections, sessionId))
        next[sessionId] = root.selections[sessionId];
    }
    root.selections = next;
  }

  Connections {
    target: root.svc.incomingRequests
    function onCountChanged() { root.prune(); root.clockNow = Date.now(); }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.visible && root.svc.incomingRequests.count > 0
    onTriggered: root.clockNow = Date.now()
  }

  Flickable {
    id: pane
    anchors.fill: parent
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    ScrollBar.vertical: KitScrollBar {}

    Column {
      id: column
      width: parent.width
      spacing: Theme.gapGroup

      Repeater {
        model: root.svc.incomingRequests
        Column {
          id: request
          required property string sessionId
          required property string alias
          required property var files
          required property real expiresAt
          readonly property var picked: root.selectedIds(sessionId, files)
          readonly property int secondsLeft: root.remaining(expiresAt)
          width: parent.width
          spacing: Theme.sectionGap

          KitRow {
            label: request.alias
            hint: Format.count(root.svc.copyFiles(request.files).length, "file") + " · " + request.secondsLeft + " s remaining"
            KitButton {
              icon: "x"
              Accessible.name: "Decline files from " + request.alias
              onClicked: root.svc.rejectTransfer(request.sessionId)
            }
          }
          Repeater {
            model: request.files
            LocalSendEntry {
              required property var modelData
              title: modelData.fileName
              detail: Format.humanSize(modelData.size)
              selectable: true
              checkable: true
              selected: request.picked.includes(modelData.fileId)
              onClicked: root.toggle(request.sessionId, modelData.fileId, request.files)
            }
          }
          KitRow {
            label: Format.count(request.picked.length, "file") + " selected"
            hint: "Save to Downloads/LocalSend"
            KitButton {
              primary: true
              text: "Accept"
              disabled: request.picked.length === 0 || request.secondsLeft <= 0
              onClicked: root.svc.acceptTransfer(request.sessionId, request.picked)
            }
          }
          KitLine { sectionBreak: false }
        }
      }
    }

    KitEmptyState {
      anchors.centerIn: parent
      width: parent.width
      visible: root.svc.incomingRequests.count === 0
      centered: true
      title: "Ready to receive"
      hint: "Send files to this computer from another device. You’ll choose what to accept here."
    }
  }
}
