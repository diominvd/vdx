import QtQuick
import qs.config
import qs.kit

// Files options in the Shell Manager (Shell apps › Files, ModuleSettings
// "files"), by what they change: the view, the rows and their columns, the
// order, the search, the sidebar, recent and starred files, what a click does,
// the file chooser's size, what asks first, and the actions of the right click's menu.
KitColumn {
  spacing: Theme.gapGroup

  KitLabel { text: "VIEW"; value: FilesService.view.toUpperCase() }

  KitRow {
    wide: true
    label: "Show as"
    hint: "Ctrl + G in the window"

    KitSegments {
      accessibleName: "File view"
      model: [{ label: "List", value: "list" }, { label: "Grid", value: "grid" }, { label: "Columns", value: "columns" }]
      current: FilesService.view
      onPicked: value => FilesService.setOption("view", value)
    }
  }

  KitRow {
    wide: true
    label: "Density"
    hint: "A row's height in the list"

    KitSegments {
      accessibleName: "File list density"
      model: [{ label: "Compact", value: "compact" }, { label: "Normal", value: "normal" }, { label: "Roomy", value: "roomy" }]
      current: FilesService.density
      onPicked: value => FilesService.setOption("density", value)
    }
  }

  KitRow {
    wide: true
    label: "Card size"
    hint: "Of the grid"

    KitSegments {
      accessibleName: "File grid card size"
      model: [{ label: "Small", value: "small" }, { label: "Medium", value: "medium" }, { label: "Large", value: "large" }]
      current: FilesService.gridSize
      onPicked: value => FilesService.setOption("gridSize", value)
    }
  }

  KitToggleRow { module: "files"; key: "folderTiles"; fallback: true; label: "Folders as tiles"; hint: "List: folders above files" }

  KitRow {
    wide: true
    label: "Path bar"
    hint: "Ctrl + L types a path"

    KitSegments {
      accessibleName: "Path bar style"
      model: [{ label: "Crumbs", value: "crumbs" }, { label: "Field", value: "field" }]
      current: FilesService.pathBar
      onPicked: value => FilesService.setOption("pathBar", value)
    }
  }

  KitToggleRow { module: "files"; key: "preview"; label: "Show preview"; hint: "The selected file, at right" }

  KitRow {
    visible: FilesService.showPreview
    wide: true
    label: "Preview lines"
    hint: "Of a text file"

    KitSegments {
      accessibleName: "File preview line count"
      model: [{ label: "20", value: 20 }, { label: "40", value: 40 }, { label: "80", value: 80 }]
      current: FilesService.previewLines
      onPicked: value => FilesService.setOption("previewLines", value)
    }
  }

  KitLine {}

  KitLabel { text: "ROWS" }

  KitToggleRow { module: "files"; key: "checkboxes"; fallback: true; label: "Checkboxes"; hint: "Tick rows to select them" }

  KitToggleRow { module: "files"; key: "rowActions"; fallback: true; label: "Menu button"; hint: "A ⋮ on the hovered row" }

  KitToggleRow { module: "files"; key: "hidden"; fallback: false; label: "Show hidden files"; hint: "Ctrl + H in the window" }

  KitToggleRow { module: "files"; key: "thumbnails"; fallback: true; label: "Show thumbnails"; hint: "Off: an icon" }

  KitToggleRow { module: "files"; key: "extensions"; fallback: true; label: "Show extensions"; hint: "Off: photo, not photo.jpg" }

  KitRow {
    wide: true
    label: "Dates"
    hint: "Today shows the time only"

    KitSegments {
      accessibleName: "File date format"
      model: [{ label: "Short", value: "short" }, { label: "ISO", value: "iso" }]
      current: FilesService.dateFormat
      onPicked: value => FilesService.setOption("dateFormat", value)
    }
  }

  KitLine {}

  KitLabel { text: "COLUMNS"; value: [FilesService.showKind, FilesService.showSize, FilesService.showDate].filter(x => x).length + " OF 3" }

  KitToggleRow { module: "files"; key: "showKind"; fallback: false; label: "Type"; hint: "Folder, or the extension" }

  KitToggleRow { module: "files"; key: "showSize"; fallback: true; label: "Size"; hint: "Folders show their item count" }

  KitToggleRow { module: "files"; key: "showDate"; fallback: true; label: "Modified"; hint: "Trash: when it was deleted" }

  KitToggleRow { module: "files"; key: "folderCounts"; fallback: true; label: "Folder sizes"; hint: "Its items; off: --" }

  KitLine {}

  KitLabel { text: "ORDER" }

  KitRow {
    wide: true
    label: "Sort by"
    hint: "Trash: the newest first"

    KitSegments {
      accessibleName: "Sort files by"
      model: [{ label: "Name", value: "name" }, { label: "Size", value: "size" }, { label: "Modified", value: "mtime" }]
      current: FilesService.sortBy
      onPicked: value => FilesService.setOption("sortBy", value)
    }
  }

  KitToggleRow { module: "files"; key: "sortDesc"; fallback: false; label: "Descending"; hint: "Click a caption to flip it" }

  KitToggleRow { module: "files"; key: "foldersFirst"; label: "Folders first"; hint: "Sorted above the files" }

  KitRow {
    wide: true
    label: "Group by"
    hint: "Type: the kinds in turn"

    KitSegments {
      accessibleName: "Group files by"
      model: [{ label: "None", value: "none" }, { label: "Type", value: "type" }]
      current: FilesService.groupBy
      onPicked: value => FilesService.setOption("groupBy", value)
    }
  }

  KitLine {}

  KitLabel { text: "SEARCH" }

  KitRow {
    wide: true
    label: "Results kept"
    hint: "Then the search stops"

    KitSegments {
      accessibleName: "Maximum file search results"
      model: [{ label: "100", value: 100 }, { label: "300", value: 300 }, { label: "1000", value: 1000 }]
      current: FilesService.searchLimit
      onPicked: value => FilesService.setOption("searchLimit", value)
    }
  }

  KitRow {
    wide: true
    label: "Time limit"
    hint: "Then the results so far"

    KitSegments {
      accessibleName: "File search time limit"
      model: [{ label: "3 s", value: 3 }, { label: "5 s", value: 5 }, { label: "15 s", value: 15 }]
      current: FilesService.searchSeconds
      onPicked: value => FilesService.setOption("searchSeconds", value)
    }
  }

  KitToggleRow { module: "files"; key: "typeAhead"; fallback: true; label: "Type to find"; hint: "A letter jumps to a name" }

  KitLine {}

  KitLabel { text: "OPENING" }

  KitToggleRow { module: "files"; key: "singleClick"; fallback: false; label: "Open on one click"; hint: "Ctrl and shift still select" }

  KitRow {
    wide: true
    label: "Open at"
    hint: "Last folder, or a fixed one"

    KitSegments {
      accessibleName: "Starting folder behavior"
      model: [{ label: "Last folder", value: "last" }, { label: "Fixed", value: "fixed" }]
      current: FilesService.startMode
      onPicked: value => FilesService.setOption("startMode", value)
    }
  }

  // the fixed folder: a path, or ~ for home; Enter keeps it; Choose… picks it in the window
  Row {
    visible: FilesService.startMode === "fixed"
    width: parent.width
    spacing: Theme.gapMedium

    KitInput {
      width: parent.width - chooseStart.width - parent.spacing
      text: FilesService.startPath
      placeholder: "~/Documents"
      onAccepted: {
        const typed = text.trim();
        if (typed.startsWith("/") || typed === "~" || typed.startsWith("~/")) FilesService.setOption("startPath", typed);
      }
    }

    KitButton {
      id: chooseStart
      icon: "folder"
      text: "Choose…"
      onClicked: FilesService.pickFolder("Open at this folder", FilesService.startFolder(), p => { if (p !== "") FilesService.setOption("startPath", p); })
    }
  }

  KitLine {}

  KitLabel { text: "TERMINAL"; value: FilesService.terminal.split(" ")[0] }

  // the command that opens a folder: the path is added after it, quoted
  KitInput {
    text: FilesService.terminal
    placeholder: "kitty --directory"
    onAccepted: { if (text.trim() !== "") FilesService.setOption("terminal", text.trim()); }
  }

  KitLine {}

  KitLabel { text: "PICKER"; value: FilesService.pickerSize.toUpperCase() }

  // the file chooser the portal opens: a preset, or the sizes typed (no live preview to drag by)
  KitRow {
    wide: true
    label: "Size"
    hint: "Custom: sizes below"

    KitSegments {
      accessibleName: "File picker size preset"
      model: [{ label: "Small", value: "small" }, { label: "Medium", value: "medium" },
              { label: "Large", value: "large" }, { label: "Custom", value: "custom" }]
      current: FilesService.pickerSize
      onPicked: value => FilesService.setOption("pickerSize", value)
    }
  }

  KitRow {
    visible: FilesService.pickerSize === "custom"
    wide: true
    label: "Width"
    hint: "480 to 1400 px"

    KitInput {
      width: Theme.buttonWidth
      text: FilesService.pickerWidth + ""
      onAccepted: {
        const v = parseInt(text);
        if (v >= 480 && v <= 1400) FilesService.setOption("pickerWidth", v);
        else text = FilesService.pickerWidth + "";
      }
    }
  }

  KitRow {
    visible: FilesService.pickerSize === "custom"
    wide: true
    label: "Height"
    hint: "360 to 1000 px"

    KitInput {
      width: Theme.buttonWidth
      text: FilesService.pickerHeight + ""
      onAccepted: {
        const v = parseInt(text);
        if (v >= 360 && v <= 1000) FilesService.setOption("pickerHeight", v);
        else text = FilesService.pickerHeight + "";
      }
    }
  }

  KitLine {}

  KitLabel { text: "SAFETY" }

  KitToggleRow { module: "files"; key: "confirmDelete"; label: "Ask before deleting"; hint: "Delete for good asks once" }

  KitToggleRow { module: "files"; key: "confirmTrash"; fallback: false; label: "Ask before trashing"; hint: "Delete asks once" }

  KitLine {}

  // the sidebar's items in their order: shown or hidden; the sidebar itself is reordered by dragging
  KitLabel { text: "SIDEBAR" }

  KitToggleRow { module: "files"; key: "showDevices"; fallback: true; label: "Show devices"; hint: "Drives plugged in" }

  KitLine {}

  // the sidebar's rows shown or hidden, by section; the order is set by dragging in the sidebar
  KitLabel { text: "PLACES SHOWN"; value: FilesService.sidebarItems.filter(i => i.kind !== "folder" && !i.hidden).length + " OF " + FilesService.sidebarItems.filter(i => i.kind !== "folder").length }

  Repeater {
    model: FilesService.sidebarItems.filter(i => i.kind !== "folder")

    KitRow {
      required property var modelData
      label: modelData.name
      hint: ({ computer: "The storage", recent: "Files opened lately", starred: "Files you starred",
               place: "Place", trash: "Trash" })[modelData.kind] ?? ""

      KitSwitch {
        checked: !modelData.hidden
        onToggled: FilesService.setHidden(modelData.path, checked)
      }
    }
  }

  KitLabel { text: "PINNED"; value: FilesService.sidebarItems.filter(i => i.kind === "folder").length + "" }

  KitRow {
    visible: FilesService.sidebarItems.filter(i => i.kind === "folder").length === 0
    label: "No folders pinned"
    hint: "Right click a folder in Files"
  }

  Repeater {
    model: FilesService.sidebarItems.filter(i => i.kind === "folder")

    KitRow {
      required property var modelData
      label: modelData.name
      hint: modelData.path

      KitSwitch {
        checked: !modelData.hidden
        onToggled: FilesService.setHidden(modelData.path, checked)
      }
    }
  }

  KitButton {
    text: "Restore defaults"
    icon: "rotate-ccw"
    onClicked: FilesService.restoreSidebar()
  }

  KitLine {}

  KitLabel { text: "RECENT AND STARRED"; value: FilesService.starred.length + " STARRED" }

  KitRow {
    wide: true
    label: "Recent files"
    hint: "The newest, at most"

    KitSegments {
      accessibleName: "Recent files limit"
      model: [{ label: "20", value: 20 }, { label: "50", value: 50 }, { label: "100", value: 100 }]
      current: FilesService.recentLimit
      onPicked: value => FilesService.setOption("recentLimit", value)
    }
  }

  KitRow {
    wide: true
    label: "Starred"
    hint: "Ctrl + S stars a selection"

    KitButton {
      text: "Clear"
      icon: "x"
      disabled: FilesService.starred.length === 0
      onClicked: FilesService.setOption("starred", [])
    }
  }

  KitLine {}

  KitLabel { text: "ACTIONS"; value: FilesService.actions.length + " IN THE MENU" }

  // a command for the right click's menu: %f is replaced by the selected paths
  Repeater {
    model: FilesService.actions

    KitRow {
      required property var modelData
      required property int index
      wide: true
      label: modelData.label
      hint: modelData.command

      KitButton {
        icon: "x"
        onClicked: FilesService.removeAction(index)
      }
    }
  }

  KitInput {
    id: actionLabel
    placeholder: "label, e.g. Open in terminal"
    onAccepted: actionCommand.input.forceActiveFocus()
  }

  KitInput {
    id: actionCommand
    placeholder: "command, %f is the selection, e.g. kitty --directory %f"
    onAccepted: { FilesService.addAction(actionLabel.text, actionCommand.text); actionLabel.text = ""; actionCommand.text = ""; }
  }

  KitButton {
    text: "Add action"
    icon: "plus"
    onClicked: { FilesService.addAction(actionLabel.text, actionCommand.text); actionLabel.text = ""; actionCommand.text = ""; }
  }

  KitGrouper {}
}
