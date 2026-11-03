import QtQuick
import QtTest
import qs.config
import qs.kit
import qs.bar
import "qs/kit/reply.js" as Reply

Item {
  width: 720; height: 1000
  KitButton { id: button; text: "Apply"; y: 10 }
  KitSwitch { id: toggle; y: 65; accessibleName: "Wi-Fi"; onToggled: checked = !checked }
  KitSegments {
    id: segments; y: 125
    model: [{ label: "One", value: 1 }, { label: "Two", value: 2 }, { label: "Three", value: 3 }]
    current: 1
    onPicked: value => current = value
  }
  KitSelect {
    id: select; y: 190; width: 600; label: "Output"
    model: [{ label: "Speakers", value: 1 }, { label: "Headphones", value: 2 }]
    current: 1
    onPicked: value => current = value
  }
  KitSlider { id: slider; y: 420; width: 300; value: 0.5; snaps: [0, 0.25, 0.5, 0.75, 1]; onMoved: value => slider.value = value }
  KitInput { id: field; y: 470; width: 300; placeholder: "Search settings" }
  KitRow {
    id: setting; y: 520; width: 540; wide: true; label: "Layout"
    KitSegments { model: [{ label: "Compact", value: 1 }, { label: "Comfortable", value: 2 }]; current: 1 }
  }
  KitColourRow { id: picker; width: 600; y: 600; names: ["theme", "red"]; picked: "#112233"; colours: name => "#ff0000" }
  KitChipBands { id: board; y: 820; width: 600; zones: ["left", "hidden"]; idsOf: zone => zone === "left" ? ["audio", "wifi"] : []; labelOf: id => id; iconOf: id => id === "audio" ? "volume" : "wifi" }
  SignalSpy { id: inspected; target: board; signalName: "inspected" }
  SignalSpy { id: drops; target: board; signalName: "dropped" }
  SignalSpy { id: chosen; target: picker; signalName: "chosen" }
  EntryBrowser {
    id: entries; x: 480; y: 0; width: 520; height: 300
    model: [{id: "audio", label: "Audio", icon: "volume", section: "on"},
            {id: "clock", label: "Clock", icon: "clock", section: "on"},
            {id: "ai", label: "AI", icon: "bot", off: true, section: "absent"}]
    sections: [{key: "on", label: "ON"}, {key: "absent", label: "NOT INSTALLED"}]
    filters: [{label: "All", value: "all", sections: null}, {label: "Off", value: "off", sections: ["absent"]}]
    onPicked: id => selected = id
  }
  SignalSpy { id: clicks; target: button; signalName: "clicked" }
  SignalSpy { id: selections; target: select; signalName: "picked" }
  FilesSelection { id: fileSelection }
  TestFileCreation { id: fileCreation }
  FilesHistory { id: fileHistory }
  TestCase {
    name: "ShellControls"
    when: windowShown
    function init() {
      segments.current = 1;          // an earlier test may have picked another one
      ShellSettings.motion = false;
      ShellSettings.set("shareColours", true);
      ShellSettings.set("customColours", ["#112233"]);
    }
    function test_popup_content_host_lifecycle() {
      const owner = Qt.createQmlObject('import QtQuick; Item {}', parent);
      const home = Qt.createQmlObject('import QtQuick; Item {}', owner);
      const first = Qt.createQmlObject('import QtQuick; Item { property bool inIsland: false }', home);
      const second = Qt.createQmlObject('import QtQuick; Item {}', home);
      const popup = Qt.createQmlObject('import QtQuick; QtObject { property Item contentItem; property bool visible: true }', owner);
      popup.contentItem = home;
      const host = Qt.createQmlObject('import QtQuick; import qs.kit; PopupContentHost {}', parent);
      const decoration = Qt.createQmlObject('import QtQuick; Item {}', host);
      host.attach(popup);
      compare(first.parent, host); compare(second.parent, host);
      compare(host.content, first); verify(first.inIsland);
      host.attach(popup);
      compare(host.content, first);
      host.release();
      compare(first.parent, home); compare(second.parent, home);
      compare(decoration.parent, host); verify(!first.inIsland);
      compare(host.popup, null);
      const otherHome = Qt.createQmlObject('import QtQuick; Item {}', owner);
      const otherItem = Qt.createQmlObject('import QtQuick; Item { property bool inIsland: false }', otherHome);
      const otherPopup = Qt.createQmlObject('import QtQuick; QtObject { property Item contentItem }', owner);
      otherPopup.contentItem = otherHome;
      host.attach(popup);
      host.attach(otherPopup);
      compare(first.parent, home); verify(!first.inIsland);
      compare(otherItem.parent, host); verify(otherItem.inIsland);
      host.attach(popup);
      compare(otherItem.parent, otherHome); verify(!otherItem.inIsland);
      host.available = false;
      compare(first.parent, home); verify(!popup.visible); verify(!first.inIsland);
      host.attach(popup); compare(host.popup, null);
      host.available = true;
      popup.visible = true;
      host.attach(popup);
      host.destroy();
      wait(1);
      compare(first.parent, home); compare(second.parent, home);
      verify(!first.inIsland); verify(!popup.visible);
      owner.destroy();
    }
    function test_popup_content_source_destroyed() {
      const owner = Qt.createQmlObject('import QtQuick; Item {}', parent);
      const home = Qt.createQmlObject('import QtQuick; Item {}', owner);
      Qt.createQmlObject('import QtQuick; Item { property bool inIsland: false }', home);
      const popup = Qt.createQmlObject('import QtQuick; QtObject { property Item contentItem }', owner);
      popup.contentItem = home;
      const host = Qt.createQmlObject('import QtQuick; import qs.kit; PopupContentHost {}', parent);
      host.attach(popup);
      owner.destroy();
      wait(1);
      host.release();
      compare(host.content, null); compare(host.popup, null);
      host.destroy();
    }
    function test_capture_save_panel_pending_and_retry() {
      const sample = Qt.createQmlObject([
        'import QtQuick; import qs.kit;',
        'CaptureSavePanel { home: "/home/test"; controller: QtObject {',
        'property var pending: ({kind: "shot", path: "/home/test/capture.png"});',
        'property bool saveBusy: false; property string saveError: ""; property bool replaceSave: false;',
        'property int saves: 0; property int dismissals: 0;',
        'function confirmSave(path) { saves++; } function dismissSave() { dismissals++; }',
        'function editSave() { saveError = ""; replaceSave = false; } } }'
      ].join('\n'), parent);
      wait(20);
      const field = findNamed(sample, "Capture file path");
      const save = findNamed(sample, "Save"), skip = findNamed(sample, "Skip");
      verify(field !== null && save !== null && skip !== null);
      compare(field.text, "~/capture.png");
      sample.controller.pending = {kind: "shot", path: "/backup/home/test/capture.png"};
      compare(field.text, "/backup/home/test/capture.png");
      sample.controller.saveBusy = true;
      verify(!field.enabled && !save.enabled && !skip.enabled);
      mouseClick(save); mouseClick(skip);
      compare(sample.controller.saves, 0); compare(sample.controller.dismissals, 0);
      sample.controller.saveBusy = false;
      const normalHeight = sample.implicitHeight;
      sample.controller.saveError = "The output folder cannot be written";
      sample.controller.replaceSave = true;
      wait(20);
      verify(sample.implicitHeight > normalHeight);
      compare(save.text, "Replace");
      field.forceActiveFocus(); keyClick(Qt.Key_End); keyClick(Qt.Key_A);
      compare(sample.controller.saveError, ""); verify(!sample.controller.replaceSave);
      mouseClick(save); compare(sample.controller.saves, 1);
      sample.controller.pending = {kind: "video", path: "/home/test/default.mp4"};
      field.text = "/elsewhere/typed.mp4";
      field.forceActiveFocus(); keyClick(Qt.Key_Escape);
      compare(field.text, "~/default.mp4"); compare(sample.controller.dismissals, 1);
      sample.destroy();
    }
    function test_file_history_commits_only_successful_operations() {
      fileHistory.undos = []; fileHistory.redos = []; fileHistory.pending = null; fileHistory.busy = false;
      let undoCalls = 0, redoCalls = 0;
      const entry = {label: "rename", undo: () => { undoCalls++; }, redo: () => { redoCalls++; }};
      fileHistory.record(entry);
      fileHistory.undo();
      compare(undoCalls, 1); verify(!fileHistory.canUndo);
      compare(fileHistory.undos.length, 1); compare(fileHistory.redos.length, 0);
      fileHistory.undo(); compare(undoCalls, 1);
      fileHistory.complete(false);
      verify(fileHistory.canUndo); compare(fileHistory.redos.length, 0);
      fileHistory.undo(); fileHistory.complete(true);
      compare(fileHistory.undos.length, 0); compare(fileHistory.redos.length, 1);
      fileHistory.redo(); compare(redoCalls, 1);
      fileHistory.complete(false); verify(fileHistory.canRedo);
      compare(fileHistory.undos.length, 0); compare(fileHistory.redos.length, 1);
      fileHistory.redo(); fileHistory.complete(true);
      compare(fileHistory.undos.length, 1); compare(fileHistory.redos.length, 0);
      fileHistory.busy = true; fileHistory.undo(); compare(undoCalls, 2);
      fileHistory.busy = false;
      fileHistory.undo(); fileHistory.complete(true);
      fileHistory.record(entry); verify(!fileHistory.canRedo);
    }
    function test_file_create_redo_does_not_record_another_action() {
      fileCreation.calls = []; fileCreation.history = [];
      fileCreation.createNew("mkdir", "/new-folder");
      compare(fileCreation.calls.length, 1);
      fileCreation.calls[0].request.after();
      compare(fileCreation.history.length, 1);
      fileCreation.history[0].redo();
      compare(fileCreation.calls.length, 2);
      compare(fileCreation.calls[1].args, ["mkdir", "/new-folder"]);
      if (fileCreation.calls[1].request.after) fileCreation.calls[1].request.after();
      compare(fileCreation.history.length, 1);
    }
    function test_file_selection_missing_anchor() {
      fileSelection.single = false;
      fileSelection.selection = [];
      fileSelection.rows = [{path: "/a"}, {path: "/b"}, {path: "/c"}];
      fileSelection.anchor = "/deleted";
      fileSelection.select("/b", "range");
      compare(fileSelection.selection, ["/b"]);
      fileSelection.anchor = "/a";
      fileSelection.select("/c", "range");
      compare(fileSelection.selection, ["/a", "/b", "/c"]);
    }
    function test_file_picker_selection_limit() {
      fileSelection.rows = [{path: "/a"}, {path: "/b"}];
      fileSelection.single = true;
      fileSelection.selectAll();
      compare(fileSelection.selection, ["/a"]);
      fileSelection.select("/b", "toggle");
      compare(fileSelection.selection, ["/b"]);
      fileSelection.single = false;
      fileSelection.selectAll();
      compare(fileSelection.selection, ["/a", "/b"]);
      fileSelection.rows = [];
      fileSelection.selectAll();
      compare(fileSelection.selection, []);
    }
    function test_file_shift_selection_extends_and_shrinks() {
      fileSelection.single = false;
      fileSelection.rows = [{path: "/a"}, {path: "/b"}, {path: "/c"}, {path: "/d"}];
      fileSelection.select("/b", "single");
      fileSelection.step(1, true);
      compare(fileSelection.selection, ["/b", "/c"]);
      fileSelection.step(1, true);
      compare(fileSelection.selection, ["/b", "/c", "/d"]);
      fileSelection.step(-1, true);
      compare(fileSelection.selection, ["/b", "/c"]);
      fileSelection.select("/a", "range");
      compare(fileSelection.selection, ["/a", "/b"]);
      fileSelection.select("/d", "single");
      fileSelection.select("/b", "range");
      compare(fileSelection.selection, ["/b", "/c", "/d"]);
    }
    function test_file_selection_tracks_visible_rows() {
      fileSelection.single = false;
      fileSelection.rows = [{path: "/a"}, {path: "/b"}];
      fileSelection.selectAll();
      fileSelection.rows = [{path: "/b"}];
      compare(fileSelection.selection, ["/b"]);
      fileSelection.rows = [];
      compare(fileSelection.selection, []);
      fileSelection.rows = [{path: "/x"}, {path: "/y"}, {path: "/z"}];
      fileSelection.step(3, false);
      compare(fileSelection.selection, ["/x"]);
      fileSelection.select("/not-visible", "single");
      compare(fileSelection.selection, ["/x"]);
    }
    function test_backend_reply_contract_data() {
      return ["null", "[]", "true", "42", '"text"', "", "bad JSON"].map(value => ({tag: value || "empty", value: value}));
    }
    function test_backend_reply_contract(data) {
      const reply = Reply.parse(data.value, "example.py");
      compare(reply.ok, false);
      compare(reply.error, "bad reply from example.py");
      compare(Reply.parse(data.value, "example.py", null), null);
      compare(Reply.parse(data.value, "example.py", {error: "fallback"}).error, "fallback");
    }
    function test_backend_reply_object() {
      compare(Reply.parse('{"ok":true,"value":3}', "example.py").value, 3);
      compare(Reply.parse('{"ok":false,"error":"offline"}', "example.py").error, "offline");
    }
    function test_backend_list_contract() {
      compare(Reply.parseList('[{"ssid":"network"}]')[0].ssid, "network");
      compare(Reply.parseList("[]"), []);
      for (const value of ["null", "{}", '{"ok":false}', "true", "42", '"text"', "", "bad JSON"]) {
        compare(Reply.parseList(value), []);
        compare(Reply.parseList(value, null), null);
        compare(Reply.parseList(value, ["fallback"]), ["fallback"]);
      }
    }
    function test_select_pending_and_model_changes() {
      const model = select.model;
      const current = select.current;
      selections.clear();
      select.openChoices(); verify(select.expanded);
      select.busy = true; verify(!select.expanded);
      select.choose(1); compare(selections.count, 0);
      select.busy = false;
      select.openChoices(); verify(select.expanded);
      select.model = []; verify(!select.expanded);
      select.openChoices(); verify(!select.expanded);
      select.choose(0); compare(selections.count, 0);
      select.model = model;
      select.disabled = true;
      select.choose(1); compare(selections.count, 0);
      select.disabled = false;
      select.choose(model.findIndex(c => c.value === current));
      compare(selections.count, 0);
    }
    function findNamed(item, name) {
      if (item.Accessible.name === name) return item;
      for (let i = 0; i < item.children.length; i++) { const found = findNamed(item.children[i], name); if (found) return found; }
      return null;
    }
    function test_settings_separator_spacing_data() {
      return [{ tag: "strict", material: false }, { tag: "material", material: true }];
    }
    function test_settings_separator_spacing(data) {
      const previous = ShellSettings.material;
      ShellSettings.material = data.material;
      const sample = Qt.createQmlObject([
        'import QtQuick; import qs.kit;',
        'Column { width: 600; property alias divider: divider; property alias groups: groups;',
        'Item { width: parent.width; height: 30; property bool kitUnboxed: true }',
        'Item { id: divider; width: parent.width; height: 1; property bool kitUnboxed: true; KitLine { anchors.fill: parent } }',
        'KitLine { visible: false }',
        'Loader { width: parent.width; sourceComponent: Column { KitRow { label: "First setting" } KitGrouper {} } }',
        'KitGrouper { id: groups } }'
      ].join('\n'), parent);
      wait(30);
      compare(sample.groups.boxes.length, 1);
      compare(sample.groups.boxes[0].y - sample.divider.y - sample.divider.height, Theme.settingsRowInset);
      sample.groups.layout();
      wait(20);
      compare(sample.groups.boxes[0].y - sample.divider.y - sample.divider.height, Theme.settingsRowInset);
      sample.destroy();
      ShellSettings.material = previous;
    }
    // Material: the runs between a popup's lines become tonal sections, the lines their gaps;
    // a header and a footer of buttons stand outside; Strict keeps the lines and draws none
    function test_popup_sections_follow_the_style() {
      const previous = ShellSettings.material;
      const sample = Qt.createQmlObject([
        'import QtQuick; import qs.kit;',
        'KitFrame { property alias first: first; property alias last: last;',
        'KitHeader { title: "Audio" }',
        'KitLine { id: first }',
        'KitRow { label: "Output" }',
        'Column { width: parent.width; KitLabel { text: "INPUT" } KitRow { label: "Microphone" } }',
        'KitLine { id: last }',
        'KitButton { width: parent.width; text: "Open settings" } }'
      ].join('\n'), parent);
      ShellSettings.material = true;
      wait(40);
      compare(sample.sections.length, 2, "a titled group starts its own section");
      verify(sample.first.gapHeight >= 0 && sample.last.gapHeight >= 0, "lines turn into gaps");
      const a = sample.sections[0], b = sample.sections[1];
      verify(b.y > a.y + a.h, "sections keep a gap between them");
      ShellSettings.material = false;
      wait(40);
      compare(sample.sections.length, 0);
      compare(sample.first.gapHeight, -1);
      compare(sample.last.gapHeight, -1);
      compare(sample.padded.length, 0, "Strict gets each group's own top back");
      sample.destroy();
      ShellSettings.material = previous;
    }
    function test_choices_fit_their_parent() {
      const sample = Qt.createQmlObject([
        'import QtQuick; import qs.kit;',
        'Item { width: 200; height: 40; property alias row: row;',
        'KitChoices { id: row; model: [{ label: "Claude", value: 1 }, { label: "Codex", value: 2 }, { label: "Ollama", value: 3 }]; current: 1 } }'
      ].join('\n'), parent);
      wait(20);
      verify(sample.row.squeezed);
      verify(sample.row.width <= 200 + 0.5, "the row stays inside its parent");
      sample.destroy();
    }
    function test_group_separator_keeps_visibility_binding() {
      const sample = Qt.createQmlObject([
        'import QtQuick; import qs.kit;',
        'Column { width: 600; property bool split: false; property alias divider: divider; property alias groups: groups;',
        'KitRow { label: "First" }',
        'KitLine { id: divider; visible: parent.split }',
        'KitRow { label: "Second" }',
        'KitGrouper { id: groups } }'
      ].join('\n'), parent);
      wait(30);
      compare(sample.groups.boxes.length, 1);
      sample.split = true;
      wait(30);
      sample.groups.layout();
      wait(30);
      compare(sample.divider.visible, true);
      compare(sample.groups.boxes.length, 2);
      const a = sample.groups.boxes[0], b = sample.groups.boxes[1];
      verify(b.y > a.y + a.h, "Cards need a visible gap");
      sample.split = false;
      wait(30);
      sample.groups.layout();
      compare(sample.divider.visible, false);
      compare(sample.groups.boxes.length, 1);
      sample.destroy();
    }
    function test_header_shared_height_has_no_bottom_slack() {
      const sample = Qt.createQmlObject([
        'import QtQuick; import qs.kit; import qs.config;',
        'Column { width: 600; spacing: Theme.sectionGap;',
        'property alias heading: heading; property alias divider: divider;',
        'KitHeader { id: heading; title: "Shell Manager"; subtitle: "Shell settings"; height: implicitHeight + 24 }',
        'KitLine { id: divider } }'
      ].join('\n'), parent);
      wait(20);
      const caption = sample.heading.children[1];
      compare(caption.y + caption.height, sample.heading.height);
      compare(sample.divider.y - caption.y - caption.height, Theme.sectionGap);
      sample.destroy();
    }
    function test_divider_centres_between_caption_and_card() {
      const sample = Qt.createQmlObject([
        'import QtQuick; import qs.kit;',
        'Column { width: 600; property alias divider: divider; property alias groups: groups; property alias heading: heading;',
        'Item { id: heading; width: parent.width; height: 44; property bool kitUnboxed: true; property Item kitCaption: caption;',
        'Item { id: caption; width: 100; height: 32 } }',
        'KitLine { id: divider; sectionBreak: false }',
        'Column { width: parent.width; KitRow { label: "Window" } KitGrouper {} }',
        'KitGrouper { id: groups } }'
      ].join('\n'), parent);
      wait(40);
      const stroke = sample.divider.mapToItem(sample, 0, 0).y;
      const captionEdge = sample.heading.kitCaption.mapToItem(sample, 0, sample.heading.kitCaption.height).y;
      const cardEdge = sample.groups.boxes[0].y;
      compare(stroke - captionEdge, cardEdge - stroke - sample.divider.height);
      sample.destroy();
    }
    function test_physical_divider_survives_grouping() {
      const sample = Qt.createQmlObject([
        'import QtQuick; import qs.kit;',
        'Column { width: 600; property alias divider: divider;',
        'Item { width: 600; height: 30; property bool kitUnboxed: true }',
        'KitLine { id: divider; sectionBreak: false }',
        'KitRow { label: "Setting" } KitGrouper {} }'
      ].join('\n'), parent);
      wait(30);
      compare(sample.divider.opacity, 1);
      compare(sample.divider.height, Theme.dividerThickness);
      compare(sample.divider.color, Theme.dividerColor);
      sample.destroy();
    }
    function test_add_bar_follows_preview_strips() {
      const sample = Qt.createQmlObject('import QtQuick; import qs.kit; BarArrangement { width: 700; idsOf: zone => zone === "left" ? ["audio"] : []; labelOf: id => id; iconOf: id => "volume" }', parent);
      const spy = Qt.createQmlObject('import QtTest; SignalSpy { signalName: "addBarRequested" }', parent);
      spy.target = sample;
      wait(20);
      const add = findNamed(sample, "Add bar");
      verify(add !== null);
      const face = findNamed(sample, "Preview audio");
      const a = add.mapToItem(sample, 0, 0), f = face.mapToItem(sample, 0, 0);
      verify(a.x > f.x); verify(Math.abs(a.y - f.y) <= 4);
      add.clicked(); compare(spy.count, 1);
      spy.destroy(); sample.destroy();
    }
    function test_overview_uses_readable_names_without_scroll() {
      const sample = Qt.createQmlObject('import QtQuick; import qs.kit; BarArrangement { width: 380; idsOf: zone => zone === "left" ? Array.from({length: 24}, (_, i) => "Module " + i) : []; labelOf: id => id; iconOf: id => "volume" }', parent);
      wait(30);
      const view = findNamed(sample, "Bar layout overview");
      verify(view !== null);
      verify(view.contentX === undefined);
      const icon = findNamed(view, "Preview Module 23");
      verify(icon !== null);
      verify(icon.width > 28); compare(icon.height, 28);
      for (let item = icon; item && item !== sample; item = item.parent) compare(item.scale, 1);
      const position = icon.mapToItem(view, 0, 0);
      verify(position.x >= 0 && position.x + icon.width <= view.width);
      verify(position.y >= 0 && position.y + icon.height <= view.height);
      const add = findNamed(sample, "Add bar");
      verify(add !== null);
      sample.width = 700; wait(20);
      verify(view.height < 200);
      sample.destroy();
    }
    function test_separator_does_not_expand_module_row() {
      const sample = Qt.createQmlObject('import QtQuick; import qs.kit; BarArrangement { width: 700; showOverview: false; showAvailable: false; idsOf: zone => zone === "left" ? ["sep-one", "audio"] : []; labelOf: id => id === "sep-one" ? "Separator" : "Audio"; iconOf: id => "volume" }', parent);
      wait(20);
      const separator = findNamed(sample, "Separator, left");
      const audio = findNamed(sample, "Audio, left");
      verify(separator !== null); verify(audio !== null);
      verify(separator.height > 0);
      compare(separator.height, audio.height);
      compare(separator.y, audio.y);
      sample.destroy();
    }
    function test_arrangement_drag_cancel_and_invalid_target() {
      const sample = Qt.createQmlObject('import QtQuick; import qs.kit; BarArrangement { width: 700; idsOf: zone => zone === "left" ? ["audio"] : zone === "right" ? ["wifi"] : zone === "hidden" ? ["battery"] : []; accepts: (id, zone) => zone !== "folder"; iconOf: id => "volume" }', parent);
      const spy = Qt.createQmlObject('import QtTest; SignalSpy { signalName: "moved" }', parent);
      spy.target = sample;
      wait(30);
      const tile = findNamed(sample, "audio, left");
      const target = findNamed(sample, "wifi, right");
      verify(tile !== null); verify(target !== null);
      const start = tile.mapToItem(sample, 15, 15);
      const end = target.mapToItem(sample, 15, 15);
      mousePress(sample, start.x, start.y);
      mouseMove(sample, end.x, end.y, 30);
      verify(sample.dragging);
      compare(sample.dragBoard.dropZone, "right");
      keyClick(Qt.Key_Escape);
      verify(!sample.dragging);
      mouseRelease(sample, end.x, end.y);
      compare(spy.count, 0);
      mousePress(sample, start.x, start.y);
      mouseMove(sample, end.x, end.y, 30);
      mouseRelease(sample, end.x, end.y);
      compare(spy.count, 1);
      compare(spy.signalArguments[0][0], "audio");
      compare(spy.signalArguments[0][1], "right");
      sample.dragBoard.dragId = "audio";
      sample.dragBoard.dropZone = "folder";
      sample.dragBoard.release();
      compare(spy.count, 1);
      verify(sample.height < 350);
      spy.destroy(); sample.destroy();
    }
    function test_layout_snapshot_restores_both_styles_and_child_bar() {
      const original = JSON.parse(JSON.stringify(BarLayout.store.screens));
      const style = ShellSettings.barStyle;
      const screen = "HDMI-A-1";
      ShellSettings.barStyle = "solid";
      const before = BarLayout.snapshot(screen);
      const child = BarLayout.addBar(screen);
      BarLayout.moveToBar(screen, "audio", child, 0);
      ShellSettings.barStyle = "island";
      BarLayout.islandMove("wifi", "hidden", 0, screen);
      BarLayout.update(screen, before);
      compare(BarLayout.snapshot(screen), before);
      ShellSettings.barStyle = style;
      BarLayout.store.screens = original;
    }
    function test_chip_click_and_drag() {
      inspected.clear(); drops.clear();
      mouseClick(board, 125, 20); compare(inspected.count, 1); compare(drops.count, 0);
      mousePress(board, 125, 20); mouseMove(board, 240, 20, 50); mouseRelease(board, 240, 20);
      compare(drops.count, 1); compare(board.dragId, "");
    }
    function test_long_module_label_wraps() {
      const sample = Qt.createQmlObject('import QtQuick; import qs.kit; KitChipBands { width: 260; stackedLabels: true; zones: ["left"]; idsOf: zone => ["long"]; labelOf: id => "A module with a deliberately long readable name"; iconOf: id => "volume" }', parent);
      wait(20);
      const chip = findNamed(sample, "A module with a deliberately long readable name, LEFT");
      verify(chip !== null);
      function labelIn(item) {
        if (item.text === "A module with a deliberately long readable name") return item;
        for (const child of item.children) { const found = labelIn(child); if (found) return found; }
        return null;
      }
      const label = labelIn(chip);
      verify(label !== null);
      verify(!label.truncated);
      verify(label.height > Theme.fontSize);
      verify(chip.height >= label.height + 12);
      verify(chip.width <= 260);
      sample.destroy();
    }
    function test_child_bars_solid() {
      const previous = ShellSettings.barStyle;
      ShellSettings.barStyle = "solid";
      const screen = "HDMI-A-1";
      const before = BarLayout.visibleIn("left", screen).concat(BarLayout.visibleIn("center", screen), BarLayout.visibleIn("right", screen));
      const first = BarLayout.addBar(screen);
      const second = BarLayout.addBar(screen);
      verify(first !== second);
      verify(BarLayout.barsOn(screen).some(b => b.id === first));
      BarLayout.moveToBar(screen, "audio", first, 0);
      compare(BarLayout.barModules(screen, first), ["audio"]);
      verify(!BarLayout.visibleIn("right", screen).includes("audio"));
      BarLayout.updateBar(screen, first, {side: "left", place: "edge"});
      compare(BarLayout.barsOn(screen).find(b => b.id === first).side, "left");
      compare(BarLayout.barModules(screen, first), ["audio"]);
      BarLayout.removeBar(screen, first); BarLayout.removeBar(screen, second);
      compare(BarLayout.visibleIn("left", screen).concat(BarLayout.visibleIn("center", screen), BarLayout.visibleIn("right", screen)), before);
      ShellSettings.barStyle = previous;
    }
    function test_card_drop_uses_both_axes() {
      board.cards = true; board.mainZoneCount = 2; board.width = 700;
      wait(20);
      board.track(600, 45); compare(board.dropZone, "hidden");
      board.track(100, 45); compare(board.dropZone, "left");
      board.width = 300; wait(20);
      board.track(100, 150); compare(board.dropZone, "hidden");
      board.cards = false; board.width = 600; board.dropZone = "";
    }
    function test_colour_row_strip() {
      compare(picker.editing, false);
      picker.startEditing();
      compare(picker.editing, true);
      verify(/^#[0-9a-f]{6}$/.test(picker.draft));
      picker.editing = false;
    }
    function test_colour_row_resolves_names_and_own() {
      compare(picker.pairOf("red")[0], "#ff0000");
      compare(picker.pairOf("#112233")[0], "#112233");
    }
    function test_entry_browser_order_search_and_filter() {
      entries.query = ""; entries.selected = "";
      compare(entries.ordered.map(e => e.id), ["audio", "clock", "ai"]);   // section by section, by name
      compare(entries.entry, null);                                        // "" is the index
      entries.query = "CL"; compare(entries.matches.map(e => e.id), ["clock"]);
      entries.query = "nothing"; compare(entries.matches.length, 0);
      entries.query = "";
      compare(entries.filter, "all");                                      // the first filter at first
      entries.filter = "off"; compare(entries.matches.map(e => e.id), ["ai"]);
      entries.query = "cl"; compare(entries.matches.length, 0);            // search within the filter
      entries.query = ""; entries.filter = "all";
      entries.selected = "ai"; compare(entries.entry.id, "ai");
      entries.picked(""); compare(entries.selected, "");
    }
    function test_island_copy_preserves_hidden() {
      const hidden = BarLayout.modules.map(m => m.id).filter(id => !["workspaces", "audio", "wifi", "clock", "folder"].includes(id));
      BarLayout.store.shared = false;
      BarLayout.store.screens = ({main: {zones: null, hidden: [], folder: null, bars: [], island: {start: ["workspaces"], end: ["audio"], hub: ["wifi"], tiles: [], hidden: hidden}}});
      BarLayout.islandCopy("HDMI-A-1", "eDP-1");
      compare(BarLayout.islandIn("hub", "eDP-1").join(","), "wifi");
      verify(BarLayout.islandHidden("eDP-1").includes("music"));
    }
    function test_modes_keep_main_layouts() {
      BarLayout.store.screens = ({}); ShellSettings.barStyle = "solid";
      BarLayout.move("audio", "left", 0, "HDMI-A-1");
      const before = BarLayout.visibleIn("left", "HDMI-A-1").join(",");
      ShellSettings.barStyle = "island";
      BarLayout.islandMove("audio", "end", 0, "HDMI-A-1");
      compare(BarLayout.islandIn("end", "HDMI-A-1")[0], "audio");
      ShellSettings.barStyle = "solid";
      compare(BarLayout.visibleIn("left", "HDMI-A-1").join(","), before);
    }
    function test_named_shape_options() {
      ShellSettings.barStyle = "solid"; ShellSettings.looks = ({});
      ShellSettings.setLook("clockOpens", "click", "island");
      compare(ShellSettings.look("clockOpens", "island"), "click");
      compare(ShellSettings.look("clockOpens"), "hover");
      ShellSettings.barStyle = "island"; compare(ShellSettings.look("clockOpens"), "click");
      ShellSettings.setLook("barIconGrow", 4); ShellSettings.barStyle = "solid";
      compare(ShellSettings.look("barIconGrow"), 0);
    }
    function test_button() {
      button.forceActiveFocus();
      clicks.clear(); keyClick(Qt.Key_Space); keyClick(Qt.Key_Return);
      compare(clicks.count, 2);
      button.disabled = true; keyClick(Qt.Key_Space); compare(clicks.count, 2);
      button.disabled = false;
      button.busy = true; keyClick(Qt.Key_Return); compare(clicks.count, 2);
      button.busy = false;
    }
    function test_segments() {
      segments.forceActiveFocus(); keyClick(Qt.Key_Right); compare(segments.current, 2);
      keyClick(Qt.Key_End); compare(segments.current, 3);
      keyClick(Qt.Key_Right); compare(segments.current, 3);
      keyClick(Qt.Key_Home); compare(segments.current, 1);
    }
    function test_select_pushes_following_content_data() {
      return [{tag: "popup", grouped: false}, {tag: "settings", grouped: true}];
    }
    function test_select_pushes_following_content(data) {
      const sample = Qt.createQmlObject([
        'import QtQuick; import qs.kit;',
        'Column { width: 600; spacing: 8; property alias select: select; property alias next: next;',
        'KitSelect { id: select; label: "Device"; model: [{label: "One", value: 1}, {label: "Two", value: 2}]; current: 1 }',
        'KitRow { id: next; label: "Following setting" }',
        data.grouped ? 'KitGrouper {}' : '', '}'
      ].join('\n'), parent);
      wait(30);
      const closed = sample.next.y;
      sample.select.openChoices();
      wait(30);
      verify(sample.next.y > closed);
      verify(sample.next.y >= sample.select.y + sample.select.height);
      sample.select.expanded = false;
      wait(30);
      compare(sample.next.y, closed);
      sample.destroy();
    }
    function test_select() {
      // Locate the accessible combobox rather than depending on its visual position.
      function findBox(item) {
        if (item.Accessible.role === Accessible.ComboBox) return item;
        for (let i=0; i<item.children.length; i++) { let found=findBox(item.children[i]); if(found) return found; }
        return null;
      }
      const box=findBox(select); verify(box !== null); box.forceActiveFocus();
      keyClick(Qt.Key_Space); verify(select.expanded);
      keyClick(Qt.Key_Down); keyClick(Qt.Key_Return); compare(select.current, 2); verify(!select.expanded);
      keyClick(Qt.Key_Space); keyClick(Qt.Key_Escape); verify(!select.expanded);
    }
    function test_slider() {
      slider.forceActiveFocus(); keyClick(Qt.Key_Right); compare(slider.value, 0.75);
      keyClick(Qt.Key_Left); compare(slider.value, 0.5);
    }
    function test_responsive_setting() {
      setting.width=Theme.rowStackBelow - 1; verify(setting.stacked);
      setting.width=Math.max(720, Theme.rowStackBelow); verify(!setting.stacked);
    }
    function test_switch() {
      toggle.forceActiveFocus(); keyClick(Qt.Key_Space); verify(toggle.checked);
      toggle.disabled=true; keyClick(Qt.Key_Space); verify(toggle.checked); toggle.disabled=false;
    }
    function test_styles_data() {
      return [{tag:"strict", material:false, corners:"sharp"}, {tag:"material", material:true, corners:"round"}];
    }
    function test_styles(data) {
      ShellSettings.material=data.material; ShellSettings.corners=data.corners;
      compare(Theme.controlHeight, Theme.aired(data.material ? 36 : 34));
      compare(button.height, Theme.controlHeight);
      verify(Theme.contrast(Theme.onSurfaceVariant, Theme.surfaceHighest) >= 4.5);
      verify(Theme.contrast(Theme.inkOn(Theme.accent), Theme.accent) >= 4.5);
      field.input.forceActiveFocus(); keyClick(Qt.Key_A); keyClick(Qt.Key_U); keyClick(Qt.Key_D); keyClick(Qt.Key_I); keyClick(Qt.Key_O); compare(field.text,"audio"); field.text="";
      wait(50);

    }
  }
}
