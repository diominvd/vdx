import QtQuick
import qs.apps.files
import qs.config
import qs.kit

// Setup: the repository and its password, how many snapshots are kept, the
// time of the timed runs, the folders beyond the three sources, and the
// patterns left out. Every change is saved by backup.py at once.
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

  // whole hours, as the timer takes them: "03:00" steps by one hour, wrapping at midnight
  function hourStep(t, by) {
    const h = (parseInt(t.split(":")[0], 10) + by + 24) % 24;
    return (h < 10 ? "0" : "") + h + ":00";
  }
  function hourBefore(t) { return hourStep(t, -1); }
  function hourAfter(t) { return hourStep(t, 1); }
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
      spacing: Theme.gapGroup

      // ---- repository ----
      KitLabel {
        text: "REPOSITORY"
        value: bs.configured ? "SET" : "NOT SET"
      }

      KitText {
        visible: !bs.configured
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.yellow
        font.pixelSize: Theme.fontSize - 2
        text: "No repository yet: nothing can be backed up until you set one here."
      }

      BackupNote {
        text: "Keep the backups on another disk: one you unplug between runs, or a NAS. Not on this computer's own disk: if it dies, the backups die with it."
      }

      KitRow {
        label: "Any folder"
        hint: "Picked in the Files window"

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
        accessibleName: "Backup repository location"
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
        label: "Show it"
        hint: "It encrypts every snapshot"

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

      BackupNote {
        text: "Stored in a file here, so timed runs can use it. Without the password nothing can be restored: keep a copy in your password manager."
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
        text: "AUTOMATIC BACKUPS"
        value: root.scheduleText.toUpperCase()
      }

      BackupNote {
        text: "Runs a backup by itself while the computer is on. A run that was missed while it was off happens at the next start."
      }

      KitText {
        visible: root.timerOn && !bs.configured
        width: parent.width
        wrapMode: Text.WordWrap
        color: Theme.yellow
        font.pixelSize: Theme.fontSize - 2
        text: "No repository yet: the time is saved, and the timer starts once a repository is set above."
      }

      KitRow {
        label: "Run by itself"
        hint: "Off: only when you press Back up"
        wide: true

        KitChoices {
          stretch: true
          disabled: bs.busy
          model: [{ label: "Off", value: "off" }, { label: "Every day", value: "daily" }, { label: "Every week", value: "weekly" }]
          current: root.mode
          onPicked: value => bs.setSchedule(value, root.time)
        }
      }

      KitRow {
        visible: root.timerOn
        label: "Start time"
        hint: root.mode === "weekly" ? "Mondays at this time" : "Every day at this time"

        KitButton {
          anchors.verticalCenter: parent.verticalCenter
          icon: "arrow-left"
          disabled: bs.busy
          onClicked: bs.setSchedule(root.mode, root.hourBefore(root.time))
        }

        KitText {
          anchors.verticalCenter: parent.verticalCenter
          width: 56
          horizontalAlignment: Text.AlignHCenter
          font.weight: Font.ExtraBold
          text: root.time
        }

        KitButton {
          anchors.verticalCenter: parent.verticalCenter
          icon: "arrow-right"
          disabled: bs.busy
          onClicked: bs.setSchedule(root.mode, root.hourAfter(root.time))
        }
      }

      KitRow {
        visible: root.timerOn
        label: "Notify when it ends"
        hint: "Only for the automatic runs"

        KitSwitch {
          accessibleName: "Notify when it ends"
          anchors.verticalCenter: parent.verticalCenter
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
        hint: "The newest by these counts, after a backup"

        KitSwitch {
          accessibleName: "Remove old snapshots"
          anchors.verticalCenter: parent.verticalCenter
          checked: root.keep.on === true
          disabled: bs.busy
          onToggled: bs.setConfig({ "keep": { "on": !checked } })
        }
      }

      KitRow {
        visible: root.keep.on === true
        label: "Daily"
        wide: true

        KitChoices {
          stretch: true
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

        KitChoices {
          stretch: true
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

        KitChoices {
          stretch: true
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

      BackupNote {
        text: "Folders backed up besides home, /etc and the lists: type a full path such as /mnt/storage/Projects and press Enter. A folder that is not there stops the next run with its name."
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

      Row {
        width: parent.width
        spacing: Theme.gapMedium

        KitInput {
          width: Math.max(0, parent.width - chooseExtra.width - parent.spacing)
          placeholder: "/an/absolute/path · Enter adds it"
          onAccepted: {
            const path = text.trim();
            if (path === "") return;
            bs.setConfig({ "extra": root.extra.concat([path]) });
            text = "";
          }
        }

        KitButton {
          id: chooseExtra
          icon: "folder"
          text: "Choose…"
          disabled: bs.busy
          onClicked: FilesService.pickFolder("Back up this folder", FilesService.home,
                                             p => { if (p !== "") bs.setConfig({ "extra": root.extra.concat([p]) }); })
        }
      }

      KitLine {}

      // ---- left out ----
      KitLabel {
        text: "LEFT OUT"
        value: root.excludes.length + " PATTERNS"
      }

      BackupNote {
        text: "A full path leaves that path out; a bare name (node_modules) leaves out every file and folder of that name."
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
        hint: "Looks at your biggest folders"

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

      BackupNote {
        visible: bs.claude
        text: "Claude sees folder names and sizes, never their contents. Yellow: less sure, have a look."
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
            anchors.verticalCenter: parent.verticalCenter
            checked: bs.aiPicked[modelData.path] === true
            disabled: bs.busy
            onToggled: bs.aiPick(modelData.path, !checked)
          }
        }
      }

      KitButton {
        width: Theme.buttonWidth
        visible: root.aiCount > 0
        icon: "check"
        text: "Leave out " + root.aiCount
        disabled: bs.busy
        onClicked: bs.aiApply()
      }
    }
  }
}
