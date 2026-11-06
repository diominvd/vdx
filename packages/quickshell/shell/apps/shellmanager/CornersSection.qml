import QtQuick
import qs.config
import qs.kit

// Appearance › SHAPE (with IconsSection): sharp or round, for
// the whole shell — popups, windows, controls, rows, the island, the icons (the
// Rounded set). Round sets one radius on a ticked slider; smaller things take a
// share of it (Theme). Separately: a slider per part (windows, cards, controls,
// the bar, the hub), each read in the same proportion. The group's label lives in AppearancePage.
KitColumn {
  id: root

  readonly property var stops: Theme.cornerStops
  readonly property bool round: ShellSettings.corners === "round"

  spacing: Theme.gapGroup


  KitRow {
    wide: true
    label: "Corners"
    hint: "Every part at once, icons too"

    KitSegments {
      model: [
        { label: "Sharp", value: "sharp" },
        { label: "Round", value: "round" }
      ]
      current: ShellSettings.corners
      onPicked: value => ShellSettings.set("corners", value)
    }
  }

  // a radius on the ticks: index <-> px
  function pos(px) { return Math.max(0, stops.indexOf(px)) / (stops.length - 1); }
  function px(p) { return stops[Math.round(p * (stops.length - 1))]; }

  // a block that folds: its height glides with `open`, the content clipped and faded. It leaves the
  // layout (and its gap) only once folded; while it glides it carries the gap itself, so nothing jumps
  component Fold: Item {
    id: fold
    property bool open: false
    default property alias content: inner.data
    property real p: open ? 1 : 0
    Behavior on p { enabled: Motion.controls; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
    visible: p > 0
    width: parent.width
    height: p * (inner.childrenRect.height + root.spacing) - root.spacing
    clip: true
    Item {
      id: inner
      width: parent.width
      height: childrenRect.height
      opacity: fold.p
    }
  }

  // the one slider: every part; folded with Separately (turning it off brings this one back)
  Fold {
    open: root.round && !ShellSettings.cornerSplit
    KitSliderRow {
      id: radius
      label: "Radius"
      snaps: root.stops.map((s, i) => i / (root.stops.length - 1))
      value: root.pos(ShellSettings.cornerRadius)
      text: root.px(radius.pressed ? radius.dragValue : radius.value) + " px"
      onMoved: value => {
        const px = root.px(value);
        if (px !== ShellSettings.cornerRadius) ShellSettings.set("cornerRadius", px);
      }
    }
  }

  // the parts, each with the px its R makes (the cards' and the previews' numbers)
  readonly property var parts: [
    { part: "windows",  label: "Windows and popups", short: "Windows",  px: r => r },
    { part: "cards",    label: "Cards and boxes",    short: "Cards",    px: r => Math.round(r * (Theme.material ? 1 : 0.6)) },
    { part: "controls", label: "Controls",           short: "Controls", px: r => Theme.scaled(Theme.controlHeight, r * Theme.softness) },
    { part: "bar",      label: "Bar",                short: "Bar",      px: r => Theme.scaled(Theme.islandHeight, r) },
    { part: "hub",      label: "Hub",                short: "Hub",      px: r => Math.round(r * 1.5) }
  ]

  // the row unfolds the slider per part under it; folded, its hint is what one radius makes of each part
  Item {
    id: splitRow
    visible: root.round
    width: parent.width
    implicitHeight: splitInner.implicitHeight

    Rectangle {
      anchors { fill: parent; leftMargin: -Theme.groupInset; rightMargin: -Theme.groupInset; topMargin: -Theme.settingsRowInset; bottomMargin: -Theme.settingsRowInset }
      radius: Theme.radiusCard
      color: splitArea.containsMouse ? Theme.background2 : Theme.clear
      Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
    }
    KitRow {
      id: splitInner
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      label: "Set each part"
      hint: ShellSettings.cornerSplit ? "Each part has its own radius"
                                      : root.parts.map(p => p.short + " " + p.px(ShellSettings.cornerRadius)).join(" · ")
      KitIcon {
        name: "chevron-down"
        rotation: ShellSettings.cornerSplit ? 0 : -90
        tint: Theme.foreground2
        size: Theme.fontSize + 1
        Behavior on rotation { enabled: Motion.controls; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
      }
    }
    MouseArea {
      id: splitArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: ShellSettings.set("cornerSplit", !ShellSettings.cornerSplit)
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Set each part"
  }

  // a part on its own: the same tick looks the same on every part (the px differ)
  Fold {
    open: root.round && ShellSettings.cornerSplit
    Column {
      width: parent.width
      spacing: root.spacing
      Repeater {
        model: root.parts

        KitSliderRow {
          id: part
          required property var modelData
          readonly property int r: ShellSettings.cornerRadii[modelData.part] ?? ShellSettings.cornerRadius
          label: modelData.label
          snaps: root.stops.map((s, i) => i / (root.stops.length - 1))
          value: root.pos(r)
          text: modelData.px(root.px(part.pressed ? part.dragValue : part.value)) + " px"
          onMoved: value => {
            const px = root.px(value);
            if (px !== r) ShellSettings.set("cornerRadii", Object.assign({}, ShellSettings.cornerRadii, { [modelData.part]: px }));
          }
        }
      }
    }
  }

  KitGrouper {}
}
