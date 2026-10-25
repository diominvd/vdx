import QtQuick
import qs.config
import qs.kit

// Cursor: the picked cursor's shapes large, in the chosen colour; its colour and
// size; then a card per cursor theme. A pick (or a colour) is previewed and waits
// for Apply (it may download the theme); the size applies at once.
// Linked from Appearance › Style.
KitColumn {
  id: root

  // short names: "Bibata-Modern-Classic" reads "Bibata Classic", "phinger-cursors-dark" "phinger dark"
  function cursorLabel(name) {
    return name.replace(/-/g, " ").replace("Modern ", "").replace(" cursors", "").replace("Original Classic", "Original");
  }

  // the cursor in the preview and its colour; Apply makes them the system's
  property string cursorSelected: CursorService.base
  property string cursorMode: CursorService.mode
  property string cursorCustom: CursorService.mode === "custom" ? CursorService.fill : "d8a657"
  readonly property var cursorRow: CursorService.cursors.find(c => c.name === cursorSelected) ?? null
  readonly property bool cursorCustomValid: /^[0-9a-f]{6}$/.test(cursorCustom)
  readonly property bool cursorChanged: cursorSelected !== CursorService.base || cursorMode !== CursorService.mode
                                        || (cursorMode === "custom" && cursorCustom !== CursorService.fill)
  // the preview follows the selection (a theme-coloured one, the theme too)
  readonly property string cursorPreviewKey: cursorRow && cursorRow.installed
    ? [cursorSelected, cursorMode, cursorCustomValid ? cursorCustom : "", CursorService.themeColours].join(" ") : ""
  onCursorPreviewKeyChanged: if (cursorPreviewKey !== "" && (cursorMode !== "custom" || cursorCustomValid))
    CursorService.preview(cursorSelected, cursorMode, cursorCustom)

  function resetCursor() {
    cursorSelected = CursorService.base;
    cursorMode = CursorService.mode;
    cursorCustom = CursorService.mode === "custom" ? CursorService.fill : "d8a657";
  }

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "cursor"
  readonly property string title: "Cursor"
  readonly property string subtitle: cursorLabel(CursorService.base).toUpperCase() + " · " + CursorService.mode.toUpperCase() + " · " + CursorService.size
  readonly property var jumps: []

  readonly property int columns: width >= 600 ? 3 : 2
  readonly property int gap: Theme.gapGroup

  // ---- the picked cursor: its shapes, Apply when changed ----
  KitLabel { text: "PREVIEW" }

  Rectangle {
    id: well

    readonly property bool ready: root.cursorRow !== null && root.cursorRow.installed
                                  && CursorService.shapesKey === CursorService.wantedKey

    width: parent.width
    height: 104
    radius: Theme.radiusControl
    color: Theme.background0

    Row {
      anchors.centerIn: parent
      visible: well.ready
      spacing: Theme.gapGroup * 2

      Repeater {
        model: CursorService.shapes

        Image {
          required property var modelData
          width: 44
          height: 44
          source: "file://" + modelData.path + "?" + CursorService.shapesKey
          sourceSize: Qt.size(modelData.width, modelData.height)
          cache: false
          smooth: true
        }
      }
    }

    KitSpinner {
      anchors.centerIn: parent
      visible: root.cursorRow !== null && root.cursorRow.installed && !well.ready
    }

    KitText {
      anchors.centerIn: parent
      visible: root.cursorRow !== null && !root.cursorRow.installed
      color: Theme.muted
      text: "Not installed yet: Apply downloads it"
    }
  }

  KitRow {
    visible: root.cursorChanged
    label: "Use " + (root.cursorRow ? root.cursorLabel(root.cursorRow.name) : "")
    hint: root.cursorRow && !root.cursorRow.installed ? "Downloads it first" : "For every app"

    KitButton {
      text: "Cancel"
      disabled: CursorService.busy
      onClicked: root.resetCursor()
    }

    KitButton {
      icon: root.cursorRow && !root.cursorRow.installed ? "download" : "check"
      text: "Apply"
      busy: CursorService.busy
      disabled: root.cursorRow === null || (root.cursorMode === "custom" && !root.cursorCustomValid)
      onClicked: CursorService.apply(root.cursorRow, CursorService.size, root.cursorMode, root.cursorCustom)
    }
  }

  // ---- its look ----
  KitLabel { text: "STYLE" }

  KitRow {
    wide: true
    label: "Colour"
    hint: root.cursorMode === "theme" ? "Follows the theme's colours"
        : root.cursorMode === "custom" ? "Your colour, outlined to stand out" : "As the cursor theme draws it"

    KitSegments {
      accessibleName: "Cursor colour mode"
      model: [
        { label: "Original", value: "original" },
        { label: "Theme",    value: "theme" },
        { label: "Custom",   value: "custom" }
      ]
      current: root.cursorMode
      onPicked: value => root.cursorMode = value
    }
  }

  ColourRow {
    visible: root.cursorMode === "custom"
    value: "#" + root.cursorCustom
    onEdited: text => root.cursorCustom = text.trim().replace(/^#/, "").toLowerCase()
    onAccepted: colour => { if (root.cursorRow) CursorService.apply(root.cursorRow, CursorService.size, "custom", colour.slice(1)); }
  }

  KitRow {
    wide: true
    label: "Size"
    hint: "Pixels at scale 1, applied at once"

    KitSegments {
      accessibleName: "Cursor size"
      model: [20, 24, 28, 32, 40].map(n => ({ label: String(n), value: n }))
      current: CursorService.size
      onPicked: value => CursorService.setSize(value)
    }
  }

  // ---- the cursor themes ----
  KitLabel {
    text: "CURSORS"
    value: CursorService.cursors.filter(c => c.installed).length + " OF " + CursorService.cursors.length + " INSTALLED"
  }

  Grid {
    property bool kitUnboxed: true          // KitGrouper: the cards stand on the page

    width: parent.width
    columns: root.columns
    columnSpacing: root.gap
    rowSpacing: root.gap

    Repeater {
      model: CursorService.cursors

      Rectangle {
        id: card

        required property var modelData
        readonly property bool inUse: modelData.name === CursorService.base
        readonly property bool picked: modelData.name === root.cursorSelected
        readonly property bool working: CursorService.working === modelData.name

        width: (root.width - (root.columns - 1) * root.gap) / root.columns
        height: 64
        radius: Theme.radiusCard
        color: area.containsMouse && !picked ? Theme.background2 : Theme.background1
        border.width: picked ? Theme.ring : area.activeFocus ? Theme.focusRingWidth : Theme.hairline
        border.color: picked ? Theme.foreground0 : area.activeFocus ? Theme.focusRing : Theme.background2
        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

        Column {
          anchors { left: parent.left; leftMargin: Theme.gapGroup; right: mark.left; rightMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
          spacing: Theme.gapTight

          KitText {
            width: parent.width
            elide: Text.ElideRight
            text: root.cursorLabel(card.modelData.name)
            font.weight: card.picked ? Font.ExtraBold : Font.DemiBold
          }

          KitText {
            text: card.working ? "Installing…" : card.inUse ? "In use" : card.modelData.installed ? "Installed" : "Not installed"
            color: card.inUse ? Theme.green : Theme.muted
            font.pixelSize: Theme.fontSize - 2
          }
        }

        Item {
          id: mark
          anchors { right: parent.right; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
          width: 16
          height: 16

          KitSpinner { anchors.centerIn: parent; visible: card.working }
          KitIcon {
            anchors.centerIn: parent
            visible: !card.working && (card.inUse || !card.modelData.installed)
            name: card.inUse ? "check" : "download"
            tint: card.inUse ? Theme.green : Theme.foreground2
            size: Theme.iconSmall
          }
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          activeFocusOnTab: !CursorService.busy
          Accessible.role: Accessible.Button
          Accessible.name: root.cursorLabel(card.modelData.name)
          Accessible.description: card.inUse ? "Currently in use"
            : card.modelData.installed ? "Select this cursor theme" : "Not installed; select it and choose Apply to download"
          cursorShape: Qt.PointingHandCursor
          onClicked: { forceActiveFocus(); root.cursorSelected = card.modelData.name; }
          Keys.onReturnPressed: event => { if (!event.isAutoRepeat) root.cursorSelected = card.modelData.name; event.accepted = true; }
          Keys.onEnterPressed: event => { if (!event.isAutoRepeat) root.cursorSelected = card.modelData.name; event.accepted = true; }
          Keys.onSpacePressed: event => { if (!event.isAutoRepeat) root.cursorSelected = card.modelData.name; event.accepted = true; }
        }
      }
    }
  }

  KitText {
    width: parent.width
    visible: CursorService.error !== ""
    text: CursorService.error
    color: Theme.red
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSize - 1
  }

  KitGrouper {}
}
