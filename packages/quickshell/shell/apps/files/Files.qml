import QtQuick
import Quickshell
import qs.config
import qs.kit

// The file manager, laid out as Shell Manager: the sidebar is a pane of its own (the window's header,
// the places, devices and storage); the page has the folder's header, the path as
// crumbs and the search, then the folder (or the search result, or the trash) as a list (folders as
// tiles, files as a table), a grid or columns, and a preview of the selection on the right. While
// a portal asks for files (FilesService.picker) the same window picks them: a
// file name field for save, Cancel and the accept button below.
// Keys: arrows move (grid: all four), shift extends, enter opens (picks), backspace
// goes up, alt+arrows go back and forward, ctrl+c/x/v copy, cut, paste, ctrl+a all,
// delete trashes, shift+delete removes for good, F2 renames, ctrl+n a new folder,
// ctrl+d pins the folder, ctrl+s stars the selection, a letter jumps to a name, ctrl+h hidden files, ctrl+g the view, ctrl+l the
// path, ctrl+f the search. A right click opens FilesMenu; files dropped on the
// list are copied in.
Item {
  id: root

  signal closeRequested()

  readonly property int padding: Theme.windowPadding
  // the panes and columns: dragged by their strips, kept in the options
  property int sideW: FilesService.opt("sideWidth", 190)
  property int previewW: FilesService.opt("previewWidth", 240)
  // Keep a useful strip for the file list; the preview collapses before it can
  // push the list beyond the available width in compact windows.
  readonly property real effectivePreviewW: Math.min(Math.max(0, previewW), Math.max(0, body.width - 180))
  property int sizeWidth: FilesService.opt("sizeWidth", 84)
  property int dateWidth: FilesService.opt("dateWidth", 124)
  readonly property int kindWidth: 72
  // the table's columns from the right edge, as Settings › Columns shows them: ⋮, the date, the size,
  // the type; the name takes the rest. Each {x, w}; seps: a separator in the middle of each gap
  function cols(w) {
    let r = Math.max(0, w - Theme.gapWide - (FilesService.rowActions ? 28 : 0));
    const c = { seps: [] };
    // Saved column widths are preferences, not permission to overflow a small
    // viewport. Shrink each visible column to the space left after its gap.
    const take = (key, width) => {
      const actual = Math.max(0, Math.min(width, r - Theme.gapWide));
      c[key] = { x: Math.max(0, r - actual), w: actual };
      r = Math.max(0, r - actual - Theme.gapWide);
      c.seps.push(Math.max(0, r + Theme.gapWide / 2));
    };
    if (FilesService.showDate) take("date", dateWidth);
    if (FilesService.showSize) take("size", sizeWidth);
    if (FilesService.showKind) take("kind", kindWidth);
    c.nameEnd = Math.max(0, r);
    return c;
  }
  // where a row's icon starts: after the box to tick
  readonly property int nameX: Theme.gapWide + (FilesService.checkboxes && !picker ? 16 + Theme.gapWide : 0)
  // the list view shows the folders as tiles above the files (not in a search, the trash or a picker)
  readonly property bool tiles: FilesService.folderTiles && !grid && !columnsView && !FilesService.searching
                                && !FilesService.virtual && FilesService.groupBy === "none"
  readonly property bool grid: FilesService.shownView === "grid"
  readonly property bool columnsView: FilesService.shownView === "columns"
  readonly property bool selectedDir: FilesService.selected.length === 1 && FilesService.selected[0].kind === "dir"
  readonly property var picker: FilesService.picker

  // what is being typed in the footer or over a row: a folder or a file to
  // create, a path to rename; a delete or an empty waiting for its second press
  property string creating: ""           // "" | folder | file
  property string renaming: ""           // a path
  property bool sure: false
  property bool emptySure: false
  property bool helpOpen: false          // F1: the keys
  property bool trashSure: false         // a move to the trash waiting for its second press
  property int parentW: FilesService.parentWidth    // the Columns view's side columns, dragged
  property int childW: FilesService.childWidth
  readonly property bool markdown: previewed !== null && previewed.name.toLowerCase().endsWith(".md")

  readonly property var previewed: FilesService.selected.length === 1 ? FilesService.selected[0] : null
  // folders have no preview: only a file's
  readonly property bool previewing: FilesService.showPreview && previewed !== null && previewed.kind !== "dir"

  focus: true
  Keys.onPressed: event => handleKey(event)

  Connections {
    target: FilesService
    // a new folder starts at its top, not where the last one was scrolled to
    function onPathChanged() {
      root.sure = false; root.emptySure = false;
      // the top is the header (Up, the tiles), above the first row
      Qt.callLater(() => { listFrame.listView.contentY = listFrame.listView.originY; listFrame.gridView.contentY = listFrame.gridView.originY; });
    }
    function onSelectionChanged() { root.sure = false; root.trashSure = false; }
    function onPickerChanged() { saveField.text = FilesService.picker ? FilesService.picker.name : ""; }
    function onQueryChanged() { if (searchField.text !== FilesService.query) searchField.text = FilesService.query; }
    // the keys move the selection: the view follows it
    function onAnchorChanged() {
      if (root.grid) {
        const i = FilesService.shown.findIndex(e => e.path === FilesService.anchor);
        if (i >= 0) listFrame.gridView.positionViewAtIndex(i, GridView.Contain);
        return;
      }
      const i = listFrame.listModel.findIndex(e => e.path === FilesService.anchor);
      // a folder's tile sits in the list's header
      if (i < 0) listFrame.listView.contentY = listFrame.listView.originY;
      else listFrame.listView.positionViewAtIndex(i, ListView.Contain);
    }
  }

  // typing a name jumps to it (Settings › Type to find): the letters typed in a short while
  property string typed: ""
  Timer { id: typedTimer; interval: 900; onTriggered: root.typed = "" }
  function typeAhead(text) {
    typed += text.toLowerCase();
    typedTimer.restart();
    const hit = FilesService.rows.find(e => e.name.toLowerCase().startsWith(typed));
    if (hit) FilesService.select(hit.path, "single");
  }

  function handleKey(event) {
    const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
    const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
    const alt = (event.modifiers & Qt.AltModifier) !== 0;
    if (event.key === Qt.Key_Escape) {
      if (menu.visible) menu.close();
      else if (helpOpen) helpOpen = false;
      else if (FilesService.job !== null) FilesService.cancelJob();
      else if (FilesService.panel !== null) FilesService.closeInfo();
      else if (picker) FilesService.finishPick([], 1);
      else if (FilesService.dupes) FilesService.leaveDupes();
      else if (FilesService.everywhere) FilesService.toggleEverywhere();
      else if (FilesService.query !== "") FilesService.setQuery("");
      else if (FilesService.selection.length > 0) FilesService.selection = [];
      else root.closeRequested();
      return;
    }
    if (ctrl) {
      switch (event.key) {
        case Qt.Key_A: FilesService.selectAll(); return;
        case Qt.Key_C: FilesService.copySelection(); return;
        case Qt.Key_X: if (!FilesService.inTrash && !picker) FilesService.cutSelection(); return;
        case Qt.Key_V: if (picker) return; if (FilesService.canPaste) FilesService.paste(); else FilesService.pasteFromSystem(); return;
        case Qt.Key_T: FilesService.openTerminal(root.folderForTerminal()); return;
        case Qt.Key_R: if (FilesService.inTrash) FilesService.restoreSelection(); return;
        case Qt.Key_N: if (FilesService.writable && !picker) startCreate("folder"); return;
        case Qt.Key_D: if (FilesService.writable) FilesService.pin(FilesService.path); return;
        case Qt.Key_S: if (FilesService.selection.length > 0) FilesService.toggleStar(FilesService.selection); return;
        case Qt.Key_H: FilesService.setOption("hidden", !FilesService.hidden); return;
        case Qt.Key_G: FilesService.cycleView(); return;
        case Qt.Key_Z: if (picker) return; if (shift) FilesService.redo(); else FilesService.undo(); return;
        case Qt.Key_Y: if (!picker) FilesService.redo(); return;
        case Qt.Key_K: FilesService.toggleEverywhere(); searchField.input.forceActiveFocus(); return;
        case Qt.Key_L: crumbs.edit(); return;
        case Qt.Key_F: searchField.input.forceActiveFocus(); return;
      }
      return;
    }
    if (alt && event.key === Qt.Key_Left) { FilesService.back(); return; }
    if (alt && event.key === Qt.Key_Right) { FilesService.forward(); return; }
    const cols = root.grid ? FilesService.columns : 1;
    switch (event.key) {
      case Qt.Key_Up: FilesService.step(-cols, shift); return;
      case Qt.Key_Down: FilesService.step(cols, shift); return;
      case Qt.Key_Left: if (root.grid) FilesService.step(-1, shift); return;
      case Qt.Key_Right: if (root.grid) FilesService.step(1, shift); return;
      case Qt.Key_Return:
      case Qt.Key_Enter:
        if (picker) accept();
        else if (FilesService.selected.length === 1) open(FilesService.selected[0]);
        return;
      case Qt.Key_Backspace: FilesService.up(); return;
      case Qt.Key_F2:
        if (FilesService.inTrash || picker) return;
        if (FilesService.selected.length === 1) renaming = FilesService.selected[0].path;
        else if (FilesService.selected.length > 1) startCreate("batch");
        return;
      case Qt.Key_F5: FilesService.refresh(); return;
      case Qt.Key_F1: helpOpen = !helpOpen; return;
      case Qt.Key_Space: FilesService.setOption("preview", !FilesService.showPreview); return;
      case Qt.Key_Delete: remove(shift); return;
    }
    if (FilesService.typeAhead && !alt && event.text.length === 1 && event.text > " ") { typeAhead(event.text); event.accepted = true; }
  }

  // a folder opens inside the window, a file with its default program; in a picker a file is picked
  function open(entry) {
    if (picker && entry.kind !== "dir") {
      FilesService.select(entry.path, "single");
      accept();
    } else if (entry.kind === "dir" && !FilesService.inTrash) {
      FilesService.go(entry.path);
    } else {
      FilesService.openExternal(entry.path);
    }
  }

  // a click: ctrl toggles, shift takes the range; in a save picker a file's name goes to the field
  function click(entry, mouse) {
    root.forceActiveFocus();
    // Settings › Behaviour: one click opens, unless a modifier selects
    if (FilesService.singleClick && !(mouse.modifiers & (Qt.ShiftModifier | Qt.ControlModifier))) {
      FilesService.select(entry.path, "single");
      open(entry);
      return;
    }
    if (mouse.modifiers & Qt.ShiftModifier) FilesService.select(entry.path, "range");
    else if (mouse.modifiers & Qt.ControlModifier) FilesService.select(entry.path, "toggle");
    else FilesService.select(entry.path, "single");
    if (picker && picker.mode === "save" && entry.kind !== "dir") saveField.text = entry.name;
  }

  function contextMenu(entry, at) {
    if (!FilesService.selection.includes(entry.path)) FilesService.select(entry.path, "single");
    menu.open(at.x, at.y, menuFor(entry));
  }

  // to the trash (asked once when Settings › Safety says so); a permanent delete (shift, or anything in the trash) asks once when confirm is on
  function remove(permanent) {
    if (FilesService.selection.length === 0 || picker) return;
    if (FilesService.inTrash || permanent) {
      if (FilesService.confirmDelete && !sure) { sure = true; return; }
      sure = false;
      FilesService.deleteSelection();
    } else {
      if (FilesService.confirmTrash && !trashSure) { trashSure = true; return; }
      trashSure = false;
      FilesService.trashSelection();
    }
  }

  // ctrl + t: the folder selected, or the one shown
  function folderForTerminal() {
    const one = FilesService.selected.length === 1 && FilesService.selected[0].kind === "dir";
    return one ? FilesService.selected[0].path : FilesService.path;
  }

  function emptyTrash() {
    if (FilesService.confirmDelete && !emptySure) { emptySure = true; return; }
    emptySure = false;
    FilesService.emptyTrash();
  }

  function startCreate(kind) {
    creating = kind;
    creatingField.text = "";
    creatingField.input.forceActiveFocus();
  }

  function finishCreate() {
    const name = creatingField.text.trim();
    if (name !== "") {
      if (creating === "folder") FilesService.createFolder(name);
      else if (creating === "batch") FilesService.batchRename(name);
      else FilesService.createFile(name);
    }
    creating = "";
    root.forceActiveFocus();
  }

  function finishRename(entry, name) {
    renaming = "";
    if (name.trim() !== "" && name.trim() !== entry.name) FilesService.rename(entry.path, name);
    root.forceActiveFocus();
  }

  // the picker's accept: the selected files (or the folder, for a folder picker, or the save name)
  function accept() {
    if (!picker) return;
    if (picker.mode === "save") {
      const name = saveField.text.trim();
      if (!FilesService.validName(name)) return;
      if (FilesService.entries.some(e => e.name === name)) {
        FilesService.error = "\"" + name + "\" is here already";
        return;
      }
      FilesService.finishPick([FilesService.path + "/" + name], 0);
      return;
    }
    const picked = FilesService.selected
      .filter(e => picker.directory ? e.kind === "dir" : e.kind !== "dir")
      .map(e => e.path);
    if (picked.length === 0) {
      if (picker.directory) FilesService.finishPick([FilesService.path], 0);
      return;
    }
    FilesService.finishPick(picker.multiple ? picked : picked.slice(0, 1), 0);
  }

  // a drop from another app: the files are copied into the folder (the one shown, or a folder's tile or
  // card), not ones already there and not a folder into itself
  function dropped(urls, dest) {
    const paths = urls.map(u => FilesService.pathFromUri(u.toString()))
                      .filter(p => p !== "" && p !== dest && FilesService.parentOf(p) !== dest);
    const writable = dest !== FilesService.path || FilesService.writable;
    if (paths.length > 0 && writable && !picker)
      FilesService.act({ done: "pasted" }, ["paste", "copy", dest].concat(paths));
  }

  function when(time) {
    const d = new Date(time * 1000);
    if (FilesService.dateFormat === "iso") return Qt.formatDateTime(d, "yyyy-MM-dd HH:mm");
    const today = d.toDateString() === new Date().toDateString();
    return Qt.formatDateTime(d, today ? "HH:mm" : "dd.MM.yy HH:mm");
  }

  function iconFor(kind) {
    return { dir: "folder", image: "image", video: "video", audio: "music", text: "file", archive: "package" }[kind] ?? "file";
  }

  function placeIcon(name) {
    return { Home: "home", Desktop: "monitor", Documents: "file", Downloads: "download", Music: "music",
             Pictures: "image", Videos: "video", Root: "server", Trash: "trash" }[name] ?? "folder";
  }
  // the header's icon for a path: a place's own, else a folder
  function placeIconFor(p) {
    if (p === FilesService.computerPath) return "monitor";
    if (p === FilesService.trashPath) return "trash";
    if (p === FilesService.recentPath) return "history";
    if (p === FilesService.starredPath) return "star";
    if (p === FilesService.home) return "home";
    const place = FilesService.places.find(x => x.path === p);
    return place ? placeIcon(place.name) : "folder";
  }

  // the header's subtitle: what is here, then what is selected
  function counts() {
    const rows = FilesService.rows;
    const dirs = rows.filter(e => e.kind === "dir").length;
    const parts = [];
    if (dirs > 0) parts.push(dirs + (dirs === 1 ? " FOLDER" : " FOLDERS"));
    if (rows.length - dirs > 0 || dirs === 0) parts.push((rows.length - dirs) + (rows.length - dirs === 1 ? " FILE" : " FILES"));
    if (FilesService.selection.length > 0) parts.push(FilesService.selection.length + " SELECTED");
    return parts.join(" · ");
  }

  // the type column: a folder, or the file's extension
  function kindLabel(e) {
    if (e.kind === "dir") return "Folder";
    const i = e.name.lastIndexOf(".");
    if (i > 0 && e.name.length - i <= 6) return e.name.slice(i + 1).toUpperCase();
    return e.kind.charAt(0).toUpperCase() + e.kind.slice(1);
  }

  // the size column: a file's size, a folder's items (Settings › Folder sizes)
  function sizeLabel(e) {
    if (e.kind !== "dir") return Format.humanSize(e.size);
    if (e.count === undefined || e.count < 0) return "--";
    return e.count === 1 ? "1 item" : e.count + " items";
  }

  // a path as a URL the image loader reads
  function fileUrl(p) { return FilesService.fileUri(p); }

  // the menu of a right click: what an entry can do now (a dimmed row can't)
  function menuFor(entry) {
    const one = FilesService.selection.length === 1;
    if (FilesService.inTrash) return [
      { label: "Open", run: () => root.open(entry) },
      { label: "Restore", hint: "Ctrl + R", run: () => FilesService.restoreSelection() },
      { label: "Delete for good", hint: "Delete", run: () => root.remove(true) },
    ];
    return [
      { label: "Open", run: () => root.open(entry) },
      { label: "Rename", hint: "F2", disabled: !one || picker !== null, run: () => root.renaming = entry.path },
      { label: "Copy", hint: "Ctrl + C", run: () => FilesService.copySelection() },
      { label: "Cut", hint: "Ctrl + X", disabled: picker !== null, run: () => FilesService.cutSelection() },
      { label: "Paste", hint: "Ctrl + V", disabled: !FilesService.canPaste || picker !== null, run: () => FilesService.paste() },
      { label: FilesService.isStarred(entry.path) ? "Unstar" : "Star", hint: "Ctrl + S", run: () => FilesService.toggleStar(FilesService.selection) },
      { label: "Open the folder it is in", disabled: !FilesService.virtual && !FilesService.searching, run: () => FilesService.reveal(entry.path) },
      { label: "Properties", run: () => FilesService.inspect(entry.path) },
      { label: "Terminal here", disabled: entry.kind !== "dir", run: () => FilesService.openTerminal(entry.path) },
      { label: "Find duplicates here", disabled: entry.kind !== "dir", run: () => FilesService.findDuplicates(entry.path) },
      { label: "Pin to sidebar", disabled: entry.kind !== "dir" || FilesService.isPinned(entry.path), run: () => FilesService.pin(entry.path) },
      { label: "Copy path", run: () => Quickshell.execDetached(["wl-copy", entry.path]) },
      { label: "Move to trash", hint: "Delete", disabled: picker !== null, run: () => root.remove(false) },
      { label: "Delete for good", hint: "Shift + Delete", disabled: picker !== null, run: () => root.remove(true) },
    ].concat(picker !== null ? [] : FilesService.actions.map(a => ({
      label: a.label, run: () => FilesService.runAction(a, FilesService.selection),
    })));
  }

  // ---- the sidebar: its own pane, as in Shell Manager: the window's header, the places, the storage ----
  Rectangle {
    id: sidePane
    visible: root.picker === null
    // the list's width plus the window's frame on each side, as Shell Manager's
    width: visible ? root.sideW + root.padding : 0
    height: parent.height
    color: Theme.background0

    Column {
      id: brand
      anchors { left: parent.left; leftMargin: root.padding; right: parent.right; top: parent.top; topMargin: root.padding - Theme.headerInset }
      spacing: Theme.gapGroup

      KitHeader {
        icon: "folder"
        title: "Files"
        subtitle: FilesService.selection.length > 0 ? FilesService.selection.length + " SELECTED"
                : FilesService.clip.length > 0 ? FilesService.clip.length + (FilesService.clipMode === "move" ? " TO MOVE" : " TO COPY")
                : "SUPER + E"
      }

      KitLine {}
    }

    FilesSidebar {
      id: sideFrame
      files: root
      x: root.padding
      y: brand.y + brand.height + Theme.gapGroup
      width: Math.max(0, root.sideW - root.padding)
      height: parent.height - root.padding - y
    }
  }

  // the line between the panes, and the strip on it: drag it to resize the sidebar
  Rectangle {
    visible: sidePane.visible
    anchors { left: sidePane.right; top: parent.top; bottom: parent.bottom }
    width: 1
    color: Theme.background3
  }
  FilesSplit {
    visible: sidePane.visible
    x: sidePane.width - width / 2
    y: 0
    height: root.height
    reference: root
    onDragged: x => root.sideW = Math.max(170, Math.min(380, x - root.padding))
    onFinished: FilesService.setOption("sideWidth", root.sideW)
  }

  // ---- the page: the folder's header, the path and the search, the list, the preview ----
  Item {
    id: page
    anchors { left: sidePane.right; right: parent.right; top: parent.top; bottom: parent.bottom
              leftMargin: (sidePane.visible ? 1 : 0) + root.padding; rightMargin: root.padding }

    KitHeader {
      id: header
      anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: root.padding - Theme.headerInset }
      icon: root.picker ? "folder" : root.placeIconFor(FilesService.path)
      title: root.picker ? root.picker.title : FilesService.title
      subtitle: FilesService.dupes ? "DUPLICATES · " + FilesService.rows.length + " FILES IN " + FilesService.dupGroups + " GROUPS"
              : root.picker ? (root.picker.mode === "save" ? "SAVE" : root.picker.directory ? "CHOOSE A FOLDER" : "CHOOSE")
                              + (FilesService.selection.length > 0 ? " · " + FilesService.selection.length + " SELECTED" : "")
              : FilesService.atComputer ? FilesService.volumes.length + " STORAGE"
              : FilesService.searching ? "SEARCH · " + FilesService.shown.length + " FOUND"
              : root.counts()

      KitButton {
        icon: "arrow-left"
        disabled: !FilesService.canBack
        onClicked: FilesService.back()
      }
      KitButton {
        icon: "arrow-right"
        disabled: !FilesService.canForward
        onClicked: FilesService.forward()
      }
      KitButton {
        icon: "arrow-up"
        disabled: !FilesService.canUp
        onClicked: FilesService.up()
      }
      // the views, side by side: the one shown is selected
      Repeater {
        model: FilesService.atComputer ? ["list", "grid"] : ["list", "grid", "columns"]
        KitButton {
          required property string modelData
          icon: modelData
          selected: FilesService.shownView === modelData
          onClicked: FilesService.setOption(FilesService.atComputer ? "computerView" : "view", modelData)
        }
      }
      KitButton {
        icon: "sliders"
        text: FilesService.sortLabel + (FilesService.atComputer ? " ↑" : FilesService.sortDesc ? " ↓" : " ↑")
        visible: !root.picker && (root.grid || FilesService.atComputer)
        onClicked: FilesService.sortNext()
      }
      KitButton {
        icon: "plus"
        text: "New"
        visible: FilesService.writable && !root.picker
        onClicked: root.startCreate("folder")
      }
      KitButton {
        icon: "trash"
        text: root.emptySure ? "Sure?" : "Empty"
        visible: FilesService.inTrash
        disabled: FilesService.entries.length === 0
        onClicked: root.emptyTrash()
      }
    }

    KitLine {
      id: headerLine
      anchors { top: header.bottom; topMargin: Theme.gapGroup }
      width: parent.width
    }

    // ---- the path and the search ----
    Row {
      id: fields
      anchors { top: headerLine.bottom; left: parent.left; right: parent.right; topMargin: Theme.gapGroup }
      spacing: Theme.gapMedium

      FilesCrumbs {
        id: crumbs
        width: Math.max(0, parent.width - searchField.width - parent.spacing)
        onDone: root.forceActiveFocus()
      }

      KitInput {
        id: searchField
        width: Math.max(0, Math.min(260, parent.width * 0.32))
        placeholder: FilesService.everywhere ? "Search all of Home…" : FilesService.virtual ? "filter" : "Search here and below…"
        passKeys: [Qt.Key_Escape]
        text: FilesService.query
        onTextEdited: FilesService.setQuery(text)
        onKeyPassed: { if (FilesService.everywhere) FilesService.toggleEverywhere(); else FilesService.setQuery(""); root.forceActiveFocus(); }
        onAccepted: root.forceActiveFocus()
      }
    }

    // ---- body: the list or grid (or the storage), the preview beside it ----
    Item {
      id: body
      anchors { top: fields.bottom; bottom: footer.top; left: parent.left; right: parent.right
                topMargin: Theme.gapGroup; bottomMargin: footer.height > 0 ? Theme.gapMedium : 0 }

      FilesList {
        id: listFrame
        files: root
        visible: !FilesService.atComputer
        x: 0
        y: 0
        width: Math.max(0, body.width - (root.previewing && root.effectivePreviewW > 0 ? previewSplit.width + root.effectivePreviewW : 0))
        height: body.height
      }

      // This computer: the storage, in the list's place
      FilesComputer {
        visible: FilesService.atComputer
        files: root
        x: 0
        y: 0
        width: body.width
        height: body.height
      }

      // the strip between the list and the preview: drag it to resize the preview
      FilesSplit {
        id: previewSplit
        visible: root.previewing && root.effectivePreviewW > 0
        x: listFrame.width
        y: 0
        height: body.height
        reference: body
        onDragged: x => root.previewW = Math.max(180, Math.min(480, body.width - x - width / 2))
        onFinished: FilesService.setOption("previewWidth", root.previewW)
      }

      FilesPreview {
        id: previewFrame
        files: root
        visible: root.previewing && root.effectivePreviewW > 0
        x: body.width - root.effectivePreviewW
        y: 0
        width: root.effectivePreviewW
        height: body.height
      }
    }

    // ---- footer: the picker's buttons, a name being typed, the error, or the keys ----
    Item {
      id: footer
      anchors { bottom: parent.bottom; left: parent.left; right: parent.right; bottomMargin: root.padding }
      // only while there is something to say or type: the list takes the room otherwise
      height: root.picker !== null || root.creating !== "" || statusLine.text !== "" ? 32 : 0

      Row {
        visible: root.picker !== null
        anchors.fill: parent
        spacing: Theme.gapMedium

        KitInput {
          id: saveField
          width: Math.max(0, parent.width - cancelButton.width - acceptButton.width - 2 * parent.spacing)
          visible: root.picker !== null && root.picker.mode === "save"
          placeholder: "file name"
          text: root.picker ? root.picker.name : ""
          passKeys: [Qt.Key_Escape]
          onAccepted: root.accept()
          onKeyPassed: FilesService.finishPick([], 1)
        }

        KitText {
          width: Math.max(0, parent.width - cancelButton.width - acceptButton.width - 2 * parent.spacing)
          visible: root.picker !== null && root.picker.mode !== "save"
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
          text: FilesService.error !== "" ? FilesService.error : "enter " + (root.picker && root.picker.directory ? "selects the folder" : "opens") + " · esc cancel"
          color: FilesService.error !== "" ? Theme.red : Theme.muted
          font.pixelSize: Theme.fontSize - 1
        }

        KitButton {
          id: cancelButton
          text: "Cancel"
          onClicked: FilesService.finishPick([], 1)
        }

        KitButton {
          id: acceptButton
          text: root.picker ? (root.picker.mode === "save" ? "Save" : root.picker.directory ? "Select" : "Open") : ""
          onClicked: root.accept()
        }
      }

      KitInput {
        id: creatingField
        width: parent.width
        visible: root.creating !== "" && root.picker === null
        placeholder: root.creating === "folder" ? "new folder name" : root.creating === "batch" ? "pattern: photo_{n}{ext}  ({n} number, {name} stem)" : "new file name"
        passKeys: [Qt.Key_Escape]
        onAccepted: root.finishCreate()
        onKeyPassed: { root.creating = ""; root.forceActiveFocus(); }
      }

      KitText {
        id: statusLine
        anchors.fill: parent
        visible: root.creating === "" && root.picker === null
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: FilesService.error !== "" ? FilesService.error
            : FilesService.job !== null ? FilesService.job.label + " " + FilesService.job.name + (FilesService.job.of > 0 ? " · " + FilesService.job.progress + " of " + FilesService.job.of : "") + " · esc cancel"
            : root.trashSure ? "Move to trash? Press delete again"
            : root.sure ? "Delete for good? Press delete again"
            : root.emptySure ? "Empty the trash? Press Empty again"
            : FilesService.clip.length > 0 && !FilesService.inTrash
              ? FilesService.clip.length + (FilesService.clipMode === "move" ? " to move" : " to copy") + " · ctrl + v paste"
            : ""
        color: FilesService.error !== "" || root.sure || root.emptySure || root.trashSure ? Theme.red : Theme.muted
        font.pixelSize: Theme.fontSize - 1
      }
    }
  }

  // the menus open where they were asked for (scene coordinates = the window's)
  function menuAt(at, items) { menu.open(at.x, at.y, items); }

  // a group header's menu: fold it, or trash the copies in every group
  function groupMenu(group) {
    return [
      { label: FilesService.isCollapsed(group.group) ? "Unfold" : "Fold", run: () => FilesService.toggleGroup(group.group) },
      { label: "Trash the copies", hint: "keeps one per group", run: () => FilesService.trashCopies() },
    ];
  }

  // ---- properties of a file: the panel (Menu › Properties) ----
  // the keys, for F1
  readonly property var keyRows: [
    { key: "enter", action: "open, or pick in a picker" },
    { key: "backspace", action: "the folder above" },
    { key: "alt + ← →", action: "back and forward" },
    { key: "↑ ↓ (grid: ← →)", action: "move; with shift, extend" },
    { key: "Ctrl + A, C, X, V", action: "select all, copy, cut, paste" },
    { key: "Ctrl + Z / Shift + Z", action: "undo, redo" },
    { key: "Delete", action: "move to trash" },
    { key: "Shift + Delete", action: "delete for good" },
    { key: "F2", action: "rename" },
    { key: "Ctrl + N / D", action: "new folder, pin this folder" },
    { key: "Ctrl + S", action: "star or unstar" },
    { key: "a letter", action: "jump to a name" },
    { key: "Ctrl + F", action: "focus the search" },
    { key: "Ctrl + K", action: "search all of Home, or this folder" },
    { key: "Ctrl + H / G", action: "hidden files, grid view" },
    { key: "Ctrl + L", action: "type a path" },
    { key: "space", action: "show or hide the preview" },
    { key: "f5", action: "read the folder again" },
    { key: "esc", action: "clear, close" },
  ]

  // a click off the panels closes them
  MouseArea {
    anchors.fill: parent
    visible: FilesService.panel !== null || root.helpOpen
    z: 27
    acceptedButtons: Qt.AllButtons
    onPressed: { FilesService.closeInfo(); root.helpOpen = false; }
  }

  KitFrame {
    id: infoCard
    z: 28
    width: 380
    anchors.centerIn: parent
    visible: FilesService.panel !== null

    KitHeader {
      icon: "info"
      title: FilesService.panel ? FilesService.panel.title : ""
      subtitle: FilesService.panel ? FilesService.panel.subtitle : ""
    }

    KitLine {}

    Repeater {
      model: FilesService.panel ? FilesService.panel.rows : []

      Row {
        required property var modelData
        width: Math.max(0, infoCard.width - 2 * infoCard.padding)
        spacing: Theme.gapMedium

        KitText {
          width: 96
          text: modelData.label
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 1
        }

        KitText {
          width: Math.max(0, parent.width - 96 - parent.spacing)
          text: modelData.value
          wrapMode: Text.WrapAnywhere
          font.pixelSize: Theme.fontSize - 1
        }
      }
    }
  }

  // ---- the keys (F1) ----
  KitFrame {
    id: helpCard
    z: 28
    width: 400
    anchors.centerIn: parent
    visible: root.helpOpen

    KitHeader { icon: "keyboard"; title: "Keys" }

    KitLine {}

    Repeater {
      model: root.keyRows

      Row {
        required property var modelData
        width: Math.max(0, helpCard.width - 2 * helpCard.padding)
        spacing: Theme.gapMedium

        KitText {
          width: 150
          text: modelData.key
          font.pixelSize: Theme.fontSize - 1
        }

        KitText {
          width: Math.max(0, parent.width - 150 - parent.spacing)
          text: modelData.action
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 1
        }
      }
    }
  }

  // a click off the menu closes it
  MouseArea {
    anchors.fill: parent
    visible: menu.visible
    z: 19
    acceptedButtons: Qt.AllButtons
    onPressed: menu.close()
  }

  FilesMenu {
    id: menu
    z: 20
  }
}
