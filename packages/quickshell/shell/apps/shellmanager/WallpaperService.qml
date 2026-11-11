pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.config

// Wallpaper pictures for the Shell Manager: the repo's (~/.dotfiles/wallpapers,
// <theme>/ and common/) and the user's own (~/.local/share/dotfiles/wallpapers,
// out of the repo), the picture each theme uses (ShellSettings.wallpaperImages,
// "<theme>/f", "common/f" or "user/f"; wallpaperOutputs per monitor) and adding
// a file — copied into the user's folder.
Singleton {
  id: root

  readonly property string dir: ThemeService.dotfiles + "/wallpapers"
  readonly property string userDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share")
    + "/dotfiles/wallpapers"
  readonly property var extensions: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif"]

  // ---- state ----
  property bool busy: false
  property string error: ""

  signal added()

  function imageFor(theme) { return ShellSettings.wallpaperImages[theme] ?? ""; }
  // a kept name as a path: user/ is the user's folder, the rest the repo's
  function pathOf(rel) { return rel.startsWith("user/") ? userDir + rel.slice(4) : dir + "/" + rel; }
  // theme -> {output: picture}: the monitors whose picture differs from the theme's
  function outputsFor(theme) { return ShellSettings.wallpaperOutputs[theme] ?? ({}); }

  // the picture in use (a path under dir), "" when the image mode is off
  readonly property string inUse: ShellSettings.wallpaperMode === "image" ? imageFor(ThemeService.current) : ""

  // the pictures to pick from: the active theme's, the user's, then common/ — [{rel, name, path}],
  // rel as ShellSettings.wallpaperImages keeps it
  property var pictures: []

  function collect() {
    const list = [];
    for (let i = 0; i < ownPictures.count; i++)
      list.push({ rel: ThemeService.current + "/" + ownPictures.get(i, "fileName"),
                  name: ownPictures.get(i, "fileName"), path: ownPictures.get(i, "filePath") });
    for (let i = 0; i < userPictures.count; i++)
      list.push({ rel: "user/" + userPictures.get(i, "fileName"),
                  name: userPictures.get(i, "fileName"), path: userPictures.get(i, "filePath") });
    for (let i = 0; i < sharedPictures.count; i++)
      list.push({ rel: "common/" + sharedPictures.get(i, "fileName"),
                  name: sharedPictures.get(i, "fileName"), path: sharedPictures.get(i, "filePath") });
    pictures = list;
  }

  FolderListModel {
    id: ownPictures
    folder: "file://" + root.dir + "/" + ThemeService.current
    nameFilters: root.extensions
    showDirs: false
    onCountChanged: root.collect()
    onStatusChanged: root.collect()
  }

  FolderListModel {
    id: userPictures
    folder: "file://" + root.userDir
    nameFilters: root.extensions
    showDirs: false
    onCountChanged: root.collect()
    onStatusChanged: root.collect()
  }

  FolderListModel {
    id: sharedPictures
    folder: "file://" + root.dir + "/common"
    nameFilters: root.extensions
    showDirs: false
    onCountChanged: root.collect()
    onStatusChanged: root.collect()
  }

  // the picture the picker has picked, shown on the desktop before it is set (Wallpaper.qml);
  // "" when no preview is on. Enter sets it (choose), leaving the picker reverts it.
  property string previewRel: ""
  function preview(rel) { previewRel = rel; }
  function endPreview() { previewRel = ""; }

  // the picture `rel` for `theme` on `output` ("" or absent: every monitor,
  // which drops the theme's per-monitor ones), and pictures on
  function choose(theme, rel, output) {
    const outputs = Object.assign({}, ShellSettings.wallpaperOutputs);
    if (output) {
      outputs[theme] = Object.assign({}, outputs[theme] ?? {}, { [output]: rel });
    } else {
      const map = Object.assign({}, ShellSettings.wallpaperImages);
      map[theme] = rel;
      ShellSettings.set("wallpaperImages", map);
      delete outputs[theme];
    }
    ShellSettings.set("wallpaperOutputs", outputs);
    ShellSettings.set("wallpaperMode", "image");
  }

  // copies `path` (~ allowed) into the user's folder and picks it for `theme` (on `output`)
  property string adding: ""
  property string addingTheme: ""
  property string addingOutput: ""

  function failAdd(message) {
    adding = "";
    addingTheme = "";
    addingOutput = "";
    error = message || "could not start wallpaper copy";
    busy = false;
  }

  function add(path, theme, output) {
    const src = path.trim().replace(/^~(?=\/)/, Quickshell.env("HOME"));
    if (busy || src === "") return;
    const name = src.split("/").pop();
    if (!/\.(jpe?g|png|webp|gif)$/i.test(name)) { error = "not a picture: " + name; return; }
    busy = true;
    error = "";
    adding = "user/" + name;
    addingTheme = theme;
    addingOutput = output ?? "";
    copyProc.command = ["bash", "-c", 'mkdir -p "$2" && cp -- "$1" "$2/"', "_", src, userDir];
    copyProc.running = true;
  }

  Process {
    id: copyProc
    stderr: StdioCollector { id: copyErr }
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.failAdd("could not start wallpaper copy");
    }
    onExited: code => {
      const rel = root.adding;
      const theme = root.addingTheme;
      const output = root.addingOutput;
      root.adding = "";
      root.addingTheme = "";
      root.addingOutput = "";
      if (code === 0) {
        root.choose(theme, rel, output);
        root.error = "";
        root.busy = false;
        root.added();
      }
      else {
        root.error = copyErr.text.trim() || "copy failed";
        root.busy = false;
      }
    }
  }
}
