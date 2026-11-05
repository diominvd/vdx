import QtQuick
import qs.config
import qs.kit

// The backups' content: a sidebar with the pages (Overview, Snapshots,
// Settings), the page's header and the page under it, and a foot with what the last action did — or
// the running backup, with its cancel.
Rectangle {
  id: root

  color: Theme.background0

  readonly property var bs: BackupService
  property string tab: "overview"

  // a shell part (the bar module's Guide button) asks for a tab
  Connections {
    target: BackupService
    function onTabRequestChanged() { if (BackupService.tabRequest !== "") root.tab = BackupService.tabRequest === "restore" ? "snapshots" : BackupService.tabRequest; }
  }

  function subtitle() {
    if (bs.loadError !== "") return "STATUS UNAVAILABLE";
    if (!bs.loaded) return "LOADING…";
    if (!bs.resticFound) return "RESTIC IS NOT INSTALLED";
    if (!bs.configured) return "NOT SET UP";
    return "LAST " + bs.agoText(bs.last?.ts).toUpperCase() + (bs.last && !bs.last.ok ? " · FAILED" : "");
  }

  // ---- sidebar: the pages ----
  KitSidebar {
    id: side
    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
    icon: "history"
    title: "Backups"
    subtitle: "RESTIC"
    lineY: head.y + head.height - Theme.dividerThickness
    model: [
      { label: "Overview", value: "overview", icon: "layout" },
      { label: "Snapshots", value: "snapshots", icon: "history" },
      { label: "Settings", value: "settings", icon: "settings" }
    ]
    current: root.tab
    onPicked: value => root.tab = value
  }

  KitLine { vertical: true; anchors { left: side.right; top: parent.top; bottom: parent.bottom } }

  // ---- header ----
  Column {
    id: head
    anchors { left: side.right; right: parent.right; top: parent.top; margins: Theme.windowPadding; topMargin: Theme.windowPadding - Theme.headerInset }
    spacing: Theme.sectionGap

    KitHeader {
      icon: root.tab === "snapshots" ? "history" : root.tab === "settings" ? "settings" : "layout"
      title: root.tab === "snapshots" ? "Snapshots" : root.tab === "settings" ? "Settings" : "Overview"
      subtitle: root.subtitle()
    }

    KitLine {}
  }

  // ---- pages ----
  // ends at the foot when it shows, else at the window's padding
  Item {
    id: pages
    anchors { left: side.right; right: parent.right; top: head.bottom; bottom: foot.visible ? foot.top : parent.bottom; leftMargin: Theme.windowPadding; rightMargin: Theme.windowPadding; topMargin: Theme.gapGroup; bottomMargin: foot.visible ? 0 : Theme.windowPadding }

    BackupOverview {
      anchors.fill: parent
      visible: root.tab === "overview"
      onOpenSettings: root.tab = "settings"
    }

    BackupSnapshots {
      anchors.fill: parent
      visible: root.tab === "snapshots"
    }

    BackupSettings {
      anchors.fill: parent
      visible: root.tab === "settings"
    }
  }

  // ---- foot ----
  Column {
    id: foot
    visible: root.bs.busy || root.bs.message !== "" || (root.bs.loaded && !root.bs.resticFound)
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
        color: root.bs.status === "error" ? Theme.red : root.bs.status === "ok" ? Theme.green : root.bs.loaded && !root.bs.resticFound ? Theme.yellow : Theme.muted
        text: root.bs.busy
          ? (root.bs.jobKind === "run" ? "Backing up · " + (root.bs.progress >= 0 ? root.bs.progress + "%" : "starting") : "Working…")
          : root.bs.message !== "" ? root.bs.message
          : root.bs.loaded && !root.bs.resticFound ? "restic is not installed: pacman -S restic"
          : ""
      }

      KitButton {
        width: Theme.buttonWidth
        id: cancel
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        visible: root.bs.busy && root.bs.jobKind === "run"
        text: "Cancel"
        onClicked: root.bs.cancel()
      }
    }
  }
}
