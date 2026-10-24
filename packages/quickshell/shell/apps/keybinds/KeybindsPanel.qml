import QtQuick
import qs.components
import qs.config
import qs.apps.shellmanager
import qs.kit

// The keybinds panel: a search, tabs (Mode, Windows, Desktop, Media — KeybindsService.tabs) and
// under the chosen one its sections, a row per bind: what it does on the left, its keys as keycaps on
// the right. The search matches the section, the name and the keys, within the tab. Tab / Shift+Tab
// switch the tab; Escape emits `back`. Shown floating (Keybinds, Super+B) or inside the island
// (Island › Keys). Changing a bind: hypr/components/keybinds.lua (the modes' in hypr/components/modes/).
KitFrame {
  id: root

  readonly property var kb: KeybindsService
  // Shell apps › Keybinds in the Shell Manager (ModuleSettings "keybinds"), as the launcher's
  readonly property int rows: ModuleSettings.get("keybinds", "rows", 8)
  readonly property string opens: ModuleSettings.get("keybinds", "opens", "mode")
  readonly property bool clearOnClose: ModuleSettings.get("keybinds", "clear", true)
  readonly property bool english: ModuleSettings.get("keybinds", "english", true)

  property string tab: "mode"
  property string query: ""
  readonly property string q: query.trim().toLowerCase()

  signal back()

  function tabLabel(value) { return kb.tabs.find(t => t.value === value)?.label ?? value; }

  // the sections in order, each { name, binds }: the tab's own, or with a search
  // every tab's matches, their sections named "Tab · Section"
  readonly property var sections: {
    const out = [];
    const index = {};
    for (const b of kb.binds) {
      if (q === "" && b.tab !== tab) continue;
      const name = q === "" ? b.section : tabLabel(b.tab) + " · " + b.section;
      if (q !== "" && (name + " " + b.what + " " + b.keys.join(" ")).toLowerCase().indexOf(q) < 0) continue;
      if (index[name] === undefined) {
        index[name] = out.length;
        out.push({ name: name, binds: [] });
      }
      out[index[name]].binds.push(b);
    }
    return out;
  }

  function step(d) {
    if (kb.tabs.length === 0) return;
    const i = kb.tabs.findIndex(t => t.value === tab);
    const current = i < 0 ? 0 : i;
    tab = kb.tabs[(current + d + kb.tabs.length) % kb.tabs.length].value;
  }

  // opened: the settings' tab, the search cleared (if so set), the English layout, the binds read again
  function reset() {
    tab = opens;
    if (clearOnClose) query = "";
    if (english) Hypr.englishLayout();
    kb.refresh();
    field.input.forceActiveFocus();
  }


  KitInput {
    id: field
    width: parent.width
    placeholder: "Search keys, actions, sections…"
    text: root.query
    onTextEdited: root.query = text

    input.Keys.onPressed: event => {
      const k = event.key;
      if (k === Qt.Key_Escape) root.back();
      else if (k === Qt.Key_Backtab || (k === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) root.step(-1);
      else if (k === Qt.Key_Tab) root.step(1);
      else return;
      event.accepted = true;
    }
  }

  KitChoices {
    width: parent.width
    stretch: true
    model: root.kb.tabs
    current: root.tab
    onPicked: value => { root.tab = value; field.input.forceActiveFocus(); }
  }

  KitLine {}

  Flickable {
    width: parent.width
    height: root.rows * 44
    clip: true
    contentHeight: list.height
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: list
      width: parent.width
      spacing: Theme.gapGroup

      KitText {
        width: parent.width
        visible: root.tab === "mode" && root.q === ""
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 2
        text: root.kb.mode.toUpperCase() + " MODE · ITS KEYS, GESTURES AND THE ARROWS IF SET"
      }

      Repeater {
        model: root.sections

        Column {
          id: section

          required property var modelData
          required property int index

          width: list.width
          spacing: Theme.gapGroup

          KitLabel {
            text: section.modelData.name.toUpperCase()
            value: String(section.modelData.binds.length)
          }

          Repeater {
            model: section.modelData.binds

            KitRow {
              required property var modelData

              label: modelData.what

              Repeater {
                model: modelData.keys

                KeyCap {
                  required property string modelData
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData
                }
              }
            }
          }

          KitLine { visible: section.index < root.sections.length - 1 }
        }
      }

      KitText {
        width: parent.width
        visible: root.sections.length === 0
        text: root.kb.error !== "" ? root.kb.error : "Nothing matches"
        color: root.kb.error !== "" ? Theme.red : Theme.muted
      }
    }
  }

  KitLine {}

  KitText {
    width: parent.width
    horizontalAlignment: Text.AlignRight
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 2
    text: "tab next tab · esc close"
  }
}
