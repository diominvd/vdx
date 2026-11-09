pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "settings_data.js" as Data

// Options of each module, set in the Shell Manager's Modules section and kept
// in the state dir (modules.json): {"<module>": {"<key>": value}}. A module
// reads `get("sysmon", "gpu", true)` — the default lives with the module.
Singleton {
  id: root

  // a hand-edited file can hold any shape: callers see an object of objects, never null or an array
  readonly property var values: Data.record(state.values)

  // a module's own keys (an inherited name such as `toString` is not one)
  function own(module) {
    return Object.prototype.hasOwnProperty.call(values, module) ? Data.record(values[module]) : {};
  }

  function get(module, key, fallback) {
    const options = own(module);
    return Object.prototype.hasOwnProperty.call(options, key) ? options[key] : fallback;
  }

  // a list option: another shape is the fallback; `strings` also drops entries that are not text
  function array(module, key, fallback) {
    const v = get(module, key, undefined);
    return Array.isArray(v) ? v : fallback;
  }
  function strings(module, key, fallback) {
    const v = get(module, key, undefined);
    return Array.isArray(v) ? Data.strings(v) : fallback;
  }

  // `keys` (optional): only those (an app and its bar module share one id:
  // config/settings-keys.json lists each one's)
  function changed(module, keys) {
    return Object.keys(own(module)).some(k => !keys || keys.includes(k));
  }

  // back to the module's defaults
  function reset(module, keys) {
    const all = Object.assign({}, values);
    if (keys) {
      const left = Object.assign({}, own(module));
      for (const k of keys) delete left[k];
      if (Object.keys(left).length) all[module] = left;
      else delete all[module];
    } else {
      delete all[module];
    }
    state.values = all;
  }

  // the keys of each app's and app module's settings file (scripts/settings_index.py)
  property var fileKeys: ({})
  function keysOf(file) { return fileKeys[file] ?? null; }

  FileView {
    path: Quickshell.shellDir + "/config/settings-keys.json"
    printErrors: false
    onLoaded: { try { root.fileKeys = JSON.parse(text()); } catch (e) { root.fileKeys = {}; } }
  }

  function set(module, key, value) {
    const all = Object.assign({}, values);
    all[module] = Object.assign({}, own(module), { [key]: value });
    state.values = all;
  }

  FileView {
    path: Quickshell.statePath("modules.json")
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    onLoadFailed: writeAdapter()

    JsonAdapter {
      id: state
      property int version: 0         // schema (scripts/settings_migrate.py stamps it)
      property var values: ({})
    }
  }
}
