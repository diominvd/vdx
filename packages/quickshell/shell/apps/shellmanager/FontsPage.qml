import QtQuick
import qs.apps.display
import qs.config
import qs.kit

// Fonts: the shell's text size, then a card per monospace font, each written
// in itself. A click on an installed one makes it the system font at once; one
// not installed yet asks first (a download, then the shell restarts).
// Linked from Appearance › Style.
KitColumn {
  id: root

  property string armed: ""                 // a font to download: the second click goes

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "text"
  readonly property string title: "Fonts"
  readonly property string subtitle: FontService.current.replace(" Nerd Font", "").toUpperCase() + " · " + ShellSettings.textSize + " PX"
  readonly property var jumps: []

  // the header's Reset: the text size back to its default (the font is the system's: picked, not reset)
  readonly property var resetKeys: ["textSize"]
  readonly property bool changed: ShellSettings.changed(resetKeys)
  function reset() { ShellSettings.reset(resetKeys); }

  readonly property int columns: width >= 600 ? 2 : 1
  readonly property int gap: Theme.gapGroup

  // a font installed after the shell started can't be drawn until it restarts
  function drawable(f) { return f.installed && Qt.fontFamilies().includes(f.family); }

  function chooseFont(f) {
    if (f.family === FontService.current || FontService.busy) return;
    if (!f.installed && armed !== f.family) {
      armed = f.family;
      disarm.restart();
      return;
    }
    armed = "";
    FontService.apply(f);
  }

  onVisibleChanged: if (visible) DisplayService.refresh()

  Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }

  // ---- size ----
  KitLabel { text: "TEXT" }

  // the shell's own text (Theme.fontSize); larger stops at 15: the bar's and rows' heights are fixed
  KitRow {
    wide: true
    label: "Text size"
    hint: "The shell's own text"

    KitSegments {
      accessibleName: "Shell text size"
      model: [12, 13, 14, 15].map(n => ({ label: n + " px", value: n }))
      current: ShellSettings.textSize
      onPicked: value => ShellSettings.set("textSize", value)
    }
  }

  // GTK apps' text: a factor of their default size (gsettings, display.py)
  KitRow {
    wide: true
    label: "GTK apps text"
    hint: "Applied at once, GTK only"

    KitSegments {
      accessibleName: "GTK application text scale"
      disabled: DisplayService.busy
      model: DisplayService.textScales.map(f => ({ label: Math.round(f * 100) + "%", value: f }))
      current: DisplayService.textFactor
      onPicked: value => DisplayService.setText(value)
    }
  }

  // ---- the fonts ----
  KitLabel {
    text: "FONT"
    value: FontService.fonts.filter(f => f.installed).length + " OF " + FontService.fonts.length + " INSTALLED"
  }

  Grid {
    property bool kitUnboxed: true          // KitGrouper: the cards stand on the page

    width: parent.width
    columns: root.columns
    columnSpacing: root.gap
    rowSpacing: root.gap

    Repeater {
      model: FontService.fonts

      Rectangle {
        id: card

        required property var modelData
        readonly property bool active: modelData.family === FontService.current
        readonly property bool working: FontService.working === modelData.family
        readonly property bool drawable: root.drawable(modelData)
        readonly property string face: drawable ? modelData.family : Theme.fontFamily

        width: (root.width - (root.columns - 1) * root.gap) / root.columns
        height: 112
        radius: Theme.radiusCard
        color: area.containsMouse && !active ? Theme.background2 : Theme.background1
        border.width: area.activeFocus ? Theme.focusRingWidth : active ? Theme.ring : Theme.hairline
        border.color: area.activeFocus ? Theme.focusRing : active ? Theme.foreground0 : Theme.background2
        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

        // the specimen: a large Aa, the name, a line of code
        KitText {
          id: aa
          x: Theme.gapGroup
          y: Theme.gapWide
          text: "Aa"
          font.family: card.face
          font.pixelSize: 34
          font.weight: Font.Bold
          color: card.drawable ? Theme.foreground0 : Theme.gray
        }

        Column {
          anchors { left: aa.right; leftMargin: Theme.gapGroup; right: parent.right; rightMargin: Theme.gapGroup; verticalCenter: aa.verticalCenter }
          spacing: Theme.gapTight

          KitText {
            width: parent.width
            elide: Text.ElideRight
            text: card.modelData.family.replace(" Nerd Font", "")
            font.family: card.face
            font.weight: card.active ? Font.ExtraBold : Font.DemiBold
          }

          KitText {
            width: parent.width
            elide: Text.ElideRight
            text: card.working ? "Installing…" : card.active ? "In use" : card.modelData.installed ? "Installed"
                : root.armed === card.modelData.family ? "Sure?" : "Not installed"
            color: card.active ? Theme.green : root.armed === card.modelData.family ? Theme.yellow : Theme.muted
            font.pixelSize: Theme.fontSize - 2
          }
        }

        KitText {
          anchors { left: parent.left; leftMargin: Theme.gapGroup; right: parent.right; rightMargin: Theme.gapGroup; bottom: parent.bottom; bottomMargin: Theme.gapWide }
          elide: Text.ElideRight
          visible: card.drawable
          text: "0123456789 {}[] => != iIl1 oO0 ~/.dotfiles"
          color: Theme.foreground2
          font.family: card.face
        }

        Item {
          anchors { right: parent.right; rightMargin: Theme.gapWide; top: parent.top; topMargin: Theme.gapWide }
          width: 16
          height: 16

          KitSpinner { anchors.centerIn: parent; visible: card.working }
          KitIcon {
            anchors.centerIn: parent
            visible: !card.working && (card.active || !card.modelData.installed)
            name: card.active ? "check" : "download"
            tint: card.active ? Theme.green : Theme.foreground2
            size: Theme.iconSmall
          }
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          activeFocusOnTab: !FontService.busy
          Accessible.role: Accessible.Button
          Accessible.name: card.modelData.family.replace(" Nerd Font", "")
          Accessible.description: card.active ? "Currently in use"
            : card.modelData.installed ? "Select this font" : "Not installed; select twice to install"
          cursorShape: card.active || FontService.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
          onClicked: { forceActiveFocus(); root.chooseFont(card.modelData); }
          Keys.onReturnPressed: event => { if (!event.isAutoRepeat) root.chooseFont(card.modelData); event.accepted = true; }
          Keys.onEnterPressed: event => { if (!event.isAutoRepeat) root.chooseFont(card.modelData); event.accepted = true; }
          Keys.onSpacePressed: event => { if (!event.isAutoRepeat) root.chooseFont(card.modelData); event.accepted = true; }
        }
      }
    }
  }

  KitText {
    width: parent.width
    visible: FontService.error !== ""
    text: FontService.error
    color: Theme.red
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSize - 1
  }

  KitGrouper {}
}
