pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.mpd
import "../../kit/reply.js" as Reply

// Yandex Music online for the Music app: the liked tracks, search, playlists and their
// management (scripts/yandex.py). Likes, the downloaded files and the update are
// YandexService's; playback is MpdService's (a downloaded track only).
Singleton {
  id: root

  // ---- tuning ----
  readonly property string script: Paths.scriptsDir + "/yandex.py"

  property var likes: []                       // [track] every liked track, Yandex order
  property bool likesLoading: false
  property var results: []                     // [track] of the last search
  property string query: ""                    // the last searched text
  property bool searching: false
  property string sent: ""                     // the text the search in flight asked for
  property var playlists: []                   // [{kind, title, count}]
  property bool playlistsLoading: false
  property var playlist: null                  // {kind, title, count, tracks: [track]} or null
  property bool playlistLoading: false
  property string error: ""
  property string notice: ""                   // "Added to Sport": a finished action, for the status line

  // a backend's raw exception (a connection pool, a certificate) is no text for a status line
  function plain(e, fallback) {
    if (!e) return fallback;
    if (/SSL|certificate/i.test(e)) return "Yandex Music is unreachable: a secure connection could not be made";
    if (/ConnectionPool|Max retries|timed? ?out|resolve|Connection (refused|reset)/i.test(e)) return "Yandex Music is unreachable: check the connection";
    return e;
  }

  // a liked track the library has downloaded: it plays from MPD
  function playable(id) { return YandexService.localIds[id] !== undefined; }

  // Plays a downloaded track from the likes queue; the queue loads first when it is not in it.
  function play(id) {
    const file = YandexService.localIds[id];
    if (file === undefined) return;
    MpdService.load("likes", ["--likes-at", file]);
  }

  function refreshLikes() {
    if (likesLoading) return;
    likesLoading = true;
    error = "";
    run(likesProc, ["--likes-list"]);
  }

  // One search at a time; a text typed meanwhile runs when the last one answers.
  function search(text) {
    query = text.trim();
    if (query === "") { results = []; return; }
    if (!searching) runSearch();
  }

  function runSearch() {
    searching = true;
    sent = query;
    error = "";
    run(searchProc, ["--search", sent]);
  }

  function refreshPlaylists() {
    if (playlistsLoading) return;
    playlistsLoading = true;
    error = "";
    run(playlistsProc, ["--playlists"]);
  }

  function openPlaylist(p) {
    if (playlistLoading) return;
    playlist = { kind: p.kind, title: p.title, count: p.count, tracks: [] };
    playlistLoading = true;
    error = "";
    run(playlistProc, ["--playlist", p.kind]);
  }

  // ---- management ----
  // One action at a time; `done(reply)` runs when it answers (ok or not).
  function act(args, done) {
    if (actProc.running) return;
    error = "";
    notice = "";
    actProc.done = done;
    run(actProc, args);
  }

  function createPlaylist(title) {
    const t = title.trim();
    if (t === "") return;
    act(["--playlist-create", t], o => {
      if (!o?.ok) return;
      notice = "Created " + t;
      refreshPlaylists();
    });
  }

  function deletePlaylist(p) {
    act(["--playlist-delete", p.kind], o => {
      if (!o?.ok) return;
      notice = "Deleted " + p.title;
      playlist = null;
      refreshPlaylists();
    });
  }

  function addToPlaylist(p, track) {
    act(["--playlist-add", p.kind, track.id], o => {
      if (!o?.ok) return;
      notice = "Added to " + p.title;
      if (playlist?.kind === p.kind) openPlaylist(p);
      refreshPlaylists();
    });
  }

  // `index`: the track's place in the open playlist
  function removeFromPlaylist(index) {
    const p = playlist;
    if (!p) return;
    act(["--playlist-remove", p.kind, String(index)], o => {
      if (!o?.ok) return;
      notice = "Removed from " + p.title;
      openPlaylist(p);
    });
  }

  function run(proc, args) {
    proc.command = ["uv", "run", "--script", root.script].concat(args);
    proc.running = true;
  }

  function parse(text) {
    return Reply.parse(text, "yandex.py", null);
  }

  Process {
    id: likesProc
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        root.likesLoading = false;
        if (o?.ok) root.likes = o.tracks;
        else root.error = root.plain(o?.error, "could not load the likes");
      }
    }
  }

  Process {
    id: searchProc
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        root.searching = false;
        if (root.query !== root.sent) root.runSearch();
        else if (o?.ok) root.results = o.tracks;
        else root.error = root.plain(o?.error, "search failed");
      }
    }
  }

  Process {
    id: playlistsProc
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        root.playlistsLoading = false;
        if (o?.ok) root.playlists = o.playlists;
        else root.error = root.plain(o?.error, "could not load the playlists");
      }
    }
  }

  Process {
    id: playlistProc
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        root.playlistLoading = false;
        if (!root.playlist) return;
        if (o?.ok) root.playlist = Object.assign({}, root.playlist, { tracks: o.tracks });
        else root.error = root.plain(o?.error, "could not load the playlist");
      }
    }
  }

  Process {
    id: actProc
    property var done: null
    stdout: StdioCollector {
      onStreamFinished: {
        const o = root.parse(text);
        if (!o?.ok) root.error = root.plain(o?.error, "that did not work");
        if (actProc.done) actProc.done(o);
      }
    }
  }
}
