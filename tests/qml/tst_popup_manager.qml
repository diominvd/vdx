import QtQuick
import QtTest
import qs.components
import qs.config
import TestQuickshell

TestCase {
  name: "PopupManager"

  Component {
    id: popupFactory
    QtObject {
      id: popup
      property bool visible: false
      property bool closeOnEscape: true
      property string moduleId: "audio"
      property var bar: ({screen: {name: "one"}})
      onVisibleChanged: {
        if (visible) PopupManager.open(popup);
        else PopupManager.close(popup);
      }
    }
  }

  QtObject {
    id: observer
    readonly property var owner: PopupManager.ipcOwner("audio")
    readonly property bool catchingClicks: !!PopupManager.current && !PopupManager.holding
  }

  function init() {
    PopupManager.current = null;
    PopupManager.ipcPopups = ({});
    PopupManager.lastLine = null;
    PopupManager.holding = false;
    PopupManager.frozen = false;
    Hyprland.focusedMonitor = null;
    ModuleSettings.values = ({});
  }

  function popup(screen) {
    return createTemporaryObject(popupFactory, this, {bar: {screen: screen ? {name: screen} : null}});
  }

  function test_switch_keeps_new_popup_current_during_previous_close() {
    const first = popup("one"), next = popup("two");
    first.visible = true;
    compare(PopupManager.current, first);
    next.visible = true;
    verify(!first.visible); verify(next.visible);
    compare(PopupManager.current, next);
    PopupManager.close(first);
    compare(PopupManager.current, next);
    next.visible = false;
    compare(PopupManager.current, null);
    verify(!observer.catchingClicks);
  }

  function test_owner_binding_tracks_registration_focus_and_removal() {
    const first = popup("one"), next = popup("two");
    compare(observer.owner, null);
    PopupManager.addIpc("audio", first);
    compare(observer.owner, first);
    PopupManager.addIpc("audio", next);
    Hyprland.focusedMonitor = {name: "two"};
    compare(observer.owner, next);
    Hyprland.focusedMonitor = {name: "missing"};
    compare(observer.owner, first);
    PopupManager.removeIpc("audio", first);
    compare(observer.owner, next);
    PopupManager.removeIpc("audio", next);
    compare(observer.owner, null);
    verify(!Object.prototype.hasOwnProperty.call(PopupManager.ipcPopups, "audio"));
  }

  function test_registration_is_idempotent_and_skips_disconnected_bars() {
    const missing = popup(""), live = popup("one");
    PopupManager.addIpc("audio", missing);
    PopupManager.addIpc("audio", live);
    PopupManager.addIpc("audio", live);
    compare(PopupManager.ipcPopups.audio.length, 2);
    compare(observer.owner, live);
    live.bar = {screen: null};
    compare(observer.owner, null);
  }

  function test_unregister_clears_active_popup_and_all_registrations() {
    const first = popup("one"), next = popup("two");
    PopupManager.addIpc("audio", first);
    PopupManager.addIpc("other", first);
    PopupManager.addIpc("audio", next);
    first.visible = true;
    PopupManager.lastLine = {bar: first.bar, x: 10, width: 20, at: 0};
    PopupManager.unregister(first);
    compare(PopupManager.current, null);
    verify(!observer.catchingClicks);
    compare(observer.owner, next);
    compare(PopupManager.ipcOwner("other"), null);
    compare(PopupManager.lastLine, null);
    PopupManager.unregister(first);
    compare(observer.owner, next);
  }

  function test_unregister_popup_without_ipc_keeps_other_popup() {
    const first = popup("one"), next = popup("two");
    next.visible = true;
    PopupManager.unregister(first);
    compare(PopupManager.current, next);
    PopupManager.unregister(next);
    compare(PopupManager.current, null);
  }

  function test_shared_back_closes_popup_or_uses_parent_route() {
    const item = popup("one");
    item.visible = true;
    verify(PopupManager.back());
    verify(!item.visible);
    compare(PopupManager.current, null);
    let returned = false;
    verify(PopupManager.back(() => returned = true));
    verify(returned);
  }

  Component { id: lifetimeFactory; TestPopupLifetime {} }
  QtObject { id: probe; property int closed: 0 }

  function test_bar_popup_destruction_closes_and_unregisters() {
    const item = lifetimeFactory.createObject(this, {probe: probe});
    probe.closed = 0;
    item.visible = true;
    PopupManager.addIpc("audio", item);
    PopupManager.open(item);
    item.destroy();
    wait(1);
    compare(probe.closed, 1);
    compare(PopupManager.current, null);
    compare(observer.owner, null);
    verify(!observer.catchingClicks);
  }

  function test_module_close_preference_and_capture_hold() {
    const item = popup("one");
    item.visible = true;
    PopupManager.closeModule("other");
    verify(item.visible);
    ModuleSettings.values = {"audio/closeOnOpen": false};
    PopupManager.closeModule("audio");
    verify(item.visible);
    ModuleSettings.values = ({});
    PopupManager.closeModule("audio");
    verify(!item.visible);
    PopupManager.holding = true;
    PopupManager.frozen = true;
    PopupManager.holding = false;
    verify(!PopupManager.frozen);
  }
}
