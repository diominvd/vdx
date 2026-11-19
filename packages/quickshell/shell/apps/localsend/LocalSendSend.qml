import QtQuick
import QtQuick.Controls
import qs.apps.files
import qs.config
import qs.kit

// Send workspace: virtualised devices and files, a retained draft and a fixed action row.
Item {
  id: root

  signal sent()

  readonly property var svc: LocalSendService
  required property var draft
  readonly property string query: draft.query
  readonly property string fingerprint: draft.fingerprint
  readonly property var queue: draft.queue

  readonly property var chosen: svc.deviceByFingerprint(root.fingerprint)
  readonly property real queueBytes: root.queue.reduce((total, file) => total + (Number(file.size) || 0), 0)

  // devices, filtered by the search field
  readonly property var devices: {
    const revision = svc.deviceRevision;
    const needle = root.query.trim().toLowerCase();
    const rows = [];
    for (let i = 0; i < svc.devices.count; i++) {
      const d = svc.devices.get(i);
      if (needle === "" || d.alias.toLowerCase().includes(needle) || d.address.toLowerCase().includes(needle)
          || d.deviceType.toLowerCase().includes(needle))
        rows.push(d);
    }
    return rows;
  }

  function iconFor(name) {
    const ext = String(name).split(".").pop().toLowerCase();
    if (["png", "jpg", "jpeg", "gif", "webp", "heic", "svg"].includes(ext)) return "image";
    if (["mp3", "wav", "ogg", "flac", "m4a", "aac"].includes(ext)) return "music";
    if (["mp4", "mkv", "mov", "webm", "avi"].includes(ext)) return "video";
    if (["zip", "tar", "gz", "xz", "zst", "7z"].includes(ext)) return "package";
    return "file";
  }

  function addPaths(paths) { root.draft.addPaths(paths); }

  function pick() {
    const target = root.draft;
    FilesService.pickFiles("Choose files to send", "", paths => {
      if (target && typeof target.addPaths === "function") target.addPaths(paths);
    });
  }

  function send() {
    if (!root.chosen || !root.chosen.available || root.queue.length === 0) return;
    const id = svc.sendFiles(root.fingerprint, root.queue.map(file => file.path));
    if (id !== "") { root.draft.queue = []; root.sent(); }
  }

  readonly property bool columns: width >= 560

  Item {
    id: workspace
    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: footer.top; bottomMargin: Theme.sectionGap }

    Item {
      id: recipients
      width: root.columns ? Math.round((parent.width - Theme.gapGroup * 2) * 0.45) : parent.width
      height: root.columns ? parent.height : Math.round((parent.height - Theme.gapGroup * 2) * 0.46)

      KitLabel {
        id: devicesLabel
        text: "NEARBY DEVICES"
        value: String(root.devices.length)
      }

      Row {
        id: search
        anchors { left: parent.left; right: parent.right; top: devicesLabel.bottom; topMargin: Theme.sectionGap }
        spacing: Theme.gapSmall
        KitInput {
          width: parent.width - refresh.width - parent.spacing
          icon: "search"
          placeholder: "Search devices"
          text: root.query
          onTextEdited: root.draft.query = text
        }
        KitButton {
          id: refresh
          icon: "refresh"
          busy: root.svc.discoveryActive
          disabled: !root.svc.serviceAvailable
          Accessible.name: "Search for nearby devices"
          onClicked: root.svc.discover()
        }
      }

      ListView {
        id: deviceList
        anchors { left: parent.left; right: parent.right; top: search.bottom; bottom: parent.bottom; topMargin: Theme.sectionGap }
        clip: true
        model: root.devices
        spacing: Theme.gapHair
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: KitScrollBar {}
        delegate: LocalSendEntry {
          required property var modelData
          width: ListView.view.width
          title: modelData.alias
          detail: modelData.available ? modelData.address : "Unavailable"
          icon: "monitor"
          selectable: true
          available: modelData.available
          selected: root.fingerprint === modelData.fingerprint
          onClicked: root.draft.fingerprint = modelData.fingerprint
        }
        KitEmptyState {
          anchors.centerIn: parent
          width: parent.width
          visible: deviceList.count === 0
          centered: true
          title: root.query.trim() !== "" ? "No matches" : root.svc.discoveryActive ? "Searching…" : "No devices found"
          hint: root.query.trim() !== "" ? "Try another name or address" : "Open LocalSend on another device on this network"
        }
      }
    }

    KitLine {
      vertical: root.columns
      x: root.columns ? recipients.width + Theme.gapGroup : 0
      y: root.columns ? 0 : recipients.height + Theme.gapGroup
      width: root.columns ? Theme.dividerThickness : parent.width
      height: root.columns ? parent.height : Theme.dividerThickness
    }

    Item {
      id: files
      x: root.columns ? recipients.width + 2 * Theme.gapGroup : 0
      y: root.columns ? 0 : recipients.height + 2 * Theme.gapGroup
      width: root.columns ? parent.width - x : parent.width
      height: root.columns ? parent.height : parent.height - y

      KitLabel {
        id: filesLabel
        text: "FILES"
        value: root.queue.length > 0 ? Format.count(root.queue.length, "FILE") : ""
      }

      Row {
        id: fileActions
        anchors { left: parent.left; right: parent.right; top: filesLabel.bottom; topMargin: Theme.sectionGap }
        spacing: Theme.gapSmall
        KitButton {
          text: "Add files…"
          compact: true
          disabled: root.queue.length >= 100
          onClicked: root.pick()
        }
        KitButton {
          icon: "trash"
          disabled: root.queue.length === 0
          Accessible.name: "Clear file selection"
          onClicked: root.draft.queue = []
        }
      }

      ListView {
        id: fileList
        anchors { left: parent.left; right: parent.right; top: fileActions.bottom; bottom: parent.bottom; topMargin: Theme.sectionGap }
        clip: true
        model: root.queue
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: KitScrollBar {}
        delegate: LocalSendEntry {
          required property var modelData
          required property int index
          width: ListView.view.width
          title: modelData.name
          detail: modelData.size > 0 ? Format.humanSize(modelData.size) : "Size checked when sending"
          icon: root.iconFor(modelData.name)
          KitButton {
            icon: "x"
            Accessible.name: "Remove " + modelData.name
            onClicked: {
              const next = root.queue.slice();
              next.splice(index, 1);
              root.draft.queue = next;
            }
          }
        }
        KitEmptyState {
          anchors.centerIn: parent
          width: parent.width
          visible: fileList.count === 0
          centered: true
          title: "Choose files to send"
          hint: "Add files above or drop them here"
        }
      }
    }
  }

  Column {
    id: footer
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    spacing: Theme.sectionGap
    KitLine {}
    KitRow {
      label: root.chosen ? root.chosen.alias : "Choose a device"
      hint: root.queue.length > 0 ? Format.count(root.queue.length, "file") + (root.queueBytes > 0 ? " · " + Format.humanSize(root.queueBytes) : "") : "No files selected"
      KitButton {
        primary: true
        text: "Send"
        disabled: !root.svc.serviceAvailable || !root.chosen || !root.chosen.available || root.queue.length === 0
        onClicked: root.send()
      }
    }
  }

  DropArea {
    anchors.fill: workspace
    keys: ["text/uri-list"]
    onDropped: drop => {
      const paths = [];
      for (const url of drop.urls || []) {
        const value = String(url);
        if (value.startsWith("file://")) paths.push(decodeURIComponent(value.slice(7)));
      }
      root.addPaths(paths);
      drop.acceptProposedAction();
    }
  }
}
