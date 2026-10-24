import QtQuick
import qs.config
import qs.kit

// Snapshots: the list, newest first; a picked one opens as a folder tree to
// browse and restore from. Restores go to a new folder (~/Restore), never over
// what is there. Forgetting asks once more; reinstalling the packages goes
// through the shell's root panel.
Item {
  id: root

  readonly property var bs: BackupService
  readonly property var picked: bs.snapshots.find(s => s.short === bs.snapshot)
  readonly property bool restoring: bs.busy && bs.jobKind === "restore"
  // the forget button asks once more, like the cleaner's
  property bool armed: false

  onPickedChanged: armed = false
  Timer { id: disarm; interval: 3000; onTriggered: root.armed = false }

  function forget() {
    if (!armed) { armed = true; disarm.restart(); return; }
    armed = false;
    bs.forget([bs.snapshot]);
    bs.leave();
  }

  Flickable {
    anchors.fill: parent
    bottomMargin: Theme.gapGroup
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight + bottomMargin > height

    KitColumn {
      id: column
      width: parent.width
      spacing: Theme.gapGroup

      BackupNote {
        visible: !bs.configured
        text: "No repository yet, so there are no snapshots. Set one up in Setup; the backups show here after the first run."
      }

      KitButton {
        visible: !bs.configured
        icon: "settings"
        text: "Open Setup"
        onClicked: bs.showTab("setup")
      }

      KitRow {
        label: "Snapshots"
        hint: bs.snapshots.length > 0 ? "Newest first · pick one to browse it" : "Each backup adds one"
        visible: bs.configured

        KitButton {
          anchors.verticalCenter: parent.verticalCenter
          icon: "refresh"
          busy: bs.listing
          onClicked: bs.loadSnapshots()
        }
      }

      BackupNote {
        visible: bs.configured && bs.snapshots.length === 0 && !bs.listing
        text: "No snapshot yet. Back up from Overview."
      }

      Repeater {
        model: bs.configured ? bs.snapshots : []

        KitRow {
          id: row
          required property var modelData

          label: Qt.formatDateTime(new Date(modelData.ts * 1000), "yyyy-MM-dd  HH:mm")
          hint: (modelData.tags.join(", ") || "manual") + " · " + modelData.paths.join(" ")
          labelColor: modelData.short === bs.snapshot ? Theme.foreground0 : Theme.foreground1

          KitText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(80, parent.width * 0.2))
            horizontalAlignment: Text.AlignRight
            text: Format.shortSize(modelData.size)
            color: Theme.foreground2
          }

          KitButton {
            width: Theme.buttonWidth
            anchors.verticalCenter: parent.verticalCenter
            icon: "folder"
            text: "Browse"
            selected: modelData.short === bs.snapshot
            onClicked: bs.browse(modelData.short, "/")
          }
        }
      }

      // ---- the open snapshot ----
      KitLine { visible: root.picked !== undefined }

      KitLabel {
        visible: root.picked !== undefined
        text: "IN " + (root.picked ? Qt.formatDateTime(new Date(root.picked.ts * 1000), "yyyy-MM-dd HH:mm") : "")
        value: bs.folder
      }

      KitRow {
        visible: root.picked !== undefined
        label: "Restore everything"
        hint: "Into a new folder in ~/Restore"

        KitButton {
          width: Theme.buttonWidth
          anchors.verticalCenter: parent.verticalCenter
          icon: "rotate-ccw"
          text: "Restore"
          busy: root.restoring
          disabled: bs.busy
          onClicked: bs.restore(bs.snapshot, [])
        }
      }

      KitRow {
        visible: root.picked !== undefined
        label: "Packages and services"
        hint: "Repository packages, then enable and groups"

        KitButton {
          width: Theme.buttonWidth
          anchors.verticalCenter: parent.verticalCenter
          icon: "package"
          text: "Install"
          busy: bs.busy && bs.jobKind === "packages"
          disabled: bs.busy
          onClicked: bs.packages(bs.snapshot)
        }
      }

      KitRow {
        visible: root.picked !== undefined
        label: "AUR packages"
        hint: "Built by yay, in a terminal, one by one"

        KitButton {
          width: Theme.buttonWidth
          anchors.verticalCenter: parent.verticalCenter
          icon: "package"
          text: "Build"
          busy: bs.busy && bs.jobKind === "aur"
          disabled: bs.busy
          onClicked: bs.aur(bs.snapshot)
        }
      }

      KitRow {
        visible: root.picked !== undefined
        label: root.armed ? "Forget it for good?" : "Forget this snapshot"
        hint: "Its space is freed at the next prune"
        labelColor: root.armed ? Theme.red : Theme.foreground0

        KitButton {
          width: Theme.buttonWidth
          anchors.verticalCenter: parent.verticalCenter
          icon: root.armed ? "check" : "trash"
          text: root.armed ? "Sure?" : "Forget"
          selected: root.armed
          disabled: bs.busy
          onClicked: root.forget()
        }
      }

      KitRow {
        visible: bs.restored !== "" && root.picked !== undefined
        label: "Restored to"
        hint: bs.restored

        KitButton {
          width: Theme.buttonWidth
          anchors.verticalCenter: parent.verticalCenter
          icon: "folder"
          text: "Open"
          onClicked: bs.openFolder(bs.restored)
        }
      }

      // the folder's entries: folders open, every entry restores
      KitRow {
        visible: root.picked !== undefined
        label: bs.folder === "/" ? "Top of the snapshot" : bs.folder
        hint: bs.browsing ? "Listing…" : bs.entries.length + " entries"

        KitButton {
          width: Theme.buttonWidth
          anchors.verticalCenter: parent.verticalCenter
          icon: "arrow-up"
          text: "Up"
          disabled: bs.folder === "/" || bs.busy
          onClicked: bs.browse(bs.snapshot, bs.folder.substring(0, bs.folder.lastIndexOf("/")) || "/")
        }
      }

      Repeater {
        model: root.picked !== undefined ? bs.entries : []

        KitRow {
          id: entry
          required property var modelData

          label: (modelData.dir ? "/ " : "") + modelData.name
          hint: modelData.dir
            ? (bs.sizes[modelData.path] !== undefined ? Format.shortSize(bs.sizes[modelData.path]) : "counting…")
            : Format.shortSize(modelData.size)
          labelColor: modelData.dir ? Theme.foreground0 : Theme.foreground1

          KitButton {
            width: Theme.buttonWidth
            anchors.verticalCenter: parent.verticalCenter
            visible: entry.modelData.dir
            icon: "folder"
            text: "Open"
            disabled: bs.busy
            onClicked: bs.browse(bs.snapshot, entry.modelData.path)
          }

          KitButton {
            width: Theme.buttonWidth
            anchors.verticalCenter: parent.verticalCenter
            icon: "rotate-ccw"
            text: "Restore"
            disabled: bs.busy
            onClicked: bs.restore(bs.snapshot, [entry.modelData.path])
          }
        }
      }
    }
  }
}
