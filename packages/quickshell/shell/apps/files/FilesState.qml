import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../../kit/reply.js" as Reply

// The file manager's state (scripts/files.py), one per window: FilesService is the browser's,
// the file picker's window makes its own, so the two never share a folder or a selection: the folder shown and its
// history, the entries sorted and filtered, the selection, the cut or copied
// paths, the places, bookmarks, devices (udisks2), the preview of a text file,
// and the picker of the file-chooser portal (scripts/files_portal.py runs
// here, kept by the shell). The trash is a list of its own (`trashPath`, not a
// folder). Options: Shell Manager › Shell apps › Files (ModuleSettings "files").
Scope {
  id: root

  readonly property string script: Paths.scriptsDir + "/files.py"
  readonly property string portalScript: Paths.scriptsDir + "/files_portal.py"
  readonly property string trashPath: "trash:"
  readonly property string computerPath: "computer:"             // This computer: the storage (volumes)
  readonly property string recentPath: "recent:"                 // the files opened lately (recently-used.xbel)
  readonly property string starredPath: "starred:"               // the files and folders starred
  readonly property string home: Quickshell.env("HOME")

  // ---- options ----
  function opt(key, fallback) { return ModuleSettings.get("files", key, fallback); }
  readonly property bool hidden: opt("hidden", false)
  readonly property bool foldersFirst: opt("foldersFirst", true)
  readonly property string sortBy: opt("sortBy", "name")          // name | size | mtime
  readonly property bool sortDesc: opt("sortDesc", false)
  readonly property var sortKeys: ["name", "size", "mtime"]
  readonly property bool confirmDelete: opt("confirmDelete", true)
  readonly property string view: opt("view", "list")              // list | grid
  // This computer has its own look, apart from the folders' (list | grid)
  readonly property string computerView: opt("computerView", "grid")
  readonly property string shownView: atComputer ? computerView : view
  readonly property bool showPreview: opt("preview", true)
  readonly property var sidebarStored: opt("sidebar", [])         // [{path, name, kind, hidden}]: see sidebarItems
  readonly property var actions: opt("actions", [])               // [{label, command}]: %f is the selection
  readonly property bool thumbnails: opt("thumbnails", true)
  readonly property bool singleClick: opt("singleClick", false)
  readonly property string dateFormat: opt("dateFormat", "short") // short | iso
  readonly property string terminal: opt("terminal", "kitty --directory")
  readonly property string groupBy: opt("groupBy", "none")       // none | type
  readonly property int searchLimit: opt("searchLimit", 300)
  readonly property int searchSeconds: opt("searchSeconds", 5)
  readonly property int previewLines: opt("previewLines", 40)
  readonly property bool confirmTrash: opt("confirmTrash", false)
  readonly property int parentWidth: opt("parentWidth", 170)
  // the file chooser's size: a preset, or the custom width and height (Settings › Picker)
  readonly property var pickerPresets: ({ small: [640, 440], medium: [760, 540], large: [920, 660] })
  readonly property string pickerSize: opt("pickerSize", "medium")
  readonly property int pickerWidth: opt("pickerWidth", 760)
  readonly property int pickerHeight: opt("pickerHeight", 540)
  readonly property var pickerDims: pickerSize === "custom" ? [pickerWidth, pickerHeight]
                                   : (pickerPresets[pickerSize] ?? pickerPresets.medium)
  readonly property int childWidth: opt("childWidth", 200)
  // the look of the window (Shell Manager › Shell apps › Files)
  readonly property string density: opt("density", "normal")      // compact | normal | roomy: a row's height
  readonly property int rowHeight: ({ compact: 28, normal: 34, roomy: 40 })[density] ?? 34
  readonly property bool checkboxes: opt("checkboxes", true)      // a box to tick at a row's start
  readonly property bool rowActions: opt("rowActions", true)      // the ⋮ at a row's end: its menu
  readonly property bool folderTiles: opt("folderTiles", true)    // the list: folders as tiles above the files
  readonly property bool showSize: opt("showSize", true)
  readonly property bool showDate: opt("showDate", true)
  readonly property bool showKind: opt("showKind", false)
  readonly property bool folderCounts: opt("folderCounts", true)  // a folder's size column: its items
  readonly property bool extensions: opt("extensions", true)      // off: names without their extension
  readonly property string pathBar: opt("pathBar", "crumbs")      // crumbs | field
  readonly property bool showDevices: opt("showDevices", true)
  readonly property string gridSize: opt("gridSize", "medium")    // small | medium | large
  readonly property int recentLimit: opt("recentLimit", 50)
  readonly property bool typeAhead: opt("typeAhead", true)        // typing a name jumps to it
  readonly property var starred: opt("starred", [])               // paths

  function setOption(key, value) { ModuleSettings.set("files", key, value); }

  // the window is up: devices are polled
  property bool active: false

  // ---- where ----
  property string path: ""
  property var history: []
  property int historyIndex: -1
  readonly property bool inTrash: path === trashPath
  readonly property bool atComputer: path === computerPath
  readonly property bool canBack: historyIndex > 0
  readonly property bool canForward: historyIndex < history.length - 1
  readonly property bool atRecent: path === recentPath
  readonly property bool atStarred: path === starredPath
  // a place that is not a folder: nothing is made or pasted in it, there is no folder above
  readonly property bool virtual: path.endsWith(":")
  readonly property bool writable: path !== "" && !virtual
  readonly property bool canUp: path !== "" && !virtual && path !== "/"
  readonly property string title: atComputer ? "This computer" : inTrash ? "Trash" : atRecent ? "Recent" : atStarred ? "Starred"
                                : path === "/" ? "Root" : path.split("/").pop()

  // Settings › Behaviour › Open at: the last folder (remembered), or a folder fixed in the settings
  readonly property string startMode: opt("startMode", "last")          // last | fixed
  readonly property string startPath: opt("startPath", home)
  readonly property string lastPath: opt("lastPath", "")
  function startFolder() {
    const fixed = startMode === "fixed" ? startPath : lastPath;
    const where = fixed !== "" ? fixed.replace(/^~(?=\/|$)/, home) : home;
    return where;
  }

  // the window comes up: a folder already shown is read at once (its cached rows show until then)
  function open() { if (path === "") go(startFolder()); else refresh(); }

  function go(where) {
    if (where === "" || where === path) return;
    history = history.slice(0, historyIndex + 1).concat([where]);
    show(history.length - 1);
  }

  function back() { if (canBack) show(historyIndex - 1); }
  function forward() { if (canForward) show(historyIndex + 1); }
  function up() { if (canUp) go(parentOf(path)); }

  // the history's entry at index becomes the folder shown
  function show(index) {
    historyIndex = index;
    path = history[index];
    // the last folder browsed is the one opened next time (not the trash, not a picker's folder)
    if (!virtual && !picker) setOption("lastPath", path);
    query = "";
    everywhere = false;
    dupes = false;
    selection = [];
    anchor = "";
    // the folder's last listing is shown at once (never another folder's rows); the new one replaces it
    loading = !(path in listing);
    entries = listing[path] ?? [];
    refresh();
  }

  function parentOf(p) {
    const trimmed = p.replace(/\/+$/, "");
    const i = trimmed.lastIndexOf("/");
    return i < 0 ? "" : i === 0 ? "/" : trimmed.slice(0, i);
  }

  // ---- listing ----
  property var entries: []           // the folder (or the trash), as the backend reads it
  readonly property int pollMs: 1000 // the shown folder is read again this often: new and gone files show at once
  property var listing: ({})         // the last reading of each folder, by path: shown again at once
  property bool loading: false       // a folder never read yet: nothing is shown until it is
  property var results: []           // a search in the folder
  property string error: ""
  property string query: ""          // a filter of the folder (Ctrl + F), or the search everywhere's text
  property bool everywhere: false    // Ctrl + K: the search reads Home, recursively
  // typing searches the folder shown and everything below it; Ctrl + K searches all of Home
  readonly property bool searching: (query.trim() !== "" && !virtual) || dupes
  property bool dupes: false          // the duplicates of a folder, in the list
  property int dupGroups: 0
  property string dupKey: ""
  function findDuplicates(folder) {
    dupes = true;
    query = "";
    results = [];
    dupKey = folder;
    run(dupProc, ["duplicates", folder], folder);
  }
  function leaveDupes() { dupes = false; results = []; }

  // the groups of the duplicates list: a header row each (its count and size), then the files unless folded
  property var collapsed: []
  function isCollapsed(g) { return collapsed.includes(g); }
  function toggleGroup(g) { collapsed = collapsed.includes(g) ? collapsed.filter(x => x !== g) : collapsed.concat([g]); }
  function groupRows(list) {
    const count = {};
    list.forEach(e => { count[e.group] = (count[e.group] || 0) + 1; });
    const out = [];
    let current = -1;
    for (const e of list) {
      if (e.group !== current) {
        current = e.group;
        out.push({ kind: "group", group: e.group, path: "group:" + e.group, name: count[e.group] + " FILES · " + Format.humanSize(e.size) + " EACH",
                   size: 0, mtime: 0, link: false });
      }
      if (!collapsed.includes(e.group)) out.push(e);
    }
    return out;
  }

  // every copy but the first of each group goes to the trash (undoable as a trash)
  function trashCopies() {
    const copies = results.filter((e, i) => results.findIndex(x => x.group === e.group) !== i).map(e => e.path);
    if (copies.length === 0) return;
    act({ done: "trashed", after: o => trashRecord(o.moved || []) }, ["trash"].concat(copies));
  }
  readonly property string searchRoot: everywhere ? home : path

  // the rows shown: the source, filtered and sorted
  readonly property var shown: arrange(searching ? results : entries)
  // a side column's rows: the same hidden-file rule, folders first, then by name
  function columnRows(list) {
    return list.filter(e => hidden || !e.name.startsWith("."))
               .sort((a, b) => (a.kind === "dir") !== (b.kind === "dir") ? (a.kind === "dir" ? -1 : 1) : a.name.localeCompare(b.name));
  }

  // the rows that are files (a duplicates group's header is a row, not a file)
  readonly property var rows: shown.filter(e => e.kind !== "group")

  function arrange(list) {
    if (dupes) return groupRows(list);    // the groups keep the order they came in
    const q = query.trim().toLowerCase();
    const rows = list.filter(e => (hidden || q !== "" || !e.name.startsWith("."))
                              && (searching || q === "" || e.name.toLowerCase().includes(q))
                              && fitsPicker(e));
    rows.sort((a, b) => {
      if (groupBy === "type" && kindRank(a.kind) !== kindRank(b.kind)) return kindRank(a.kind) - kindRank(b.kind);
      if (foldersFirst && (a.kind === "dir") !== (b.kind === "dir")) return a.kind === "dir" ? -1 : 1;
      if (inTrash) return (b.deleted ?? "").localeCompare(a.deleted ?? "") || a.name.localeCompare(b.name);
      if (atRecent) return (b.visited ?? "").localeCompare(a.visited ?? "");
      const c = sortBy === "size" ? a.size - b.size
              : sortBy === "mtime" ? a.mtime - b.mtime
              : a.name.localeCompare(b.name);
      return (sortDesc ? -c : c) || a.name.localeCompare(b.name);
    });
    return rows;
  }

  readonly property var kindOrder: ["dir", "image", "video", "audio", "text", "archive", "file"]
  function kindRank(kind) { const i = kindOrder.indexOf(kind); return i < 0 ? kindOrder.length : i; }

  // a picker shows folders for going on, and the files its filter allows; a save shows every
  // file (what is there already, a name to take or not to overwrite)
  function fitsPicker(e) {
    if (!picker || e.kind === "dir" || picker.mode === "save") return true;
    if (picker.directory) return false;
    return picker.filter.length === 0 || picker.filter.some(p => matchPattern(e, p));
  }

  // a glob ("*.png") against the name, or a mime type ("image/*") against the kind
  function matchPattern(e, p) {
    if (p.includes("/")) {
      const major = p.split("/")[0];
      const kinds = ["image", "video", "audio", "text"];
      return !kinds.includes(major) || e.kind === major;     // "*/*", "application/*": every file
    }
    return new RegExp("^" + globToRegex(p) + "$", "i").test(e.name);
  }

  // a glob as a regex body: * ? and classes ("*.[jJ][pP][gG]", what Chromium sends; [!x] negates)
  function globToRegex(p) {
    let re = "";
    for (let i = 0; i < p.length; i++) {
      const c = p[i];
      const close = c === "[" ? p.indexOf("]", i + 2) : -1;
      if (c === "*") re += ".*";
      else if (c === "?") re += ".";
      else if (close > 0) {
        const body = p.slice(i + 1, close).replace(/\\/g, "\\\\");
        re += "[" + (body[0] === "!" ? "^" + body.slice(1) : body) + "]";
        i = close;
      } else re += c.replace(/[.+^${}()|[\]\\]/g, "\\$&");
    }
    return re;
  }

  // a column caption or the header's button: the same key flips the order, a new key starts ascending
  function sortOn(key) {
    if (sortBy === key) setOption("sortDesc", !sortDesc);
    else { setOption("sortBy", key); setOption("sortDesc", false); }
  }

  // Ctrl + G and the header: list, grid, columns, and round again
  readonly property var viewKeys: ["list", "grid", "columns"]
  // the view button: a folder cycles list, grid, columns; This computer only list and grid, its own
  function cycleView() {
    if (atComputer) { setOption("computerView", computerView === "grid" ? "list" : "grid"); return; }
    setOption("view", viewKeys[(viewKeys.indexOf(view) + 1) % viewKeys.length]);
  }

  // This computer sorts its storage by name or size, on its own setting
  readonly property string computerSort: opt("computerSort", "name")        // name | size
  readonly property string sortLabel: atComputer
      ? ({ name: "Name", size: "Size" })[computerSort]
      : ({ name: "Name", size: "Size", mtime: "Modified" })[sortBy]

  function sortNext() {
    if (atComputer) { setOption("computerSort", computerSort === "name" ? "size" : "name"); return; }
    sortOn(sortKeys[(sortKeys.indexOf(sortBy) + 1) % sortKeys.length]);
  }

  function refresh() {
    if (dupes) { run(dupProc, ["duplicates", dupKey], dupKey); return; }
    if (atComputer) { refreshVolumes(); return; }
    if (inTrash) run(listProc, ["trash-list"], path);
    else if (atRecent) run(listProc, ["recent", String(recentLimit)], path);
    else if (atStarred) {
      if (starred.length > 0) run(listProc, ["entries"].concat(starred), path);
      else { entries = []; loading = false; }
    }
    else run(listProc, ["list", path].concat(folderCounts ? ["counts"] : []), path);
    if (searching) searchTimer.restart();
  }

  // typing in the search field; the folder is searched once the typing pauses
  function setQuery(text) {
    query = text;
    if (text.trim() === "") results = [];
    searchTimer.restart();
  }

  // Ctrl + K: the search reads all of Home, and back to the folder shown; the text is kept
  function toggleEverywhere() {
    everywhere = !everywhere;
    results = [];
    searchTimer.restart();
  }

  function searchKey() { return searchRoot + "|" + query.trim(); }

  Timer {
    id: searchTimer
    interval: 250
    onTriggered: {
      if (root.searching) run(searchProc, ["search", root.searchRoot, root.query.trim(), String(root.searchLimit), String(root.searchSeconds)], root.searchKey());
      else root.results = [];
    }
  }

  // ---- selection ----
  property alias selection: selectionState.selection
  property alias anchor: selectionState.anchor
  readonly property var selected: {
    const picked = new Set(selection);
    return rows.filter(e => picked.has(e.path));
  }

  FilesSelection {
    id: selectionState
    rows: root.rows
    single: root.picker !== null && !root.picker.multiple
  }

  // Public API used by every view; the selection model owns the behaviour.
  function select(p, mode) { selectionState.select(p, mode); }
  function selectAll() { selectionState.selectAll(); }
  property int columns: 1
  function step(delta, extend) { selectionState.step(delta, extend); }

  onSelectionChanged: updatePreview()

  // ---- preview: the first lines of a text file, the picture is shown from its path ----
  property string previewText: ""
  property string thumbPath: ""      // a video's frame or a PDF's first page, once made
  property string thumbError: ""     // why there is none (a tool to install, mostly)
  readonly property string previewPath: selected.length === 1 ? selected[0].path : ""
  function updatePreview() {
    previewText = "";
    thumbPath = "";
    thumbError = "";
    if (!showPreview || selected.length !== 1) return;
    const kind = selected[0].kind;
    if (kind === "text") run(previewProc, ["preview", selected[0].path, String(previewLines)], selected[0].path);
    else if (kind === "video" || kind === "pdf") run(thumbProc, ["thumb", selected[0].path, "480"], selected[0].path);
  }

  // ---- cut, copy, paste: the files kept until pasted (cut) or until replaced ----
  property var clip: []
  property string clipMode: ""       // copy | move
  readonly property bool canPaste: clip.length > 0 && writable

  function copySelection() { if (selection.length) { clip = selection.slice(); clipMode = "copy"; toSystemClipboard(clip); } }
  function cutSelection() { if (selection.length) { clip = selection.slice(); clipMode = "move"; toSystemClipboard(clip); } }

  // ---- paths, URIs and the shell: a file URI encodes each segment; a URI from another program is read
  // with care; a path given to sh is single-quoted (an apostrophe closes, escapes and reopens the quote)
  function fileUri(p) { return "file://" + p.split("/").map(encodeURIComponent).join("/"); }
  function pathFromUri(u) {
    const s = String(u).trim();
    if (!s.startsWith("file://")) return "";
    let rest = s.slice("file://".length);
    if (rest.startsWith("localhost/")) rest = rest.slice("localhost".length);
    if (!rest.startsWith("/")) return "";                 // a remote host: not a local file
    try { return decodeURIComponent(rest); } catch (e) { return ""; }
  }
  function validName(n) { return n !== "" && n !== "." && n !== ".." && !n.includes("/"); }
  function shq(p) { return "'" + p.replace(/'/g, "'\\''") + "'"; }

  // the paths on the Wayland clipboard as a uri list: other apps paste them as files
  function toSystemClipboard(paths) {
    Quickshell.execDetached(["wl-copy", "--type", "text/uri-list", paths.map(fileUri).join("\n")]);
  }

  // ctrl + v with nothing cut or copied here: the files on the system clipboard are copied in
  function pasteFromSystem() {
    if (!writable || externalPaste.running) return;
    externalPaste.running = true;
  }

  // a folder in the terminal (Settings › Behaviour); the path is quoted for sh
  function openTerminal(folder) {
    Quickshell.execDetached(["sh", "-c", terminal + " " + shq(folder)]);
  }

  function paste() {
    if (!canPaste) return;
    const mode = clipMode, dest = path, srcs = clip.slice();
    act({ done: mode === "move" ? "moved" : "pasted", after: o => pasteRecord(mode, dest, srcs, o.made || []) },
        ["paste", mode, dest].concat(srcs));
  }

  // a copy is undone by trashing the copies; a move by moving them back to where they came from
  function pasteRecord(mode, dest, srcs, made) {
    if (made.length === 0) return;
    const e = { label: mode, made: made };
    if (mode === "copy") {
      e.undo = () => act({ done: "undone" }, ["trash"].concat(e.made));
      e.redo = () => act({ done: "redone", after: o => { e.made = o.made || []; } }, ["paste", "copy", dest].concat(srcs));
    } else {
      const back = parentOf(srcs[0]);
      if (!srcs.every(s => parentOf(s) === back)) return;       // from more than one folder: not undone
      e.undo = () => act({ done: "undone" }, ["paste", "move", back].concat(e.made));
      e.redo = () => act({ done: "redone", after: o => { e.made = o.made || []; } }, ["paste", "move", dest].concat(srcs));
    }
    record(e);
  }

  // ---- undo and redo: the reversible operations, newest last ----
  readonly property var undos: operationHistory.undos
  readonly property var redos: operationHistory.redos
  readonly property bool canUndo: operationHistory.canUndo
  readonly property bool canRedo: operationHistory.canRedo
  FilesHistory { id: operationHistory; busy: actionProc.busy }
  function record(entry) { operationHistory.record(entry); }
  function undo() { operationHistory.undo(); }
  function redo() { operationHistory.redo(); }

  // ---- properties: the panel of a path (scripts/files.py stat) or of a device ----
  // panel: {title, subtitle, rows: [{label, value}]}; null when closed
  property var panel: null
  property string infoPath: ""
  function inspect(p) { panel = null; infoPath = p; run(statProc, ["stat", p], p); }
  function closeInfo() { panel = null; infoPath = ""; }

  function fileRows(i) {
    return [
      { label: "Location", value: parentOf(i.path) || "/" },
      { label: "Size", value: i.kind === "dir" ? (i.items ?? 0) + " items" : Format.humanSize(i.size) },
      { label: "Modified", value: Qt.formatDateTime(new Date(i.mtime * 1000), "dd.MM.yyyy HH:mm") },
      { label: "Type", value: i.mime || i.kind },
      { label: "Owner", value: i.owner + " : " + i.group },
      { label: "Permissions", value: i.mode },
    ].concat(i.link ? [{ label: "Link to", value: i.link }] : []);
  }

  function deviceProperties(d) {
    const rows = [
      { label: "Device", value: d.path },
      { label: "Filesystem", value: d.fstype || "" },
      { label: "Size", value: d.size || "" },
      { label: "Mounted", value: d.mount || "no" },
    ];
    if (d.mount) rows.push({ label: "Free", value: Format.humanSize(d.free) + " of " + Format.humanSize(d.total) });
    panel = { title: d.name, subtitle: "DEVICE", rows: rows };
  }

  // ---- reveal: a path (from another app, or the IPC): its folder is shown, the path selected ----
  property string pendingReveal: ""
  function reveal(p) {
    if (p === "") return;
    run(revealProc, ["stat", p], p);
  }

  // ---- batch rename: the selection named by a pattern ({n} the number, {name} the stem, {ext} with its dot) ----
  function batchRename(pattern) {
    const paths = selected.map(e => e.path);
    const pad = String(paths.length).length;
    const pairs = paths.map((p, i) => {
      const old = p.split("/").pop();
      const dot = old.lastIndexOf(".");
      const stem = dot > 0 ? old.slice(0, dot) : old;
      const ext = dot > 0 ? old.slice(dot) : "";
      const n = String(i + 1).padStart(pad, "0");
      return [p, pattern.split("{n}").join(n).split("{name}").join(stem).split("{ext}").join(ext).trim()];
    });
    const names = pairs.map(x => x[1]);
    if (names.some(n => n === "" || n.includes("/") || n === "." || n === "..") || new Set(names).size !== names.length) {
      error = "the names are empty, repeated or hold a /";
      return;
    }
    act({ done: "renamed", after: () => batchRecord(pairs) }, ["rename-all", JSON.stringify(pairs)]);
  }

  // undo renames each back to its old name, redo renames them all again
  function batchRecord(pairs) {
    const back = pairs.map(([from, to]) => [parentOf(from) + "/" + to, from.split("/").pop()]);
    const forward = pairs;
    record({
      label: "rename",
      undo: () => act({ done: "undone" }, ["rename-all", JSON.stringify(back)]),
      redo: () => act({ done: "redone" }, ["rename-all", JSON.stringify(forward)]),
    });
  }

  // ---- actions ----
  // `done` names the action; the backend's reply gives the path left selected (a new or renamed file)

  function createFolder(name) { createNew("mkdir", path + "/" + name.trim()); }
  function createFile(name) { createNew("touch", path + "/" + name.trim()); }

  // a new folder or file: undo trashes it, redo makes it again
  function createNew(verb, target) {
    act({ done: "created", after: () => record({
      label: verb,
      undo: () => act({ done: "undone" }, ["trash", target]),
      redo: () => act({ done: "redone" }, [verb, target]),
    }) }, [verb, target]);
  }

  function rename(p, name) {
    const to = parentOf(p) + "/" + name.trim();
    const from = p.split("/").pop();
    act({ done: "renamed", after: () => record(renameEntry(p, to, from)) }, ["rename", p, name.trim()]);
  }

  function renameEntry(from, to, oldName) {
    return {
      label: "rename",
      undo: () => act({ done: "undone" }, ["rename", to, oldName]),
      redo: () => act({ done: "redone" }, ["rename", from, to.split("/").pop()]),
    };
  }

  function trashSelection() {
    if (!selection.length) return;
    act({ done: "trashed", after: o => trashRecord(o.moved || []) }, ["trash"].concat(selection));
  }

  // undo restores what was trashed by its id; redo trashes it again and learns the new ids
  function trashRecord(moved) {
    const ids = moved.filter(m => m.id);
    if (ids.length === 0) return;
    const e = { label: "trash", moved: ids };
    e.undo = () => act({ done: "undone" }, ["restore"].concat(e.moved.map(m => m.id)));
    e.redo = () => act({ done: "redone", after: o => { e.moved = (o.moved || []).filter(m => m.id); } },
                       ["trash"].concat(e.moved.map(m => m.from)));
    record(e);
  }
  function deleteSelection() {
    if (!selection.length) return;
    if (inTrash) act({ done: "deleted" }, ["purge"].concat(ids()));
    else act({ done: "deleted" }, ["delete"].concat(selection));
  }
  function restoreSelection() { if (inTrash && selection.length) act({ done: "restored" }, ["restore"].concat(ids())); }
  function emptyTrash() { if (inTrash) act({ done: "emptied" }, ["empty-trash"]); }

  // the trash entries' ids: the file names in the trash
  function ids() { return selection.map(p => p.split("/").pop()); }

  // the backend runs the action; the folder is read again after its reply
  function act(asked, args) {
    actionProc.submit(asked, args);
  }

  function openExternal(p) { Quickshell.execDetached(["xdg-open", p]); }

  // ---- custom actions: a command of the user's, run by sh with the selected paths quoted in for %f ----
  function addAction(label, command) {
    if (label.trim() === "" || command.trim() === "") return;
    setOption("actions", actions.concat([{ label: label.trim(), command: command.trim() }]));
  }
  function removeAction(i) { setOption("actions", actions.filter((a, j) => j !== i)); }
  function runAction(a, paths) {
    Quickshell.execDetached(["sh", "-c", a.command.split("%f").join(paths.map(shq).join(" "))]);
  }

  // ---- the sidebar: one ordered list of its items (This computer, the places, the trash, folders pinned) ----
  // Stored as "sidebar" (modules.json): [{path, name, kind, hidden}]. A default that is not stored yet
  // comes first in its default order, so a new place shows up; [] is the defaults.
  function defaultEntries() {
    return [{ name: "This computer", path: computerPath, kind: "computer" },
            { name: "Recent", path: recentPath, kind: "recent" },
            { name: "Starred", path: starredPath, kind: "starred" }]
      .concat(places.map(p => ({ name: p.name, path: p.path, kind: "place" })))
      .concat([{ name: "Trash", path: trashPath, kind: "trash" }]);
  }
  readonly property var sidebarItems: {
    const known = sidebarStored.map(i => i.path);
    const missing = defaultEntries().filter(d => !known.includes(d.path)).map(d => Object.assign({ hidden: false }, d));
    return missing.concat(sidebarStored);
  }
  function setSidebar(list) {
    setOption("sidebar", list.map(i => ({ path: i.path, name: i.name, kind: i.kind, hidden: i.hidden === true })));
  }
  function moveSidebar(from, to) {
    const list = sidebarItems.slice();
    list.splice(to, 0, list.splice(from, 1)[0]);
    setSidebar(list);
  }
  function setHidden(p, hidden) {
    setSidebar(sidebarItems.map(i => i.path === p ? Object.assign({}, i, { hidden: hidden }) : i));
  }
  function isPinned(p) { return sidebarItems.some(i => i.path === p && !i.hidden); }
  // a folder joins the sidebar at its end (a default that was hidden comes back)
  function pin(p) {
    if (isPinned(p)) return;
    if (sidebarItems.some(i => i.path === p)) { setHidden(p, false); return; }
    setSidebar(sidebarItems.concat([{ path: p, name: p === "/" ? "Root" : p.split("/").pop(), kind: "folder", hidden: false }]));
  }
  // a folder is removed; a default is only hidden (Settings › SIDEBAR brings it back)
  function unpin(p) {
    const item = sidebarItems.find(i => i.path === p);
    if (item && item.kind === "folder") setSidebar(sidebarItems.filter(i => i.path !== p));
    else setHidden(p, true);
  }
  function restoreSidebar() { setSidebar([]); }

  // ---- starred: files and folders kept in the sidebar's Starred ----
  function isStarred(p) { return starred.includes(p); }
  function toggleStar(paths) {
    const all = paths.every(p => starred.includes(p));
    setOption("starred", all ? starred.filter(p => !paths.includes(p)) : starred.concat(paths.filter(p => !starred.includes(p))));
    if (atStarred) refresh();
  }

  // a name as the list shows it: without its extension when Settings › Names say so
  function shownName(e) {
    if (extensions || e.kind === "dir") return e.name;
    const i = e.name.lastIndexOf(".");
    return i > 0 ? e.name.slice(0, i) : e.name;
  }



  // ---- places (the backend's: Home, the user folders, Root) and devices (udisks2) ----
  property var places: []
  property var devices: []
  function refreshDevices() { run(devicesProc, ["devices"], ""); }
  // This computer: the storage, mounted or not (scripts/files.py volumes)
  property var volumes: []
  function refreshVolumes() { run(volumesProc, ["volumes"], ""); }
  function mountDevice(d, goThere) { run(mountProc, ["mount", d.path], { open: goThere, mount: "" }); }
  function unmountDevice(d) { run(mountProc, ["unmount", d.path], { open: false, mount: d.mount }); }

  // udisks2 says what changed (a drive plugged, mounted, unmounted): devices and the computer page are read
  // again, at once, and at each window opening; no fast poll
  Timer {
    id: udisksDebounce
    interval: 400
    onTriggered: { root.refreshDevices(); root.refreshVolumes(); }
  }
  Process {
    id: udisksMonitor
    command: ["udisksctl", "monitor"]
    running: root.active
    stdout: SplitParser { onRead: udisksDebounce.restart() }
  }
  onActiveChanged: if (active) { refreshDevices(); refreshVolumes(); }

  // the folder shown is read again while it is open (a search has its own reading)
  Timer {
    id: watchTimer
    interval: root.pollMs
    repeat: true
    running: root.active && root.path !== "" && !root.searching && !root.atComputer
    onTriggered: root.refresh()
  }

  // ---- the picker: asked for by the file-chooser portal, or by a setting of the shell ----
  // {id, mode: open|save, title, multiple, directory, filter: [patterns], folder, name, onPick}
  // id is the portal's request ("" for the shell's own); onPick(path) is the shell's answer ("" when cancelled)
  property var picker: null
  signal pickerDone()
  // a request for a picker (the portal, or a setting of the shell): the picker's window takes it
  // up with its own state, `begin(request, onPick)`
  signal pickAsked(var request, var onPick)

  // the shell's IPC: the portal's request as JSON
  function choose(json) {
    const r = parse(json);
    if (!r.id) return;
    pickAsked({
      // the title comes from another program: plain text, a short one
      id: r.id, mode: r.mode, title: String(r.title || "").replace(/<[^>]*>/g, "").slice(0, 80)
                                      || (r.mode === "save" ? "Save File" : r.directory ? "Select Folder" : "Open File"),
      multiple: !!r.multiple, directory: !!r.directory,
      filter: r.filters && r.filters.length > 0 ? r.filters[0].patterns : [],
      folder: r.folder, name: r.name || ""
    }, null);
  }

  // a folder (or a file, of the filter's patterns) for a setting of the shell ("Choose…"): the window
  // shows the picker and onPick gets the path
  function pick(title, start, directory, filter, onPick) {
    pickAsked({ id: "", mode: "open", title: title, multiple: false, directory: directory, filter: filter, folder: start || home, name: "" }, onPick);
  }
  function pickFiles(title, start, onPick) {
    pickAsked({ id: "", mode: "open", title: title, multiple: true, withMetadata: true, directory: false, filter: [], folder: start || home, name: "" }, onPick);
  }
  function pickFolder(title, start, onPick) { pick(title, start, true, [], onPick); }

  function begin(request, onPick) {
    if (picker) finishPick([], 1);
    request.onPick = onPick;
    picker = request;
    selection = [];
    anchor = "";
    if (request.folder === path) refresh();
    else go(request.folder);
  }

  // the answer goes to the portal (or to the shell's caller); the window gives way to what it was showing
  function finishPick(paths, response) {
    if (!picker) return;
    const asked = picker;
    if (asked.onPick) {
      let picked = response === 0 ? (asked.multiple ? paths : paths[0] || "") : asked.multiple ? [] : "";
      if (response === 0 && asked.multiple && asked.withMetadata) {
        picked = paths.map(path => {
          const entry = root.shown.find(item => item.path === path);
          return { path: path, size: entry && typeof entry.size === "number" ? entry.size : 0 };
        });
      }
      asked.onPick(picked);
    }
    else answerProc.submit({ done: "answered" }, ["answer", asked.id, JSON.stringify({ response: response, paths: paths })]);
    picker = null;
    pickerDone();
  }

  // one process per kind: a request while it runs waits for it, the latest wins
  function run(proc, args, asked) {
    if (proc.running) { proc.next = { args: args, asked: asked }; return; }
    proc.asked = asked;
    proc.next = null;
    proc.command = ["python3", script].concat(args);
    proc.running = true;
  }

  function resume(proc) {
    if (!proc.running && proc.next) root.run(proc, proc.next.args, proc.next.asked);
  }

  function parse(text) {
    return Reply.parse(text, "files.py");
  }

  Component.onCompleted: run(placesProc, ["places"], "")

  Process {
    id: placesProc
    property var next: null
    property var asked: null
    onRunningChanged: root.resume(placesProc)
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        if (o.ok) root.places = o.places;
        else root.error = o.error;
      }
    }
  }

  // a reply for a folder left behind (the user went on) is dropped
  Process {
    id: listProc
    property var next: null
    property var asked: null
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) started = false;
      else if (listProc.asked === root.path) {
        root.loading = false;
        root.error = "could not start folder listing";
      }
      root.resume(listProc);
    }
    stdout: StdioCollector {
      onStreamFinished: {
        if (listProc.asked !== root.path) return;
        const o = root.parse(text);
        root.loading = false;
        if (!o.ok) { root.error = o.error; return; }
        root.error = "";
        root.listing[listProc.asked] = o.entries;
        // a poll that finds the same folder changes nothing: the rows keep their hover and selection
        if (root.pendingReveal === "" && JSON.stringify(o.entries) === JSON.stringify(root.entries)) return;
        root.entries = o.entries;
        if (root.pendingReveal !== "" && o.entries.some(e => e.path === root.pendingReveal)) {
          root.selection = [root.pendingReveal];
          root.anchor = root.pendingReveal;
          root.pendingReveal = "";
        }
        root.selection = root.selection.filter(p => o.entries.some(e => e.path === p));
      }
    }
  }

  Process {
    id: searchProc
    property var next: null
    property var asked: null
    onRunningChanged: root.resume(searchProc)
    stdout: StdioCollector {
      onStreamFinished: {
        if (searchProc.asked !== root.searchKey()) return;
        const o = root.parse(text);
        if (!o.ok) { root.error = o.error; return; }
        root.results = o.entries;
      }
    }
  }

  Process {
    id: previewProc
    property var next: null
    property var asked: null
    onRunningChanged: root.resume(previewProc)
    stdout: StdioCollector {
      onStreamFinished: {
        if (previewProc.asked !== root.previewPath) return;
        const o = root.parse(text);
        root.previewText = o.ok ? o.text : "";
      }
    }
  }

  Process {
    id: thumbProc
    property var next: null
    property var asked: null
    onRunningChanged: root.resume(thumbProc)
    stdout: StdioCollector {
      onStreamFinished: {
        if (thumbProc.asked !== root.previewPath) return;
        const o = root.parse(text);
        if (o.ok) root.thumbPath = root.fileUri(o.path);
        else root.thumbError = o.error;
      }
    }
  }

  Process {
    id: devicesProc
    property var next: null
    property var asked: null
    onRunningChanged: root.resume(devicesProc)
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        if (o.ok) root.devices = o.devices;
      }
    }
  }

  Process {
    id: volumesProc
    property var next: null
    property var asked: null
    onRunningChanged: root.resume(volumesProc)
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        if (o.ok) root.volumes = o.volumes;
      }
    }
  }

  Process {
    id: mountProc
    property var next: null
    property var asked: null
    onRunningChanged: root.resume(mountProc)
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        root.error = o.ok ? "" : o.error;
        if (o.ok && mountProc.asked.open && o.mount) root.go(o.mount);
        const mount = mountProc.asked.mount;
        if (o.ok && mount && (root.path === mount || root.path.startsWith(mount.replace(/\/+$/, "") + "/"))) root.go(root.home);
        root.refreshDevices();
        root.refreshVolumes();
      }
    }
  }

  Process {
    id: statProc
    property var next: null
    property var asked: null
    onRunningChanged: root.resume(statProc)
    stdout: StdioCollector {
      onStreamFinished: {
        if (statProc.asked !== root.infoPath) return;
        const o = root.parse(text);
        if (o.ok) root.panel = { title: o.info.name, subtitle: o.info.kind.toUpperCase(), rows: root.fileRows(o.info) };
        else root.error = o.error;
      }
    }
  }

  // a folder is opened; a file's folder is opened with the file selected
  Process {
    id: revealProc
    property var next: null
    property var asked: null
    onRunningChanged: root.resume(revealProc)
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        if (!o.ok) { root.error = o.error; return; }
        if (o.info.kind === "dir") { root.go(revealProc.asked); return; }
        root.pendingReveal = revealProc.asked;
        const folder = root.parentOf(revealProc.asked);
        if (folder === root.path) root.refresh();
        else root.go(folder);
      }
    }
  }


  // an action runs as one process: progress lines while it works (the job), the reply last
  readonly property var job: actionProc.job
  readonly property bool cancelling: actionProc.cancelling
  function cancelJob() { actionProc.cancel(); }

  function finishAction(o, asked, cancelled) {
    const success = !cancelled && o.ok && !(o.errors || []).length;
    if (cancelled) {
      error = "cancelled: the items done before are done";
    } else {
      const errors = o.errors || [];
      if (!o.ok || errors.length > 0) {
        error = o.error ?? errors.join("; ");
      } else {
        error = "";
        if (asked.done === "moved") clip = [];
        if (o.path) selection = [o.path];
        if (asked.after) asked.after(o);
      }
    }
    if (asked.done === "undone" || asked.done === "redone") operationHistory.complete(success);
    refresh();
  }

  FilesActions {
    id: actionProc
    script: root.script
    onFinished: (result, request, cancelled) => root.finishAction(result, request, cancelled)
  }

  // the duplicates of a folder: the search's list, in groups
  Process {
    id: dupProc
    property var next: null
    property var asked: null
    onRunningChanged: root.resume(dupProc)
    stdout: StdioCollector {
      onStreamFinished: {
        if (dupProc.asked !== root.dupKey) return;
        const o = root.parse(text);
        if (!o.ok) { root.error = o.error; return; }
        root.results = o.entries;
        root.dupGroups = o.groups;
      }
    }
  }

  // the files on the system clipboard (wl-paste): copied into the folder shown
  Process {
    id: externalPaste
    command: ["wl-paste", "--no-newline", "--type", "text/uri-list"]
    stdout: StdioCollector {
      onStreamFinished: {
        const paths = text.split("\n").map(l => root.pathFromUri(l)).filter(p => p !== "");
        if (paths.length > 0) act({ done: "pasted" }, ["paste", "copy", root.path].concat(paths));
      }
    }
  }

  FilesActions {
    id: answerProc
    script: root.script
    onFinished: result => { if (!result.ok) root.error = result.error; }
  }

  // the portal's backend: started with the shell, gone with it (pdeathsig)
  Process {
    id: portalProc
    command: ["setpriv", "--pdeathsig", "TERM", "python3", root.portalScript]
    running: true
    onExited: portalRestart.start()
  }

  Timer {
    id: portalRestart
    interval: 10000
    onTriggered: portalProc.running = true
  }
}
