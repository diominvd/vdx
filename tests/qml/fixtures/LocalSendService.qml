pragma Singleton
import QtQuick

// In-memory boundary for the production LocalSend views.
QtObject {
  property bool serviceAvailable: true
  property string processStatus: "ready"
  property string error: ""
  property bool discoveryActive: false
  property int deviceRevision: 0
  property var calls: []
  property ListModel devices: ListModel { dynamicRoles: true }
  property ListModel transfers: ListModel { dynamicRoles: true }
  property ListModel incomingRequests: ListModel { dynamicRoles: true }
  function deviceByFingerprint(fingerprint) {
    const revision = deviceRevision;
    for (let i = 0; i < devices.count; i++)
      if (devices.get(i).fingerprint === fingerprint) return devices.get(i);
    return null;
  }
  function sendFiles(fingerprint, paths) { calls = calls.concat([{action: "send", fingerprint: fingerprint, paths: paths}]); return "sent"; }
  function acceptTransfer(session, files) { calls = calls.concat([{action: "accept", session: session, files: files}]); }
  function rejectTransfer(session) { calls = calls.concat([{action: "reject", session: session}]); }
  function cancelTransfer(id) { calls = calls.concat([{action: "cancel", id: id}]); }
  function discover() {}
  function retry() {}
}
