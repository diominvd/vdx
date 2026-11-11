import QtQuick
import qs.apps.display
import qs.config
import qs.kit

// Fonts, in the Themes frame: the families on the left (a sample, the name, a check on
// the one in use; installed first, then those that can be downloaded), the picked one's
// specimen on the right with Apply, the text sizes under it. ↑ / ↓ pick, Enter applies.
KitPicker {
  id: root

  readonly property string icon: "text"
  readonly property string title: "Fonts"
  readonly property string description: "The shell's typeface and text size."
  readonly property var jumps: [{ key: "size", label: "Text size", y: head.y }]
  readonly property var resetKeys: ["textSize"]
  readonly property bool changed: ShellSettings.changed(resetKeys)
  function reset() { ShellSettings.reset(resetKeys); }

  // what the user picked (empty: the font in use); a pick survives the list arriving later
  property string choice: ""
  property string armed: ""
  readonly property var chosen: FontService.fonts.find(f => f.family === selected) ?? null
  // asked once: Qt copies the whole system list on every call
  readonly property var drawable: {
    const set = ({});
    for (const f of Qt.fontFamilies()) set[f] = true;
    return set;
  }
  readonly property string previewFamily: chosen && drawable[chosen.family] ? chosen.family : Theme.fontFamily
  readonly property bool pending: chosen !== null && selected !== FontService.current

  function short(family) { return family.replace(" Nerd Font", ""); }
  function apply() {
    if (!chosen || FontService.busy || !pending) return;
    if (!chosen.installed && armed !== selected) { armed = selected; disarm.restart(); return; }
    armed = "";
    FontService.apply(chosen);
  }
  Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }

  selected: choice !== "" ? choice : FontService.current
  marked: FontService.current
  busyKey: FontService.working
  placeholder: "Search fonts"
  emptyIcon: "text"
  emptyTitle: "No matching fonts"
  model: {
    const out = [];
    for (const f of FontService.fonts) if (f.installed) out.push({ key: f.family, label: short(f.family), sub: "Installed", section: "INSTALLED" });
    for (const f of FontService.fonts) if (!f.installed) out.push({ key: f.family, label: short(f.family), sub: "Download to use", section: "AVAILABLE", available: true });
    return out;
  }
  thumbWidth: 44
  thumb: Component {
    Rectangle {
      property var entry: ({})
      radius: Theme.radiusControl
      color: Theme.background0
      border.width: Theme.hairline
      border.color: Theme.controlLine
      KitText {
        anchors.centerIn: parent
        text: "Ag"
        font.family: root.drawable[parent.entry.key ?? ""] ? parent.entry.key : Theme.fontFamily
        font.pixelSize: Theme.fontSize + 5
        color: Theme.foreground0
      }
    }
  }

  onPicked: key => choice = key
  onActivated: apply()
  onSelectedChanged: armed = ""
  Connections { target: FontService; function onCurrentChanged() { root.choice = ""; } }
  // the Loader makes the page already visible: the first show is not a change
  Component.onCompleted: visibleChanged()
  onVisibleChanged: if (visible) { search.input.forceActiveFocus(); if (DisplayService.textScales.length === 0) DisplayService.refresh(); }

  // ---- the picked family: head with its options, then the specimen card ----
  KitPickerHead {
    id: head
    title: root.chosen ? root.short(root.chosen.family) : "Fonts"
    phase: !root.chosen ? "loading" : FontService.busy && FontService.working === root.selected ? "busy"
         : !root.pending ? "inuse" : root.chosen.installed ? "preview" : "missing"
    busyText: root.chosen && root.chosen.installed ? "Applying…" : "Downloading…"
    actions: [
      KitButton { visible: root.pending && !FontService.busy; text: "Cancel"; onClicked: root.choice = "" },
      KitButton {
        visible: root.pending || FontService.busy
        primary: true
        text: root.armed === root.selected ? "Confirm download" : root.chosen && !root.chosen.installed ? "Download & use" : "Apply"
        icon: root.chosen && !root.chosen.installed ? "download" : "check"
        busy: FontService.busy
        onClicked: root.apply()
      }
    ]

    KitLabel { text: "TEXT SIZE"; visible: false }      // the search index finds the group by it
    KitPickerOption {
      label: "Text size"
      KitSegments { width: parent.width; model: [12, 13, 14, 15].map(n => ({ label: n + " px", value: n })); current: ShellSettings.textSize; onPicked: value => ShellSettings.set("textSize", value) }
    }
    KitPickerOption {
      label: "GTK apps"
      KitSegments { width: parent.width; disabled: DisplayService.busy || DisplayService.textScales.length === 0; model: DisplayService.textScales.map(f => ({ label: Math.round(f * 100) + "%", value: f })); current: DisplayService.textFactor; onPicked: value => DisplayService.setText(value) }
    }
  }

  Rectangle {
    id: well
    width: parent.width
    height: parent.height - y - (err.visible ? err.height + parent.spacing : 0)
    radius: Theme.radiusCard
    color: Theme.background0
    border.width: Theme.hairline
    border.color: Theme.controlLine
    clip: true

    Flickable {
      id: specimen
      anchors.fill: parent
      contentWidth: width
      contentHeight: sheet.implicitHeight + 2 * Theme.gapGroup
      interactive: contentHeight > height
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      visible: root.chosen !== null && root.drawable[root.chosen.family] === true

      Column {
        id: sheet
        x: Theme.gapGroup; y: Theme.gapGroup
        width: specimen.width - 2 * Theme.gapGroup
        spacing: Theme.gapWide

        // the face at display size
        Row {
          spacing: Theme.gapGroup
          KitText { text: "Ag"; font.family: root.previewFamily; font.pixelSize: 72; color: Theme.foreground0 }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: sheet.width - 72 * 1.4 - Theme.gapGroup
            spacing: Theme.gapHair
            KitText { width: parent.width; text: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"; font.family: root.previewFamily; font.pixelSize: 13; color: Theme.foreground2; elide: Text.ElideRight }
            KitText { width: parent.width; text: "abcdefghijklmnopqrstuvwxyz"; font.family: root.previewFamily; font.pixelSize: 13; color: Theme.foreground2; elide: Text.ElideRight }
            KitText { width: parent.width; text: "0123456789 {}[]()<>=!&|@#$"; font.family: root.previewFamily; font.pixelSize: 13; color: Theme.foreground2; elide: Text.ElideRight }
          }
        }

        KitLine { sectionBreak: false }

        // code at the shell's own text size
        Column {
          spacing: Theme.gapHair
          Repeater {
            model: [
              [["~/.dotfiles ", "blue"], ["main ", "purple"], ["❯ ", "green"], ["git status -sb", "foreground1"]],
              [["def ", "red"], ["apply", "green"], ["(", "foreground1"], ["name", "blue"], [": ", "foreground1"], ["str", "yellow"], [") -> ", "foreground1"], ["bool", "yellow"], [":", "foreground1"]],
              [["    colours ", "foreground1"], ["= ", "orange"], ["load", "aqua"], ["(", "foreground1"], ["f\"themes/{name}\"", "green"], [")", "foreground1"]],
              [["M ", "yellow"], ["install.py   ", "foreground1"], ["A ", "green"], ["FontsPage.qml   ", "foreground1"], ["D ", "red"], ["Display.qml", "foreground1"]]
            ]
            Row {
              required property var modelData
              Repeater {
                model: parent.modelData
                Text {
                  required property var modelData
                  text: modelData[0]
                  color: Theme[modelData[1]]
                  font.family: root.previewFamily
                  font.pixelSize: Theme.fontSize
                }
              }
            }
          }
        }

        KitLine { sectionBreak: false }

        KitText { width: parent.width; text: "=> != === -> <= >=  ·  iIl1 oO0 rn m"; font.family: root.previewFamily; font.pixelSize: Theme.fontSize + 2; elide: Text.ElideRight }
      }
    }

    KitEmptyState {
      anchors.fill: parent
      visible: root.chosen !== null && !specimen.visible
      icon: "download"; title: "Preview after download"; hint: "The shell restarts after it is downloaded"
    }
    KitSpinner { anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; visible: FontService.fonts.length === 0 }
  }

  KitText { id: err; visible: FontService.error !== ""; width: parent.width; text: FontService.error; color: Theme.red; wrapMode: Text.WordWrap }
}
