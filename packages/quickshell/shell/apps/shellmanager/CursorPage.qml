import QtQuick
import qs.config
import qs.kit
import "../../kit/colour.js" as Colour

// Cursor, in the Themes frame: the cursor themes on the left (a name, a check on the one
// in use), the picked one's shapes on the right in the chosen colour, its colour and size
// at the foot of that card. A pick (or a colour) is previewed and waits for Apply (it may
// download the theme).
KitPicker {
  id: root

  // short names: "Bibata-Modern-Classic" reads "Bibata Classic", "phinger-cursors-dark" "phinger dark"
  function cursorLabel(name) {
    return name.replace(/-/g, " ").replace("Modern ", "").replace(" cursors", "").replace("Original Classic", "Original");
  }

  // the cursor in the preview and its colour; Apply makes them the system's
  property string cursorChoice: ""
  readonly property string cursorSelected: cursorChoice !== "" ? cursorChoice : CursorService.base
  property string cursorMode: CursorService.mode
  property int cursorSize: CursorService.size
  property string cursorCustom: CursorService.mode === "custom" ? CursorService.fill : "d8a657"
  readonly property var cursorRow: CursorService.cursors.find(c => c.name === cursorSelected) ?? null
  readonly property bool cursorCustomValid: /^[0-9a-f]{6}$/.test(cursorCustom)
  readonly property bool cursorChanged: cursorSelected !== CursorService.base || cursorMode !== CursorService.mode || cursorSize !== CursorService.size
                                        || (cursorMode === "custom" && cursorCustom !== CursorService.fill)
  // the preview follows the selection (a theme-coloured one, the theme too)
  readonly property string cursorPreviewKey: cursorRow && cursorRow.installed
    ? [cursorSelected, cursorMode, cursorCustomValid ? cursorCustom : "", CursorService.themeColours].join(" ") : ""
  onCursorPreviewKeyChanged: if (cursorPreviewKey !== "" && (cursorMode !== "custom" || cursorCustomValid))
    CursorService.preview(cursorSelected, cursorMode, cursorCustom)

  function resetCursor() {
    cursorChoice = "";
    cursorMode = CursorService.mode;
    cursorSize = CursorService.size;
    cursorCustom = CursorService.mode === "custom" ? CursorService.fill : "d8a657";
  }
  function applyCursor() {
    if (!cursorRow || !cursorChanged || CursorService.busy || (cursorMode === "custom" && !cursorCustomValid)) return;
    CursorService.apply(cursorRow, cursorSize, cursorMode, cursorCustom);
  }

  readonly property string icon: "cursor"
  readonly property string title: "Cursor"
  readonly property string description: "The pointer's theme, colour and size."
  readonly property var jumps: [{ key: "style", label: "Style", y: head.y }]
  readonly property bool pending: cursorChanged

  selected: cursorSelected
  marked: CursorService.base
  busyKey: CursorService.working
  placeholder: "Search cursors"
  emptyIcon: "cursor"
  emptyTitle: "No matching cursors"
  model: {
    const out = [];
    for (const c of CursorService.cursors) if (c.installed) out.push({ key: c.name, label: cursorLabel(c.name), sub: "Installed", section: "INSTALLED" });
    for (const c of CursorService.cursors) if (!c.installed) out.push({ key: c.name, label: cursorLabel(c.name), sub: "Download to use", section: "AVAILABLE", available: true });
    return out;
  }
  onPicked: key => cursorChoice = key
  onActivated: applyCursor()
  onEscaped: resetCursor()
  Connections { target: CursorService; function onBaseChanged() { root.cursorChoice = ""; } }
  // the Loader makes the page already visible: the first show is not a change
  Component.onCompleted: visibleChanged()
  onVisibleChanged: if (visible) search.input.forceActiveFocus()

  // ---- head with its options, then the scene ----
  KitPickerHead {
    id: head
    title: root.cursorRow ? root.cursorLabel(root.cursorRow.name) : "Cursor"
    phase: !root.cursorRow ? "loading" : CursorService.busy ? "busy" : !root.cursorChanged ? "inuse"
         : root.cursorRow.installed ? "preview" : "missing"
    busyText: root.cursorRow && root.cursorRow.installed ? "Applying…" : "Downloading…"
    actions: [
      KitButton { visible: root.cursorChanged || CursorService.busy; text: "Cancel"; disabled: CursorService.busy; onClicked: root.resetCursor() },
      KitButton {
        visible: root.cursorChanged || CursorService.busy
        primary: true
        icon: root.cursorRow && !root.cursorRow.installed ? "download" : "check"
        text: root.cursorRow && !root.cursorRow.installed ? "Download & use" : "Apply"
        busy: CursorService.busy
        disabled: root.cursorRow === null || (root.cursorMode === "custom" && !root.cursorCustomValid)
        onClicked: root.applyCursor()
      }
    ]

    KitLabel { text: "STYLE"; visible: false }      // the search index finds the group by it
    KitPickerOption {
      label: "Colour"
      KitSegments {
        width: parent.width
        model: [{ label: "Original", value: "original" }, { label: "Theme", value: "theme" }, { label: "Colour", value: "custom" }]
        current: root.cursorMode
        onPicked: value => root.cursorMode = value
      }
    }
    KitPickerOption {
      visible: root.cursorMode === "custom"
      label: "Palette"
      Row {
        spacing: Theme.gapMedium
        Repeater {
          model: Theme.colourSet
          Rectangle {
            required property string modelData
            readonly property string hex: Colour.hexOfColour(Theme.accentColour(modelData)).slice(1)
            width: 22; height: 22; radius: 11
            color: Theme.accentColour(modelData)
            border.width: root.cursorCustom === hex ? Theme.ring : 0
            border.color: Theme.foreground0
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cursorCustom = parent.hex }
          }
        }
      }
    }
    KitPickerOption {
      label: "Size"
      KitSegments {
        width: parent.width
        model: [20, 24, 28, 32, 40].map(n => ({ label: String(n), value: n }))
        current: root.cursorSize
        onPicked: value => root.cursorSize = value
      }
    }
  }

  Rectangle {
    id: well
    readonly property bool ready: root.cursorRow !== null && root.cursorRow.installed
                                  && CursorService.shapesKey === CursorService.wantedKey
    width: parent.width
    height: parent.height - y - (err.visible ? err.height + parent.spacing : 0)
    radius: Theme.radiusCard
    color: Theme.background0
    border.width: Theme.hairline
    border.color: Theme.controlLine
    clip: true

    CursorScene {
      visible: well.ready
      anchors { fill: parent; margins: Theme.gapGroup }
      size: root.cursorSize
    }
    KitSpinner { anchors.centerIn: parent; visible: root.cursorRow !== null && root.cursorRow.installed && !well.ready }
    KitEmptyState {
      anchors.fill: parent
      visible: root.cursorRow !== null && !root.cursorRow.installed
      centered: true
      icon: ""
      title: "Preview after download"
      hint: "Not on this machine yet"
    }
  }

  KitText { id: err; visible: CursorService.error !== ""; width: parent.width; text: CursorService.error; color: Theme.red; wrapMode: Text.WordWrap; font.pixelSize: Theme.fontSize - 1 }
}
