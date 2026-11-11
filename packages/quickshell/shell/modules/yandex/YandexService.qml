pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.mpd

// Yandex Music likes on top of MpdService: covers, library sync (yandex-music-cli)
// and likes (scripts/yandex.py). The music module, its popup and the Music app
// read MpdService for playback (and its queue) and this service for the rest.
Singleton {
  id: root

  // ---- tuning ----
  readonly property int coverSize: 64
  readonly property string script: Paths.scriptsDir + "/yandex.py"

  readonly property bool active: MpdService.source === "likes" && !MpdService.stopped

  property string cover: ""                    // file:// url of the cached cover
  property string coverRequestId: ""

  property var liked: []                       // Yandex ids of liked tracks
  property var fileIds: ({})                   // file -> Yandex id (state.json)
  readonly property string trackId: fileIds[MpdService.file] ?? ""
  readonly property bool isLiked: liked.includes(trackId)
  onTrackIdChanged: refreshCover()          // also when the library map arrives after the file
  // Yandex id -> file, for the tracks the library has downloaded (playable)
  readonly property var localIds: {
    const map = {};
    for (const file in fileIds) map[fileIds[file]] = file;
    return map;
  }

  property bool updating: false

  function popupShown() {
    MpdService.error = "";
    if (!likesProc.running) likesProc.running = true;
  }

  // the Music window refreshes the queue as it opens (see MpdService.refreshQueue)
  function setWindowOpen(on) { if (on) MpdService.refreshQueue(); }

  // the playing track's cover from Yandex Music (cached by yandex.py)
  function refreshCover() {
    cover = "";
    coverRequestId = MpdService.source === "likes" ? trackId : "";
    startCover();
  }

  function startCover() {
    if (coverRequestId === "" || MpdService.source !== "likes" || coverProc.running) return;
    coverProc.requestId = coverRequestId;
    coverProc.command = ["uv", "run", "--script", root.script, "--cover", coverProc.requestId];
    coverProc.running = true;
  }

  function validLikes(o) {
    if (o?.ok !== true || !Array.isArray(o.liked) || !o.liked.every(id => typeof id === "string")
        || !o.files || typeof o.files !== "object" || Array.isArray(o.files)) return false;
    return Object.keys(o.files).every(file => typeof file === "string" && typeof o.files[file] === "string");
  }

  function acceptLikes(o) {
    if (!validLikes(o)) { MpdService.error = typeof o?.error === "string" && o.error !== ""
      ? o.error : "bad Yandex likes reply"; return false; }
    liked = o.liked;
    fileIds = o.files;
    likedCache.liked = o.liked;
    return true;
  }

  function validFileIds(ids) {
    if (!ids || typeof ids !== "object" || Array.isArray(ids)) return false;
    return Object.keys(ids).every(id => ids[id] && typeof ids[id].file === "string");
  }

  function acceptFileIds(ids) {
    if (!validFileIds(ids)) return false;
    const map = {};
    for (const id in ids) map[ids[id].file] = id;
    fileIds = map;
    return true;
  }

  function refreshLikes() {
    if (!likesProc.running) likesProc.running = true;
  }

  // Header switch: resume the likes queue, load it, or stop.
  function setActive(on) {
    if (!on) MpdService.stop();
    else if (MpdService.source === "likes") MpdService.play();
    else MpdService.load("likes", ["--likes"]);
  }

  function runUpdate() {
    if (updating || updateProc.running) return;
    updating = true;
    MpdService.error = "";
    if (!MpdService.run(updateProc, ["--update"])) {
      MpdService.error = "could not start Yandex update";
      updating = false;
    }
  }

  function finishUpdate(o, startFailure) {
    const ok = !startFailure && o?.ok === true && typeof o.message === "string";
    if (!ok) MpdService.error = startFailure ? "could not start Yandex update"
      : typeof o?.error === "string" && o.error !== "" ? o.error : "Yandex update failed";
    else if (!rebuildProc.running) MpdService.run(rebuildProc, ["--likes-refresh"]);
    if (!likesProc.running) likesProc.running = true;
    updating = false;
  }

  // The like of track `id` (the playing one when none is given). One at a time.
  function toggleLike(id) {
    const target = id || trackId;
    if (typeof target !== "string" || target === "" || likeProc.running) return;
    const like = !liked.includes(target);
    likeProc.previousLiked = liked.slice();
    liked = like ? liked.concat(target) : liked.filter(i => i !== target);   // optimistic
    likeProc.reply = null;
    likeProc.command = ["uv", "run", "--script", root.script, like ? "--like" : "--unlike", target];
    likeProc.running = true;
  }

  function finishLike(o, startFailure) {
    if (!startFailure && o?.ok === true) return;
    liked = likeProc.previousLiked;
    MpdService.error = startFailure ? "could not start Yandex like request"
      : typeof o?.error === "string" && o.error !== "" ? o.error : "could not change the like";
  }

  Process {
    id: coverProc
    property string requestId: ""
    property var reply: null
    property bool started: false
    onStarted: { started = true; reply = null; }
    onRunningChanged: {
      if (running) return;
      if (started) {
        started = false;
        const requestId = coverProc.requestId;
        const o = reply;
        if (requestId === root.coverRequestId && requestId === root.trackId
            && MpdService.source === "likes")
          root.cover = o?.ok === true && typeof o.path === "string" && o.path !== ""
            ? "file://" + o.path : "";
      } else {
        if (coverProc.requestId === root.coverRequestId && root.coverRequestId !== "") {
          MpdService.error = "could not start cover request";
          return;
        }
      }
      if (root.coverRequestId !== coverProc.requestId) root.startCover();
    }
    stdout: StdioCollector {
      onStreamFinished: coverProc.reply = MpdService.parse(text);
    }
  }

  Process {
    id: updateProc
    property var reply: null
    property bool started: false
    onStarted: { started = true; reply = null; }
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; root.finishUpdate(reply, false); }
      else root.finishUpdate(null, true);
    }
    stdout: StdioCollector {
      onStreamFinished: updateProc.reply = MpdService.parse(text);
    }
  }

  Process {
    id: rebuildProc
    stdout: StdioCollector {
      onStreamFinished: {
        const o = MpdService.parse(text);
        if (o?.ok !== true) MpdService.error = typeof o?.error === "string" && o.error !== ""
          ? o.error : "could not refresh the queue";
        MpdService.refreshQueue();
      }
    }
  }

  // file -> id straight from yandex-music-cli's state.json: known at once and
  // without the network, so the like button shows for every library track
  FileView {
    path: Quickshell.env("HOME") + "/.config/scripts/yandex-music/state.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        const state = JSON.parse(text());
        if (state && root.validFileIds(state.ids ?? {})) root.acceptFileIds(state.ids ?? {});
      } catch (e) {}
    }
  }

  // the last known likes, so the heart is right before the network answers
  FileView {
    path: Quickshell.statePath("music-likes.json")
    printErrors: false
    onAdapterUpdated: writeAdapter()
    onLoaded: if (root.liked.length === 0 && Array.isArray(likedCache.liked)
                  && likedCache.liked.every(id => typeof id === "string")) root.liked = likedCache.liked

    JsonAdapter {
      id: likedCache
      property var liked: []
    }
  }

  Process {
    id: likesProc
    command: ["uv", "run", "--script", root.script, "--likes"]
    property var reply: null
    property bool started: false
    onStarted: { started = true; reply = null; }
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; root.acceptLikes(reply); }
      else MpdService.error = "could not start Yandex likes query";
    }
    stdout: StdioCollector {
      onStreamFinished: likesProc.reply = MpdService.parse(text);
    }
  }

  Process {
    id: likeProc
    property var previousLiked: []
    property var reply: null
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; root.finishLike(reply, false); }
      else root.finishLike(null, true);
    }
    stdout: StdioCollector {
      onStreamFinished: likeProc.reply = MpdService.parse(text);
    }
  }
}
