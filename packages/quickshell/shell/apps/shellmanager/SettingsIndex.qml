pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The search over the shell's settings: every page's rows from
// config/settings-index.json (scripts/settings_index.py, rebuilt with the
// pages). The Shell Manager's sidebar search and the launcher's Shell tab share
// it. The file is read the first time a search needs it (`load()`), not at start.
Singleton {
  id: root

  property var indexed: []
  property bool wanted: false

  function load() { wanted = true; }

  FileView {
    path: root.wanted ? Quickshell.shellDir + "/config/settings-index.json" : ""
    printErrors: false
    onLoaded: {
      let entries = [];
      try { entries = JSON.parse(text()); } catch (e) { entries = []; }
      root.indexed = entries.map(e => ({ entry: e, label: root.norm(e.label), aliases: (e.aliases ?? []).map(a => root.norm(a)),
        hint: root.words(e.hint), where: root.words(e.where) }));
    }
  }

  // letters and digits only, lower case: "wifi" finds "Wi-Fi", "dark mode" finds "Dark  mode"
  function norm(s) { return (s ?? "").toLowerCase().replace(/[^a-z0-9а-яё]+/g, ""); }
  // the words of a text, lower case: a hint matches by whole-word starts ("scan" finds "Scan files",
  // not "…ing a scan…" inside a word), so a hint or a place does not match every row near it
  function words(s) { return (s ?? "").toLowerCase().split(/[^a-z0-9а-яё]+/).filter(w => w !== ""); }
  // the rows for a typed text: a label match before an alias, a hint or a place one
  function search(raw) {
    const q = norm(raw);
    if (q === "") return [];
    const tokens = words(raw);
    const matchesWords = list => tokens.length > 0 && tokens.every(t => list.some(w => w.startsWith(t)));
    const first = indexed.filter(e => e.label.includes(q));
    const firstSet = new Set(first);
    const second = indexed.filter(e => !firstSet.has(e) && e.aliases.some(a => a.includes(q)));
    const secondSet = new Set(second);
    const then = indexed.filter(e => !firstSet.has(e) && !secondSet.has(e) && matchesWords(e.hint));
    // the page or group named (a place) only when nothing else answers
    const place = first.length + second.length + then.length > 0 ? []
      : indexed.filter(e => matchesWords(e.where));
    // A setting can be indexed through its page, group and app/module owner.
    // Keep the most relevant hit for a destination instead of showing the same row repeatedly.
    const seen = new Set();
    return first.concat(second, then, place).filter(hit => {
      const key = hit.entry.target + "|" + hit.label;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    }).slice(0, 30).map(hit => hit.entry);
  }
}
