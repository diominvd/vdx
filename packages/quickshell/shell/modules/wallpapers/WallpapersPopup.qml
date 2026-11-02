import QtQuick
import Quickshell.Widgets
import qs.apps.shellmanager
import qs.components
import qs.config
import qs.kit

// Wallpapers of the active theme, then common/, two views (Modules › Wallpapers
// › View; auto: cards in the island, the list on the strip):
//   cards — a strip of pictures, the ends fade out;
//   list  — the header, a search, rows with a small picture and the name.
// Both: a search on top (English layout on open, an option); arrows (and the
// wheel, an option) move the pick, Enter or a click sets it. The picture in use
// has a check. In the island the cards go bare, as the island frames them.
KitFrame {
  id: root

  readonly property string query: search.text.trim().toLowerCase()
  readonly property var matches: WallpaperService.pictures.filter(p => query === "" || p.name.toLowerCase().includes(query))

  readonly property string viewOption: ModuleSettings.get("wallpapers", "view", "auto")
  readonly property bool cards: viewOption === "cards" || (viewOption === "auto" && inIsland)
  // the cards alone in the island go bare (no header, no footer); the list keeps its frame
  readonly property bool bare: inIsland && cards
  readonly property bool wheel: ModuleSettings.get("wallpapers", "wheel", true)

  // the pick: an index in `matches`
  property int current: 0
  readonly property var picked: matches[current] ?? null

  // the popup is open: the pick shows on the desktop (WallpaperService.preview); Enter sets it
  property bool live: false
  onPickedChanged: if (live && picked) WallpaperService.preview(picked.rel)
  onLiveChanged: if (!live) WallpaperService.endPreview(); else if (picked) WallpaperService.preview(picked.rel)

  function move(step) {
    if (matches.length === 0) return;
    current = Math.max(0, Math.min(matches.length - 1, current + step));
  }

  function take(item) {
    if (item && item.rel !== WallpaperService.inUse) WallpaperService.choose(ThemeService.current, item.rel);
  }

  // the picture in use, or the first one, is picked and in view
  function pickInUse() {
    current = Math.max(0, matches.findIndex(p => p.rel === WallpaperService.inUse));
  }

  // the popup came up: a fresh search, the picture in use picked and in view
  function shown() {
    if (ModuleSettings.get("wallpapers", "english", true)) Hypr.englishLayout();
    search.text = "";
    search.input.forceActiveFocus();
    pickInUse();
    reveal.restart();
  }

  // the content settles (moved into the island, sized) a moment after it shows
  Timer {
    id: reveal
    interval: 60
    onTriggered: (root.cards ? strip : rows).positionViewAtIndex(root.current, ListView.Center)
  }

  onQueryChanged: pickInUse()

  implicitWidth: cards ? 480 : Theme.modulePopupWidth

  // ---- header (the strip's popup) ----
  KitHeader {
    visible: !root.bare
    icon: "image"
    title: "Wallpapers"
    subtitle: (WallpaperService.inUse.split("/").pop() || "—").toUpperCase() + " · " + WallpaperService.pictures.length + " PICTURES"

    // the view, switched here and kept (Modules › Wallpapers too)
    Row {
      spacing: Theme.gapHair

      Repeater {
        model: [{ value: "cards", icon: "grid" }, { value: "list", icon: "list" }]

        KitButton {
          required property var modelData
          icon: modelData.icon
          selected: (modelData.value === "cards") === root.cards
          onClicked: ModuleSettings.set("wallpapers", "view", modelData.value)
        }
      }
    }
  }

  KitLine { visible: !root.bare }

  // the search and, in the island's bare cards (no header), the view switch: one row
  Row {
    width: parent.width
    spacing: Theme.gapSmall

    KitInput {
      id: search
      width: parent.width - (switchBare.visible ? switchBare.width + Theme.gapSmall : 0)
      placeholder: "Search pictures" + Theme.ellipsis
      passKeys: root.cards ? [Qt.Key_Left, Qt.Key_Right] : [Qt.Key_Up, Qt.Key_Down]
      onKeyPassed: key => root.move(key === Qt.Key_Left || key === Qt.Key_Up ? -1 : 1)
      onAccepted: root.take(root.picked)
    }

    KitChoices {
      id: switchBare
      visible: root.bare
      model: [{ label: "", value: "cards", icon: "grid" }, { label: "", value: "list", icon: "list" }]
      current: root.cards ? "cards" : "list"
      onPicked: value => ModuleSettings.set("wallpapers", "view", value)
    }
  }

  // ---- cards ----
  Item {
    visible: root.cards && root.matches.length > 0
    width: parent.width
    height: 84

    ListView {
      id: strip
      anchors.fill: parent
      orientation: ListView.Horizontal
      spacing: Theme.gapMedium
      clip: true
      model: root.cards ? root.matches : []
      currentIndex: root.current
      highlightFollowsCurrentItem: false
      boundsBehavior: Flickable.StopAtBounds
      interactive: false
      onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

      delegate: WallpaperCard {
        required property var modelData
        required property int index
        path: modelData.path
        inUse: modelData.rel === WallpaperService.inUse
        picked: index === root.current
        width: 136
        height: strip.height
        onClicked: { root.current = index; root.take(modelData); }
      }
    }

    WheelHandler {
      enabled: root.wheel
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: event => root.move(event.angleDelta.y > 0 || event.angleDelta.x > 0 ? -1 : 1)
    }

    // the ends fade into the surface: more pictures lie that way
    Rectangle {
      anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
      width: 28
      visible: !strip.atXBeginning
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Theme.background0 }
        GradientStop { position: 1; color: Theme.clear }
      }
    }
    Rectangle {
      anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
      width: 28
      visible: !strip.atXEnd
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Theme.clear }
        GradientStop { position: 1; color: Theme.background0 }
      }
    }
  }

  // ---- list ----
  ListView {
    id: rows
    visible: !root.cards
    width: parent.width
    height: Math.min(root.matches.length, Theme.visibleRows) * 32
    clip: true
    model: root.cards ? [] : root.matches
    currentIndex: root.current
    boundsBehavior: Flickable.StopAtBounds
    interactive: false
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

    delegate: Rectangle {
      id: row
      required property var modelData
      required property int index

      readonly property bool active: modelData.rel === WallpaperService.inUse
      readonly property bool picked: index === root.current

      width: rows.width
      height: 32
      radius: Theme.radiusControl
      color: picked ? Theme.selectedFill
        : area.containsMouse ? Theme.background1 : Theme.clear
      Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

      // a small picture, cropped, framed like the swatches
      ClippingRectangle {
        id: thumb
        anchors { left: parent.left; leftMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
        width: 40
        height: 24
        radius: Theme.radiusControl
        color: Theme.background1
        border.width: Theme.frameWidth
        border.color: Theme.background2

        Image {
          anchors.fill: parent
          source: "file://" + row.modelData.path
          sourceSize: Qt.size(80, 48)
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
        }
      }

      KitText {
        anchors { left: thumb.right; leftMargin: Theme.gapWide; right: check.left; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
        text: row.modelData.name
        elide: Text.ElideRight
        color: row.picked || area.containsMouse ? Theme.foreground0 : Theme.foreground2
        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
        font.weight: row.picked ? Font.ExtraBold : Theme.fontWeight
      }

      KitIcon {
        id: check
        anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
        visible: row.active
        name: "check"
        tint: Theme.green
        size: Theme.iconSmall
      }

      MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.current = row.index; root.take(row.modelData); }
      }
    }

    WheelHandler {
      enabled: root.wheel
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: event => root.move(event.angleDelta.y > 0 ? -1 : 1)
    }
  }

  KitText {
    visible: root.matches.length === 0
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    text: WallpaperService.pictures.length === 0 ? "No pictures in this theme or common" : "No picture matches"
    color: Theme.muted
  }

  KitText {
    visible: WallpaperService.error !== ""
    width: parent.width
    text: WallpaperService.error
    color: Theme.red
    wrapMode: Text.Wrap
  }

  // ---- footer (the strip's popup) ----
  KitLine { visible: !root.bare }

  KitText {
    visible: !root.bare
    text: (root.cards ? "← →" : "↑ ↓") + " pick · enter set · esc close"
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 2
  }
}
