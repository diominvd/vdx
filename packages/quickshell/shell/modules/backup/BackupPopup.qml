import QtQuick
import Quickshell
import qs.components
import qs.apps.backup
import qs.config
import qs.kit

// The backups in brief: when the last one ran, Back up now, and the restore
// guide. Everything else is in the Backups window.
KitFrame {
  id: root

  readonly property var bs: BackupService

  signal openWindow()


  // open the window on a tab, from the bar (a tab is set before it shows)
  function openTab(tab) {
    BackupService.tabRequest = "";
    BackupService.tabRequest = tab;
    root.openWindow();
    ShellIpc.call("backup", "open");
  }

  KitHeader {
    icon: "history"
    title: "Backups"
    subtitle: !bs.loaded ? "LOADING…" : !bs.configured ? "NOT SET UP"
      : bs.last ? "LAST " + bs.agoText(bs.last.ts).toUpperCase() : "NEVER RUN"

    KitButton {
      icon: "external"
      onClicked: root.openTab("overview")
    }
  }

  KitLine {}

  KitRow {
    label: bs.last ? (bs.last.ok ? "Last backup" : "Last backup failed") : "No backup yet"
    hint: bs.last ? bs.last.message : bs.configured ? "Press Back up" : "Set it up in the window"
    labelColor: bs.last && !bs.last.ok ? Theme.red : Theme.foreground0

    KitButton {
      anchors.verticalCenter: parent.verticalCenter
      icon: "download"
      text: "Back up"
      width: BackupService.buttonWidth
      busy: bs.busy && bs.jobKind === "run"
      disabled: bs.busy || !bs.configured || !bs.resticFound
      onClicked: bs.runNow()
    }
  }

  KitRow {
    label: "Restore"
    hint: "Step by step, or: backup guide"

    KitButton {
      anchors.verticalCenter: parent.verticalCenter
      icon: "rotate-ccw"
      text: "Guide"
      width: BackupService.buttonWidth
      onClicked: root.openTab("snapshots")
    }
  }
}
