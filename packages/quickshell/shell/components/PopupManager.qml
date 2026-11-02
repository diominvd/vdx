pragma Singleton
import QtQuick
import Quickshell.Hyprland
import qs.config

// Keeps at most one popup open across the bar: opening one hides the previous.
// `holding` keeps an open popup while the capture overlay takes the focus;
// `frozen` hides it once the overlay shows a still copy of the screen with it.
QtObject {
  property var current: null
  property bool holding: false
  property bool frozen: false
  // where the last open popup's bar underline stood: { bar, x, width, at }
  property var lastLine: null
  onHoldingChanged: if (!holding) frozen = false

  // ---- ipc ----
  // Every bar has its own popup per module, but an IPC target answers once:
  // the popup on the focused monitor's bar, else the first one there is.
  property var ipcPopups: ({})               // target -> [BarPopup]

  function addIpc(target, popup) {
    if (!target || !popup || (ipcPopups[target] ?? []).includes(popup)) return;
    const next = Object.assign({}, ipcPopups);
    next[target] = (next[target] ?? []).concat([popup]);
    ipcPopups = next;
  }

  function removeIpc(target, popup) {
    const next = Object.assign({}, ipcPopups);
    const remaining = (next[target] ?? []).filter(p => p !== popup);
    if (remaining.length) next[target] = remaining;
    else delete next[target];
    ipcPopups = next;
  }

  function ipcOwner(target) {
    const list = (ipcPopups[target] ?? []).filter(p => !!p?.bar?.screen);
    return list.find(p => p.bar.screen.name === Hyprland.focusedMonitor?.name) ?? list[0] ?? null;
  }

  // Called for every popup, including ones without an IPC target. Destruction
  // need not emit visibleChanged, so explicitly release the outside-click
  // catcher, keyboard-demand bindings and any cached underline position.
  function unregister(popup) {
    close(popup);
    for (const target of Object.keys(ipcPopups)) {
      if (ipcPopups[target].includes(popup)) removeIpc(target, popup);
    }
    if (lastLine?.bar === popup.bar) lastLine = null;
  }

  function open(win) {
    if (current === win) return;
    const prev = current;
    current = win;                   // first, so prev's close() is a no-op
    if (prev?.visible) prev.visible = false;
  }

  function close(win) {
    if (current === win) current = null;
  }

  // Shared Escape/back entry point. A view may provide its local parent route
  // (Island → Hub); otherwise the active popup is dismissed if it owns Escape.
  function back(fallback) {
    if (fallback) { fallback(); return true; }
    if (current?.visible && current.closeOnEscape) {
      current.visible = false;
      return true;
    }
    return false;
  }

  // An app's window opened from its bar module closes that module's popup.
  function closeModule(id) {
    if (current?.moduleId === id && ModuleSettings.get(id, "closeOnOpen", true)) current.visible = false;
  }
}
