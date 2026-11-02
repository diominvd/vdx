import QtQuick
import qs.apps.files
import qs.config
import qs.kit

// Settings, in the Settings look (groups in boxes, segments, short hints): the
// repository and its password, the timed runs, how many snapshots are kept,
// the folders beyond the three sources and the patterns left out. Every change
// is saved by backup.py at once.
Item {
  id: root

  readonly property var bs: BackupService
  readonly property var keep: bs.config.keep ?? ({})
  readonly property var extra: bs.config.extra ?? []
  readonly property var excludes: bs.config.excludes ?? []
  readonly property string mode: bs.config.schedule ? bs.config.schedule.mode : "off"
  readonly property string time: bs.config.schedule ? bs.config.schedule.time : "03:00"
  readonly property bool timerOn: mode !== "off"
  readonly property string scheduleText: !timerOn ? "Off" : (mode === "weekly" ? "every Monday" : "every day") + " at " + time

  // whole hours; a time set some other way stays in the list
  readonly property var timeChoices: ["01:00", "03:00", "06:00", "12:00", "18:00", "22:00"]
      .concat(["01:00", "03:00", "06:00", "12:00", "18:00", "22:00"].indexOf(time) < 0 ? [time] : [])
      .sort().map(t => ({ label: t, value: t }))
  // the repository's drive: the mounted disk its folder is on, else custom
  readonly property int aiCount: bs.aiSuggestions.filter(sug => bs.aiPicked[sug.path]).length

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
      spacing: Theme.sectionGap

      // ---- repository ----
      KitLabel {
        text: "REPOSITORY"
        value: bs.configured ? "SET" : "NOT SET"
      }

      KitRow {
        label: "Folder"
        hint: bs.configured ? (bs.config.repo ?? "") : "Another disk or a NAS, not this one"

        KitButton {
          width: Theme.buttonWidth
          anchors.verticalCenter: parent.verticalCenter
          icon: "folder"
          text: "Choose…"
          busy: bs.busy && bs.jobKind === "pick"
          disabled: bs.busy
          onClicked: bs.pick()
        }
      }

      KitInput {
        id: repo
        placeholder: "/a/folder · or sftp:user@host:/path · Enter sets it"
        text: bs.config.repo ?? ""
        onAccepted: bs.init(text.trim())
      }

      KitLine {}

      // ---- the password: it encrypts everything ----
      KitLabel {
        text: "PASSWORD"
        value: bs.configured ? "IN A FILE" : "NONE YET"
      }

      KitRow {
        label: "Password"
        hint: "Without it nothing can be restored"

        KitButton {
          width: Theme.buttonWidth
          anchors.verticalCenter: parent.verticalCenter
          visible: bs.configured && bs.revealed === ""
          icon: "lock"
          text: "Show"
          busy: bs.busy && bs.jobKind === "password"
          disabled: bs.busy
          onClicked: bs.showPassword()
        }

        KitButton {
          width: Theme.buttonWidth
          anchors.verticalCenter: parent.verticalCenter
          visible: bs.revealed !== ""
          icon: bs.copied ? "check" : "clipboard"
          text: bs.copied ? "Copied" : "Copy"
          onClicked: bs.copyPassword()
        }
      }

      KitInput {
        visible: bs.revealed !== ""
        text: bs.revealed
        input.readOnly: true
        input.font.pixelSize: Theme.fontSize - 1
      }

      KitLine {}

      // ---- automatic backups: set here, run by a systemd timer ----
      KitLabel {
        text: "SCHEDULE"
        value: root.scheduleText.toUpperCase()
      }

      KitRow {
        label: "Run by itself"
        hint: root.timerOn && !bs.configured ? "Starts once a repository is set" : "Off: only on Back up"
        wide: true

        KitSegments {
          disabled: bs.busy
          model: [{ label: "Off", value: "off" }, { label: "Every day", value: "daily" }, { label: "Every week", value: "weekly" }]
          current: root.mode
          onPicked: value => bs.setSchedule(value, root.time)
        }
      }

      KitRow {
        visible: root.timerOn
        label: "Start time"
        hint: root.mode === "weekly" ? "On Mondays" : "Every day"
        wide: true

        KitSegments {
          disabled: bs.busy
          model: root.timeChoices
          current: root.time
          onPicked: value => bs.setSchedule(root.mode, value)
        }
      }

      KitRow {
        label: "Notify when it ends"
        hint: "Done, or what went wrong"

        KitSwitch {
          accessibleName: "Notify when it ends"
          checked: bs.config.notify === true
          disabled: bs.busy
          onToggled: bs.setConfig({ "notify": !checked })
        }
      }

      KitLine {}

      // ---- how many are kept ----
      KitLabel {
        text: "KEEP"
        value: root.keep.on ? "DAILY " + root.keep.daily + " · WEEKLY " + root.keep.weekly + " · MONTHLY " + root.keep.monthly : "EVERYTHING"
      }

      KitRow {
        label: "Remove old snapshots"
        hint: "After a backup, by these counts"

        KitSwitch {
          accessibleName: "Remove old snapshots"
          checked: root.keep.on === true
          disabled: bs.busy
          onToggled: bs.setConfig({ "keep": { "on": !checked } })
        }
      }

      KitRow {
        visible: root.keep.on === true
        label: "Daily"
        wide: true

        KitSegments {
          disabled: bs.busy
          model: [3, 7, 14, 30].map(n => ({ label: n + " days", value: n }))
          current: root.keep.daily ?? null
          onPicked: value => bs.setConfig({ "keep": { "daily": value } })
        }
      }

      KitRow {
        visible: root.keep.on === true
        label: "Weekly"
        wide: true

        KitSegments {
          disabled: bs.busy
          model: [2, 4, 8].map(n => ({ label: n + " weeks", value: n }))
          current: root.keep.weekly ?? null
          onPicked: value => bs.setConfig({ "keep": { "weekly": value } })
        }
      }

      KitRow {
        visible: root.keep.on === true
        label: "Monthly"
        wide: true

        KitSegments {
          disabled: bs.busy
          model: [3, 6, 12].map(n => ({ label: n + " months", value: n }))
          current: root.keep.monthly ?? null
          onPicked: value => bs.setConfig({ "keep": { "monthly": value } })
        }
      }

      KitLine {}

      // ---- folders beyond the sources ----
      KitLabel {
        text: "EXTRA FOLDERS"
        value: root.extra.length > 0 ? root.extra.length + " ADDED" : "NONE"
      }

      Repeater {
        model: root.extra

        KitRow {
          required property var modelData
          required property int index

          label: modelData
          labelColor: Theme.foreground1

          KitButton {
            width: Theme.buttonWidth
            anchors.verticalCenter: parent.verticalCenter
            icon: "trash"
            text: "Remove"
            disabled: bs.busy
            onClicked: bs.setConfig({ "extra": root.extra.filter((_, i) => i !== index) })
          }
        }
      }

      KitRow {
        label: "Add a folder"
        hint: "Extra folders; a missing one stops a run"

        KitButton {
          width: Theme.buttonWidth
          anchors.verticalCenter: parent.verticalCenter
          icon: "folder"
          text: "Choose…"
          disabled: bs.busy
          onClicked: FilesService.pickFolder("Back up this folder", FilesService.home,
                                             p => { if (p !== "") bs.setConfig({ "extra": root.extra.concat([p]) }); })
        }
      }

      KitInput {
        placeholder: "/an/absolute/path · Enter adds it"
        onAccepted: {
          const path = text.trim();
          if (path === "") return;
          bs.setConfig({ "extra": root.extra.concat([path]) });
          text = "";
        }
      }

      KitLine {}

      // ---- left out ----
      KitLabel {
        text: "LEFT OUT"
        value: root.excludes.length > 0 ? root.excludes.length + " ADDED" : "NONE"
      }

      Repeater {
        model: root.excludes

        KitRow {
          required property var modelData
          required property int index

          label: modelData
          labelColor: Theme.foreground1

          KitButton {
            width: Theme.buttonWidth
            anchors.verticalCenter: parent.verticalCenter
            icon: "trash"
            text: "Remove"
            disabled: bs.busy
            onClicked: bs.setConfig({ "excludes": root.excludes.filter((_, i) => i !== index) })
          }
        }
      }

      KitRow {
        label: "Add a pattern"
        hint: "A path, or a name for every match"
      }

      KitInput {
        placeholder: "A path or a name · Enter adds it"
        onAccepted: {
          const pattern = text.trim();
          if (pattern === "") return;
          bs.setConfig({ "excludes": root.excludes.concat([pattern]) });
          text = "";
        }
      }

      KitLine {}

      // ---- Claude's suggestions: the user picks, nothing is left out before ----
      KitLabel {
        visible: bs.claude
        text: "CLAUDE"
        value: root.aiCount > 0 ? root.aiCount + " PICKED" : ""
      }

      KitRow {
        visible: bs.claude
        label: "Suggest what to leave out"
        hint: "Sees folder names and sizes only"

        KitButton {
          width: Theme.buttonWidth
          anchors.verticalCenter: parent.verticalCenter
          icon: "bot"
          text: "Analyse"
          busy: bs.busy && bs.jobKind === "ai"
          disabled: bs.busy
          onClicked: bs.analyze()
        }
      }

      Repeater {
        model: bs.aiSuggestions

        KitRow {
          required property var modelData

          label: modelData.shown
          hint: modelData.why + " · " + modelData.mb + " MB"
          labelColor: modelData.risk === "medium" ? Theme.yellow : Theme.foreground0

          KitSwitch {
            accessibleName: modelData.shown
            checked: bs.aiPicked[modelData.path] === true
            disabled: bs.busy
            onToggled: bs.aiPick(modelData.path, !checked)
          }
        }
      }

      KitRow {
        visible: root.aiCount > 0
        label: "Leave out the picked"
        hint: root.aiCount + " picked · yellow: less sure"

        KitButton {
          width: Theme.buttonWidth
          anchors.verticalCenter: parent.verticalCenter
          icon: "check"
          text: "Leave out"
          disabled: bs.busy
          onClicked: bs.aiApply()
        }
      }

      KitGrouper {}
    }
  }
}
