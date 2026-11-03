import QtQuick
import qs.apps.shellmanager
import qs.components
import qs.config
import qs.kit

// Themes, two views (Modules › Themes › View; auto: cards in the island, the
// list on the strip):
//   cards — a strip of cards, one per theme: its background, its palette as
//           dots, its name in its own text colour; the ends fade out;
//   list  — the classic popup: header, search, rows with a small palette.
// Both: a search field on top (English layout on open, an option); arrows (and the wheel, an option) move the
// pick, Enter or a click switches to it. The active theme has a check. In the
// island the cards go bare (no header, no footer), as the island frames them.
KitFrame {
  id: root

  readonly property var dots: ["red", "orange", "yellow", "green", "aqua", "blue", "purple"]
  readonly property string query: search.text.trim().toLowerCase()
  readonly property var matches: ThemeService.inMode.filter(t => query === "" || t.toLowerCase().includes(query))

  readonly property string viewOption: ModuleSettings.get("themes", "view", "auto")
  readonly property bool cards: viewOption === "cards" || (viewOption === "auto" && inIsland)
  // the cards alone in the island go bare (no header, no footer); the list keeps its frame
  readonly property bool bare: inIsland && cards
  readonly property bool wheel: ModuleSettings.get("themes", "wheel", true)

  // the pick: an index in `matches`
  property int current: 0
  readonly property string picked: matches[current] ?? ""

  function colorOf(theme, role) { return ThemeService.colors[theme]?.[role] ?? Theme[role]; }

  function move(step) {
    if (matches.length === 0) return;
    current = Math.max(0, Math.min(matches.length - 1, current + step));
  }

  function take(theme) {
    if (theme !== "" && theme !== ThemeService.current && !ThemeService.busy) ThemeService.apply(theme);
  }

  // the popup came up: a fresh search, the active theme picked and in view
  function shown() {
    if (ModuleSettings.get("themes", "english", true)) Hypr.englishLayout();
    search.text = "";
    search.input.forceActiveFocus();
    ThemeService.refresh();
    current = Math.max(0, matches.indexOf(ThemeService.current));
    center();
    reveal.restart();
  }

  // the pick in the middle of its view, before the view is seen: a move after
  // it shows reads as the strip jumping
  function center() {
    const view = root.cards ? strip : rows;
    view.forceLayout();
    view.positionViewAtIndex(root.current, ListView.Center);
  }

  // the content settles (moved into the island, sized) a moment after it shows
  Timer {
    id: reveal
    interval: 60
    onTriggered: root.center()
  }

  onQueryChanged: current = Math.max(0, matches.indexOf(ThemeService.current))

  implicitWidth: cards ? 480 : Theme.modulePopupWidth

  // ---- header (the strip's popup) ----
  KitHeader {
    visible: !root.bare
    icon: "palette"
    title: "Themes"
    subtitle: (ThemeService.current || "—").toUpperCase() + " · " + Format.count(ThemeService.inMode.length, "THEME")

    // the view, switched here and kept (Modules › Themes too)
    Row {
      spacing: Theme.gapHair

      Repeater {
        model: [{ value: "cards", icon: "grid" }, { value: "list", icon: "list" }]

        KitButton {
          required property var modelData
          icon: modelData.icon
          selected: (modelData.value === "cards") === root.cards
          onClicked: ModuleSettings.set("themes", "view", modelData.value)
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
      placeholder: "Search themes" + Theme.ellipsis
      passKeys: root.cards ? [Qt.Key_Left, Qt.Key_Right] : [Qt.Key_Up, Qt.Key_Down]
      onKeyPassed: key => root.move(key === Qt.Key_Left || key === Qt.Key_Up ? -1 : 1)
      onAccepted: root.take(root.picked)
    }

    KitChoices {
      id: switchBare
      visible: root.bare
      model: [{ label: "", value: "cards", icon: "grid" }, { label: "", value: "list", icon: "list" }]
      current: root.cards ? "cards" : "list"
      onPicked: value => ModuleSettings.set("themes", "view", value)
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

      delegate: ThemeCard {
        required property string modelData
        required property int index
        theme: modelData
        page: root
        width: 136
        height: strip.height
        picked: index === root.current
        onClicked: { root.current = index; root.take(modelData); }
      }
    }

    WheelHandler {
      enabled: root.wheel
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: event => root.move(event.angleDelta.y > 0 || event.angleDelta.x > 0 ? -1 : 1)
    }

    // the ends fade into the surface: more cards lie that way
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
    // past the cap the rows scroll: the wheel and the arrows move the pick
    height: Math.min(root.matches.length, Theme.visibleRows) * 32
    clip: true
    model: root.cards ? [] : root.matches
    currentIndex: root.current
    boundsBehavior: Flickable.StopAtBounds
    interactive: false
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

    delegate: Rectangle {
      id: row
      required property string modelData
      required property int index

      readonly property bool active: modelData === ThemeService.current
      readonly property bool picked: index === root.current

      width: rows.width
      height: 32
      radius: Theme.radiusControl
      color: picked ? Theme.selectedFill
        : area.containsMouse ? Theme.background1 : Theme.clear
      Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

      // the palette on the theme's own background
      Rectangle {
        id: palette
        anchors { left: parent.left; leftMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
        width: dotsRow.implicitWidth + 2 * Theme.gapSmall
        height: 18
        radius: Theme.radiusControl
        color: root.colorOf(row.modelData, "background0")
        border.width: Theme.frameWidth
        border.color: Theme.background2

        Row {
          id: dotsRow
          anchors.centerIn: parent
          spacing: Theme.gapHair

          Repeater {
            model: root.dots
            Rectangle {
              required property string modelData
              anchors.verticalCenter: parent.verticalCenter
              width: 7
              height: 7
              radius: Theme.pill(height)
              color: root.colorOf(row.modelData, modelData)
            }
          }
        }
      }

      KitText {
        anchors { left: palette.right; leftMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
        text: row.modelData
        color: row.picked || area.containsMouse ? Theme.foreground0 : Theme.foreground2
        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
        font.weight: row.picked ? Font.ExtraBold : Theme.fontWeight
      }

      KitSpinner {
        anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
        visible: ThemeService.applying === row.modelData
      }

      KitIcon {
        anchors { right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
        visible: row.active && ThemeService.applying !== row.modelData
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
    text: "No theme matches"
    color: Theme.muted
  }

  KitText {
    visible: ThemeService.error !== ""
    width: parent.width
    text: ThemeService.error
    color: Theme.red
    wrapMode: Text.Wrap
  }

  // ---- footer (the strip's popup) ----
  KitLine { visible: !root.bare }

  KitText {
    visible: !root.bare
    text: (root.cards ? "← →" : "↑ ↓") + " pick · enter apply · esc close"
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 2
  }
}
