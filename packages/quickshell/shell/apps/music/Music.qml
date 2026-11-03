import QtQuick
import Quickshell
import Quickshell.Io
import qs.bar
import qs.config
import qs.kit
import qs.modules.mpd
import qs.modules.player
import qs.modules.radio
import qs.modules.yandex
import "../../kit/reply.js" as Reply

// The music player, tabbed by source as Files lays out: the sidebar is a pane of its
// own (the header, then the tabs Yandex Music | Files | Radio of the sources installed,
// then the tab's rows); the page has its header, a field where it filters (Yandex
// searches on Enter), its list as a table in one raised box, and the player at its foot
// (MusicPlayerBar). Playback is PlayerService's: MPD (Yandex likes, local files, radio)
// or any MPRIS player. A tab shows only while its component is installed.
Item {
  id: root

  signal closeRequested()

  readonly property int padding: Theme.windowPadding
  readonly property int sideW: 290
  readonly property bool yandexOn: BarLayout.installed("yandex")
  readonly property bool filesOn: BarLayout.installed("files")
  readonly property bool radioOn: BarLayout.installed("radio")
  readonly property bool anyOn: yandexOn || filesOn || radioOn
  readonly property var tabs: [{ label: "Yandex", value: "yandex" }, { label: "Files", value: "files" },
                               { label: "Radio", value: "radio" }].filter(t => available(t.value))

  property string tab: "yandex"        // the source shown: yandex | files | radio
  property string page: "likes"        // Yandex Music's page: likes | search | playlist
  property string playlistKind: ""
  property string folder: ""           // Files: the folder listed ("": the first of the folders)
  property string filter: ""           // the rows that match: Likes, a playlist, a folder
  property string radioPage: "all"     // Radio's page: all | favorites
  property bool deleteSure: false      // Delete playlist waits for its second press
  property bool asked: false           // a tab was asked for (go): shown() keeps it over opensOn

  readonly property bool fieldOn: tab === "yandex" || tab === "files"
  readonly property var playlistShown: yandexOn ? YandexLibrary.playlists.find(p => p.kind === playlistKind) ?? null : null
  readonly property int downloaded: yandexOn ? Object.keys(YandexService.localIds).length : 0

  // the liked tracks the library still lists (an unlike hides a row at once)
  readonly property var likes: yandexOn ? YandexLibrary.likes.filter(t => YandexService.liked.includes(t.id)) : []
  readonly property var yandexTracks: !yandexOn ? []
    : matching(page === "likes" ? likes
             : page === "search" ? YandexLibrary.results
             : page === "playlist" && YandexLibrary.playlist ? YandexLibrary.playlist.tracks : [])

  // ---- files: the folders of music.folders and the one listed (see music_files.py) ----
  readonly property string script: Paths.scriptsDir + "/music_files.py"
  readonly property var folders: ModuleSettings.get("music", "folders", ["~/Music"]).map(p => home(p))
  readonly property string dir: folder !== "" ? folder : (folders[0] ?? "")
  property var subdirs: []             // [{name, path}] of dir
  property var songs: []               // [{path, title, artist}] of dir
  property bool listing: false
  property string listError: ""
  readonly property var filesEntries: matching(subdirs.map(d => ({ dir: true, path: d.path, title: d.name, artist: "" }))
                                               .concat(songs))

  function matching(list) {
    const q = tab === "yandex" && page === "search" ? "" : filter.trim().toLowerCase();
    return q === "" ? list : list.filter(t => (t.title + " " + (t.artist ?? "") + " " + (t.album ?? "")).toLowerCase().includes(q));
  }

  // a folder's path with ~ as the home folder, and its name
  function home(path) { return path.replace(/^~(?=\/|$)/, Quickshell.env("HOME")); }
  function parentOf(path) { const i = path.lastIndexOf("/"); return i > 0 ? path.slice(0, i) : path; }

  onDirChanged: {
    subdirs = [];
    songs = [];
    refreshFiles();
  }

  // ---- opening ----
  // the window shows: its data is read, and the tab is the one music.opensOn names (last:
  // the one shown). A `go` IPC call made while it was shut may run before this (the window
  // turns visible a little later): then that tab stays.
  function shown() {
    if (yandexOn) {
      YandexService.setWindowOpen(true);
      YandexService.refreshLikes();
      YandexLibrary.refreshLikes();
      YandexLibrary.refreshPlaylists();
    }
    if (radioOn) RadioService.popupShown();
    if (!asked) {
      const opens = ModuleSettings.get("music", "opensOn", "last");
      select(opens !== "last" ? opens : tab);
    }
    asked = false;
  }

  function hidden() {
    if (yandexOn) YandexService.setWindowOpen(false);
    asked = false;
    menu.close();
  }

  function available(name) {
    if (name === "yandex") return yandexOn;
    if (name === "files") return filesOn;
    if (name === "radio") return radioOn;
    return false;
  }

  // the tabs by name: yandex, files, radio; the Yandex pages likes, search, playlist
  // (`playing`: the tab shown stays). A tab not installed falls back to the first one.
  function go(name) {
    asked = true;
    select(name);
  }

  function select(name) {
    if (name === "playing") name = tab;
    if (name === "likes" || name === "search" || name === "playlist") {
      page = name;
      name = "yandex";
    }
    if (!available(name)) name = tabs.length > 0 ? tabs[0].value : tab;
    tab = name;
    filter = "";
    deleteSure = false;
    menu.close();
    if (tab === "yandex" && page === "likes") YandexLibrary.refreshLikes();
    if (tab === "yandex" && page === "search") Qt.callLater(() => field.input.forceActiveFocus());
    if (tab === "files") refreshFiles();
  }

  function openPlaylist(p) {
    go("playlist");
    playlistKind = p.kind;
    YandexLibrary.openPlaylist(p);
  }

  // ---- files: a folder listed, entered (a click) or left (Up) ----
  function openDir(path) {
    folder = path;
    filter = "";
  }

  function refreshFiles() {
    if (dir === "" || listProc.running) return;
    listProc.asked = dir;
    listing = true;
    listError = "";
    listProc.command = ["python3", root.script, "--list", dir];
    listProc.running = true;
  }

  // Escape: the menu, then the filter, then the window
  function cancel() {
    if (menu.open) menu.close();
    else if (filter !== "" && !(tab === "yandex" && page === "search")) filter = "";
    else closeRequested();
  }

  function played() {
    if (ModuleSettings.get("music", "closeOnPlay", false)) closeRequested();
  }

  function playTrack(track) {
    YandexLibrary.play(track.id);
    played();
  }

  // the folder plays from the file on, as a folder of the Files tab does
  function playFile(entry) {
    MpdService.playFolder(dir, entry.path);
    played();
  }

  function activateFile(entry) {
    if (entry.dir) openDir(entry.path);
    else playFile(entry);
  }

  // ---- menus ----
  function trackMenu(track, index, anchor) {
    const playable = YandexLibrary.playable(track.id);
    const liked = YandexService.liked.includes(track.id);
    let items = [
      { label: playable ? "Play" : "Not downloaded yet", disabled: !playable, run: () => root.playTrack(track) },
      { label: liked ? "Remove from likes" : "Add to likes", run: () => YandexService.toggleLike(track.id) },
      { line: true },
    ];
    items = items.concat(YandexLibrary.playlists.length === 0
      ? [{ label: "No playlists yet", disabled: true, run: () => {} }]
      : YandexLibrary.playlists.map(p => ({ label: "Add to " + p.title, note: p.count + "", run: () => YandexLibrary.addToPlaylist(p, track) })));
    if (page === "playlist" && YandexLibrary.playlist)
      items = items.concat([{ line: true },
        { label: "Remove from " + YandexLibrary.playlist.title, danger: true, run: () => YandexLibrary.removeFromPlaylist(index) }]);
    menu.show(track.title, items, anchor);
  }

  function fileMenu(entry, index, anchor) {
    menu.show(entry.title, [
      { label: "Play", run: () => root.playFile(entry) },
      { label: "Play next", run: () => MpdService.addFile(entry.path, true) },
      { label: "Add to queue", run: () => MpdService.addFile(entry.path, false) },
    ], anchor);
  }

  // ---- the sidebar: its own pane, as in Files: the window's header, the tabs, the tab's rows ----
  Rectangle {
    id: sidePane
    width: root.sideW + root.padding
    height: parent.height
    color: Theme.sideFill

    // the header sits centred between the window's top and its line, which is level with the page's
    KitLine {
      id: brandLine
      x: root.padding
      y: headerLine.y
      width: parent.width - root.padding
    }

    KitHeader {
      x: root.padding
      y: (brandLine.y - height) / 2
      width: brandLine.width
      icon: "music"
      title: "Music"
      subtitle: !PlayerService.hasMedia ? "NOTHING PLAYING" : PlayerService.playing ? "PLAYING" : "PAUSED"
    }

    MusicSidebar {
      music: root
      x: root.padding
      y: brandLine.y + brandLine.height + Theme.gapGroup
      width: root.sideW - root.padding
      height: parent.height - root.padding - y
    }
  }

  // the line between the panes
  KitLine {
    anchors { left: sidePane.right; top: parent.top; bottom: parent.bottom }
    vertical: true
  }

  // ---- the page: its header, the field, the list (or the empty state), the player ----
  Item {
    id: pageArea
    anchors { left: sidePane.right; right: parent.right; top: parent.top; bottom: parent.bottom
              leftMargin: 1 + root.padding; rightMargin: root.padding }

    KitHeader {
      id: header
      visible: root.anyOn
      anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: root.padding - Theme.headerInset }
      icon: root.tab === "files" ? "folder" : root.tab === "radio" ? (root.radioPage === "favorites" ? "star" : "radio")
          : ({ likes: "heart", search: "search", playlist: "list" })[root.page]
      title: root.tab === "files" ? (root.dir === "" ? "Files" : Paths.nameOf(root.dir))
           : root.tab === "radio" ? (root.radioPage === "favorites" ? "Favourites" : "All stations")
           : root.page === "likes" ? "Likes"
           : root.page === "search" ? "Search"
           : root.playlistShown?.title ?? YandexLibrary.playlist?.title ?? "Playlists"
      subtitle: root.tab === "files" ? root.subdirs.length + " FOLDERS · " + root.songs.length + " TRACKS"
              : root.tab === "radio" ? (root.radioPage === "favorites" ? RadioService.favoriteStations.length + " FAVOURITES"
                                         : RadioService.stations.length + " STATIONS")
              : root.page === "likes" ? root.likes.length + " LIKED · " + root.downloaded + " DOWNLOADED"
              : root.page === "search" ? (YandexLibrary.query === "" ? "YANDEX MUSIC" : YandexLibrary.results.length + " FOUND")
              : YandexLibrary.playlist ? YandexLibrary.playlist.tracks.length + " TRACKS"
              : YandexLibrary.playlists.length + " PLAYLISTS"

      KitButton {
        visible: root.tab === "files" && root.dir !== "" && root.folders.indexOf(root.dir) < 0
        icon: "arrow-up"
        text: root.dir === "" ? "" : Paths.nameOf(root.parentOf(root.dir))
        onClicked: root.openDir(root.parentOf(root.dir))
      }

      KitButton {
        visible: root.tab === "yandex" && root.yandexOn
        icon: "refresh"
        text: "Update"
        busy: root.yandexOn && YandexService.updating
        disabled: root.yandexOn && YandexService.updating
        onClicked: YandexService.runUpdate()
      }

      KitButton {
        visible: root.tab === "yandex" && root.page === "playlist" && YandexLibrary.playlist !== null
        icon: "trash"
        text: root.deleteSure ? "Sure?" : "Delete"
        onClicked: {
          if (!root.deleteSure) { root.deleteSure = true; sureTimer.restart(); return; }
          root.deleteSure = false;
          if (root.playlistShown) YandexLibrary.deletePlaylist(root.playlistShown);
          root.go("likes");
        }
      }
    }

    Timer { id: sureTimer; interval: 3000; onTriggered: root.deleteSure = false }

    KitLine {
      id: headerLine
      visible: root.anyOn
      anchors { top: header.bottom; topMargin: Theme.gapGroup }
      width: parent.width
    }

    // ---- the field: Search asks Yandex on Enter, the others filter as you type ----
    KitInput {
      id: field
      visible: root.anyOn && root.fieldOn
      anchors { top: headerLine.bottom; topMargin: Theme.gapGroup }
      width: parent.width
      placeholder: root.tab === "yandex" && root.page === "search" ? "Search artist, track or album…" : "filter"
      text: root.tab === "yandex" && root.page === "search" ? YandexLibrary.query : root.filter
      onTextEdited: if (!(root.tab === "yandex" && root.page === "search")) root.filter = text
      onAccepted: if (root.tab === "yandex" && root.page === "search") YandexLibrary.search(text)
    }

    // an error in red, else what the last action did
    KitText {
      id: note
      readonly property string err: (root.tab === "yandex" ? YandexLibrary.error : "")
                                   || (root.tab === "files" ? root.listError : "") || MpdService.error
      visible: root.anyOn && text !== ""
      anchors { top: field.visible ? field.bottom : headerLine.bottom; topMargin: Theme.gapMedium }
      width: parent.width
      text: err || (root.tab === "yandex" ? YandexLibrary.notice : "")
      color: err ? Theme.red : Theme.muted
      wrapMode: Text.WordWrap
      font.pixelSize: Theme.fontSize - 1
    }

    // no source installed: the one line of the page
    KitText {
      visible: !root.anyOn
      anchors.centerIn: parent
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: "Install the mpd component to play music"
      color: Theme.muted
      wrapMode: Text.WordWrap
      font.pixelSize: Theme.fontSize - 1
    }

    // ---- body ----
    Item {
      id: body
      visible: root.anyOn
      anchors { left: parent.left; right: parent.right; bottom: bar.visible ? bar.top : parent.bottom
                top: note.visible ? note.bottom : field.visible ? field.bottom : headerLine.bottom
                topMargin: Theme.gapGroup; bottomMargin: bar.visible ? Theme.gapGroup : root.padding }

      MusicTracks {
        anchors.fill: parent
        visible: root.tab === "yandex"
        kind: "yandex"
        tracks: root.yandexTracks
        empty: !root.yandexOn ? "" : root.page === "likes" ? (YandexLibrary.likesLoading ? "Loading…" : YandexLibrary.error !== "" ? "" : root.filter !== "" ? "Nothing matches" : "No liked tracks")
             : root.page === "search" ? (YandexLibrary.searching ? "Searching…"
                 : YandexLibrary.query === "" ? "Type and press Enter to search Yandex Music"
                 : "Nothing matches “" + YandexLibrary.query + "”")
             : root.page === "playlist" && !YandexLibrary.playlist ? "Pick a playlist on the left"
             : YandexLibrary.playlistLoading ? "Loading…" : root.filter !== "" ? "Nothing matches"
             : "No tracks yet. Add some from a track's ⋮ menu"
        onActivated: track => root.playTrack(track)
        onMenu: (track, index, anchor) => root.trackMenu(track, index, anchor)
      }

      MusicTracks {
        anchors.fill: parent
        visible: root.tab === "files"
        kind: "files"
        tracks: root.filesEntries
        empty: root.dir === "" ? "No folders. Add some in Music settings"
             : root.listing ? "Loading…"
             : root.filter !== "" ? "Nothing matches" : "No music in this folder"
        onActivated: entry => root.activateFile(entry)
        onMenu: (entry, index, anchor) => root.fileMenu(entry, index, anchor)
      }

      MusicTracks {
        anchors.fill: parent
        visible: root.tab === "radio"
        kind: "radio"
        tracks: !root.radioOn ? [] : root.radioPage === "favorites" ? RadioService.favoriteStations : RadioService.stations
        empty: root.radioPage === "favorites" ? "No favourite stations yet — star one in All stations"
             : "No stations. Add them with the radio command"
        onActivated: station => { RadioService.play(station.key); root.played(); }
      }
    }

    MusicPlayerBar {
      id: bar
      visible: root.anyOn && PlayerService.hasMedia
      anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: root.padding }
      yandexOn: root.yandexOn
    }
  }

  // above the window's content: a click outside it closes it
  MusicMenu {
    id: menu
    host: root
  }

  // ---- the listing of the folder (music_files.py --list) ----
  Process {
    id: listProc
    property string asked: ""
    // a folder picked while one was listed: the next listing runs when this one ends
    onRunningChanged: {
      if (running) return;
      if (root.dir !== asked) root.refreshFiles();
      else root.listing = false;
    }
    stdout: StdioCollector {
      onStreamFinished: {
        if (listProc.asked !== root.dir) return;
        const o = Reply.parse(text, "music_files.py", null);
        root.subdirs = o?.dirs ?? [];
        root.songs = o?.tracks ?? [];
        root.listError = o?.ok === false ? (o.error ?? "could not list the folder") : "";
      }
    }
  }
}
