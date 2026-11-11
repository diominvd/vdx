pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.mpd

// Internet radio on top of MpdService: stations from radio-cli's
// stations.json. The bar module and the popup read MpdService for playback and
// this service for the stations.
Singleton {
  id: root

  readonly property bool active: MpdService.source === "radio" && !MpdService.stopped

  property var stations: []                    // [{key, name, genre, about}]
  readonly property string stationKey: stations.find(s => s.name === MpdService.player.station)?.key ?? ""
  property string lastKey: ""                  // station the switch resumes
  // the one a play brings back: on air, else the last
  readonly property string resumeKey: active ? stationKey : lastKey

  // the station on air, else the one the switch resumes (its name; "" before the list is read)
  readonly property string stationName: stations.find(s => s.key === resumeKey)?.name ?? ""

  // ---- favourites: the station keys starred in the Music window (music.favoriteStations) ----
  readonly property var favorites: ModuleSettings.strings("music", "favoriteStations", [])
  readonly property var favoriteStations: stations.filter(s => favorites.includes(s.key))

  function isFavorite(key) { return favorites.includes(key); }

  function setFavorite(key, on) {
    const rest = favorites.filter(k => k !== key);
    ModuleSettings.set("music", "favoriteStations", on ? rest.concat([key]) : rest);
  }

  function popupShown() {
    MpdService.error = "";
    if (!stationsProc.running) MpdService.run(stationsProc, ["--stations"]);
  }

  function validStations(rows) {
    return Array.isArray(rows) && rows.every(s => s && typeof s.key === "string"
      && typeof s.name === "string" && typeof s.genre === "string" && typeof s.about === "string");
  }

  function acceptStations(rows) {
    if (!validStations(rows)) return false;
    stations = rows;
    return true;
  }

  function play(key) {
    lastKey = key;
    MpdService.load(key, ["--radio", key]);
  }

  // Header switch: stop, or resume the last station (the first one otherwise).
  function setActive(on) {
    if (!on) MpdService.stop();
    else play(resumeKey || stations[0]?.key || "");
  }

  onStationKeyChanged: if (stationKey !== "") lastKey = stationKey

  Component.onCompleted: MpdService.run(stationsProc, ["--stations"])

  Process {
    id: stationsProc
    property var reply: null
    property bool started: false
    onStarted: { started = true; reply = null; }
    onRunningChanged: {
      if (running) return;
      if (started) {
        started = false;
        if (!root.acceptStations(reply)) MpdService.error = "bad radio stations reply";
      } else MpdService.error = "could not start radio stations query";
    }
    stdout: StdioCollector {
      onStreamFinished: stationsProc.reply = MpdService.parseList(text)
    }
  }
}
