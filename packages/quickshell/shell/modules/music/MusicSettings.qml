import QtQuick
import qs.apps.files
import qs.bar
import qs.config
import qs.kit
import qs.modules.player

// Music options in the Shell Manager: the bar's face, the player's timeline, which players
// the module shows, the Music window (how it opens, closes) and the local folders the Files
// source lists.
KitColumn {
  id: root
  spacing: Theme.gapGroup

  KitLabel { text: "BAR" }
  BarTextRow { module: "music" }

  KitOptionRow {
    visible: ModuleSettings.get("music", "text", "content") === "content"
    module: "music"; key: "show"; fallback: "both"
    label: "Shows"; hint: "What the bar names while something plays"
    model: [{ label: "Icon", value: "icon" }, { label: "Title", value: "title" }, { label: "Artist", value: "artist" },
            { label: "Both", value: "both" }]
  }

  KitOptionRow {
    visible: ModuleSettings.get("music", "text", "content") === "content" && ModuleSettings.get("music", "show", "both") !== "icon"
    module: "music"; key: "titleLength"; fallback: 60
    label: "Max length"; hint: "Longer ones end with …"
    model: [{ label: "30", value: 30 }, { label: "45", value: 45 }, { label: "60", value: 60 }, { label: "Full", value: -1 }]
  }

  KitLine {}

  KitLabel { text: "PLAYER" }

  KitToggleRow {
    module: "music"; key: "showRemaining"; fallback: false
    label: "Time left"; hint: "The timeline counts down"
  }

  KitLine {}

  KitLabel { text: "PLAYERS" }

  KitOptionRow {
    module: "music"; key: "players"; fallback: "all"
    label: "Show"; hint: "Hidden ones stay in their own app"
    model: [{ label: "All players", value: "all" }, { label: "Music only", value: "music" }, { label: "Pick", value: "pick" }]
  }

  KitRow {
    visible: root.picking && root.pickList.length === 0
    label: "No players"
    hint: "Start one to pick it"
  }

  // Pick: every MPRIS player running now, and the hidden ones
  Repeater {
    model: root.picking ? root.pickList : []

    KitRow {
      required property var modelData
      label: modelData
      hint: PlayerService.mprisNames.includes(modelData) ? "" : "Not running"

      KitSwitch {
        checked: !root.hidden.includes(modelData)
        onToggled: root.setHidden(modelData, !root.hidden.includes(modelData))
      }
    }
  }

  KitLine {}

  KitLabel { text: "WINDOW" }

  KitRow {
    wide: true
    label: "Opens on"
    hint: "The page it shows first"

    KitSegments {
      accessibleName: "Music window opening page"
      model: [{ label: "Last tab", value: "last" }, { label: "Yandex", value: "yandex" },
              { label: "Files", value: "files" }, { label: "Radio", value: "radio" }]
      current: ModuleSettings.get("music", "opensOn", "last")
      onPicked: value => ModuleSettings.set("music", "opensOn", value)
    }
  }

  KitToggleRow {
    module: "music"; key: "closeOnPlay"; fallback: false
    label: "Close when a track plays"; hint: "After a click in a list"
  }

  KitLine {}

  KitLabel { text: "FILES"; value: root.folders.length + "" }

  KitRow {
    visible: root.folders.length === 0
    label: "No folders"
    hint: "Files is not listed"
  }

  Repeater {
    model: root.folders

    KitRow {
      required property var modelData
      label: root.nameOf(modelData)
      hint: modelData

      KitButton {
        icon: "x"
        onClicked: root.setFolders(root.folders.filter(f => f !== modelData))
      }
    }
  }

  // a folder typed (Enter adds it) or picked
  Row {
    width: parent.width
    spacing: Theme.gapMedium

    KitInput {
      id: typed
      width: parent.width - choose.width - parent.spacing
      placeholder: "~/Music"
      onAccepted: root.addFolder(text)
    }

    KitButton {
      id: choose
      icon: "folder"
      text: "Choose…"
      onClicked: FilesService.pickFolder("Music folder", FilesService.startFolder(), p => root.addFolder(p))
    }
  }

  KitGrouper {}

  // ---- players ----
  readonly property bool picking: ModuleSettings.get("music", "players", "all") === "pick"
  readonly property var hidden: ModuleSettings.get("music", "hiddenPlayers", [])
  readonly property var pickList: PlayerService.mprisNames
    .concat(hidden.filter(n => !PlayerService.mprisNames.includes(n)))
    .filter((n, i, all) => all.indexOf(n) === i)

  function setHidden(name, hide) {
    const rest = hidden.filter(n => n !== name);
    ModuleSettings.set("music", "hiddenPlayers", hide ? rest.concat([name]) : rest);
  }

  // ---- folders ----
  readonly property var folders: ModuleSettings.get("music", "folders", ["~/Music"])

  function nameOf(path) { return path.split("/").filter(s => s !== "").pop() ?? path; }

  function setFolders(list) { ModuleSettings.set("music", "folders", list); }

  function addFolder(path) {
    const p = path.trim();
    if (p === "" || folders.includes(p)) return;
    setFolders(folders.concat([p]));
    typed.text = "";
  }
}
