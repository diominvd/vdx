import QtQuick
import qs.config
import qs.kit

// Overview: the last run, a backup now (with its progress), a check of the
// repository, what goes in and the timed runs. Before a repository is set,
// it only points to Setup.
Item {
  id: root

  signal openSetup()

  readonly property var bs: BackupService
  readonly property bool running: bs.busy && bs.jobKind === "run"
  readonly property bool timerOn: bs.config.schedule ? bs.config.schedule.mode !== "off" : false
  readonly property string scheduleText: !root.timerOn ? "Off, only when you press Back up"
    : (bs.config.schedule.mode === "weekly" ? "Every Monday" : "Every day") + " at " + bs.config.schedule.time

  function bytes(n) { return Format.humanSize(n); }

  // whole hours, as the timer takes them: "03:00" steps by one hour, wrapping at midnight
  function hourStep(time, by) {
    const h = (parseInt(time.split(":")[0], 10) + by + 24) % 24;
    return (h < 10 ? "0" : "") + h + ":00";
  }
  function hourBefore(time) { return hourStep(time, -1); }
  function hourAfter(time) { return hourStep(time, 1); }

  function source(key) { return bs.config.sources ? bs.config.sources[key] === true : false; }

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
        visible: bs.loaded && !bs.configured
        text: "Nothing is backed up yet. Choose a folder on a drive in Setup, and the first run starts here."
      }

      KitButton {
        width: Theme.buttonWidth
        visible: bs.loaded && !bs.configured
        text: "Open Setup"
        icon: "settings"
        onClicked: root.openSetup()
      }

      // ---- the last run and a backup now ----
      KitLabel {
        visible: bs.configured
        text: "LAST RUN"
        value: bs.last ? bs.agoText(bs.last.ts).toUpperCase() : "NEVER"
      }

      KitRow {
        visible: bs.configured
        label: bs.last ? (bs.last.ok ? "Saved" : "Failed") : "Not run yet"
        hint: bs.last ? bs.last.message + (bs.last.auto ? " · timed" : "") : "Back up once to see it here"
        labelColor: bs.last && !bs.last.ok ? Theme.red : Theme.foreground0
      }

      KitInfo {
        visible: bs.configured
        label: "On disk"
        value: bs.onDisk >= 0 ? root.bytes(bs.onDisk) + " for all snapshots together" : "counting…"
      }

      KitInfo {
        visible: bs.configured
        label: "Restores to"
        value: bs.restoreSize >= 0 ? root.bytes(bs.restoreSize) + " from the newest" : "counting…"
      }

      KitLine { visible: bs.configured }

      KitRow {
        visible: bs.configured
        label: "Back up now"
        hint: root.running ? "Backing up · " + (bs.progress >= 0 ? bs.progress + "%" : "starting") : "Everything below, once a root pass"

        KitButton {
          width: Theme.buttonWidth
          anchors.verticalCenter: parent.verticalCenter
          icon: "download"
          text: "Back up"
          busy: root.running
          disabled: bs.busy || !bs.resticFound
          onClicked: bs.runNow()
        }
      }

      KitRow {
        visible: bs.configured
        label: "Check the repository"
        hint: "Reads its index, not the data"

        KitButton {
          width: Theme.buttonWidth
          anchors.verticalCenter: parent.verticalCenter
          icon: "shield"
          text: "Check"
          busy: bs.busy && bs.jobKind === "verify"
          disabled: bs.busy
          onClicked: bs.verify(false)
        }
      }

      KitLine { visible: bs.configured }

      // ---- what goes in ----
      KitLabel {
        visible: bs.configured
        text: "WHAT GOES IN"
        value: [root.source("home"), root.source("etc"), root.source("packages"), root.source("root")].filter(on => on).length + " OF 4"
      }

      KitRow {
        visible: bs.configured
        label: "Home"
        hint: "Your files, without the caches"

        KitSwitch {
          accessibleName: "Home"
          anchors.verticalCenter: parent.verticalCenter
          checked: root.source("home")
          disabled: bs.busy
          onToggled: bs.setConfig({ "sources": { "home": !checked } })
        }
      }

      KitRow {
        visible: bs.configured
        label: "System config"
        hint: "/etc · root-only files are skipped"

        KitSwitch {
          accessibleName: "System config"
          anchors.verticalCenter: parent.verticalCenter
          checked: root.source("etc")
          disabled: bs.busy
          onToggled: bs.setConfig({ "sources": { "etc": !checked } })
        }
      }

      KitRow {
        visible: bs.configured
        label: "Root-only files"
        hint: "Wi-Fi, logins, Bluetooth · asks once"

        KitSwitch {
          accessibleName: "Root-only files"
          anchors.verticalCenter: parent.verticalCenter
          checked: root.source("root")
          disabled: bs.busy
          onToggled: bs.setConfig({ "sources": { "root": !checked } })
        }
      }

      KitRow {
        visible: bs.configured
        label: "Packages and services"
        hint: "Pacman list, services, groups"

        KitSwitch {
          accessibleName: "Packages and services"
          anchors.verticalCenter: parent.verticalCenter
          checked: root.source("packages")
          disabled: bs.busy
          onToggled: bs.setConfig({ "sources": { "packages": !checked } })
        }
      }

      KitLine { visible: bs.configured }

      KitInfo {
        visible: bs.configured
        label: "Automatic"
        value: root.scheduleText
      }
    }
  }
}
