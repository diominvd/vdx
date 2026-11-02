import QtQuick
import qs.apps.display
import qs.config
import qs.kit

// Preview a family before applying it. Installed and downloadable families
// share a compact list; system scaling is a separate group.
KitColumn {
  id: root
  property string tab: "family"
  readonly property var tabs: [{ label: "Family", value: "family" }, { label: "Text size", value: "size" }]
  function jump(key) { tab = key === "size" ? "size" : "family"; }
  readonly property string icon: "text"
  readonly property string title: "Fonts"
  readonly property string description: "The shell's typeface and text size."
  readonly property var jumps: [
    { key: "preview", label: "Preview", y: previewLabel.y },
    { key: "families", label: "Families", y: familiesLabel.y },
    { key: "size", label: "Text size", y: sizeLabel.y }
  ].filter(j => tab === "size" ? j.key === "size" : j.key !== "size")
  readonly property var resetKeys: ["textSize", "inputAlign"]
  readonly property bool changed: ShellSettings.changed(resetKeys)
  function reset() { ShellSettings.reset(resetKeys); }

  property string selected: FontService.current
  property string query: ""
  property string armed: ""
  readonly property var chosen: FontService.fonts.find(f => f.family === selected) ?? null
  readonly property var shown: FontService.fonts.filter(f => f.installed
    && f.family.toLowerCase().includes(query.trim().toLowerCase()))
  onShownChanged: if (shown.length && !shown.some(f => f.family === selected)) selected = shown[0].family
  readonly property bool drawable: chosen !== null && chosen.installed && Qt.fontFamilies().includes(chosen.family)
  readonly property string previewFamily: drawable ? chosen.family : Theme.fontFamily
  function apply() {
    if (!chosen || FontService.busy || selected === FontService.current) return;
    if (!chosen.installed && armed !== selected) { armed = selected; disarm.restart(); return; }
    armed = "";
    FontService.apply(chosen);
  }
  Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }
  onSelectedChanged: armed = ""
  onVisibleChanged: if (visible) DisplayService.refresh()

  Column {
  spacing: Theme.sectionGap

    width: parent.width; visible: root.tab === "family"
  KitLabel { id: previewLabel; visible: root.shown.length > 0; text: "PREVIEW"; value: root.drawable ? "SELECTED FAMILY" : "INSTALL TO PREVIEW" }
  Rectangle {
    id: fontSpecimen
    property bool kitUnboxed: true
    visible: root.shown.length > 0
    width: parent.width
    height: sample.implicitHeight + 2 * Theme.gapGroup
    radius: Theme.radiusCard
    color: Theme.groupFill
    border.width: Theme.frameWidth
    border.color: Theme.controlLine
    Column {
      id: sample
      x: Theme.gapGroup; y: Theme.gapGroup
      width: parent.width - 2 * Theme.gapGroup
      spacing: Theme.gapMedium
      KitText { width: parent.width; text: root.selected.replace(" Nerd Font", ""); font.family: root.previewFamily; font.pixelSize: Theme.fontSize + 7; elide: Text.ElideRight }
      KitText { width: parent.width; text: "Aa Bb 0123456789 · iIl1 oO0"; font.family: root.previewFamily; font.pixelSize: Theme.fontSize + 3; elide: Text.ElideRight }
      KitText { width: parent.width; text: "~/.dotfiles  {const value = 42;}  => !="; font.family: root.previewFamily; color: Theme.muted; elide: Text.ElideRight }
    }
  }
  KitRow {
    visible: root.shown.length > 0
    label: root.selected === FontService.current ? "Current font" : "Selected font"
    hint: root.selected === FontService.current ? "Used by the shell and system" : root.chosen?.installed ? "Apply when ready" : "Downloads before applying"
    KitButton {
      text: root.armed === root.selected ? "Confirm install" : root.chosen?.installed ? "Apply" : "Install & use"
      icon: root.chosen?.installed ? "check" : "download"
      iconTint: root.chosen?.installed ? Theme.green : Theme.foreground0
      disabled: !root.chosen || root.selected === FontService.current
      busy: FontService.busy
      onClicked: root.apply()
    }
  }
  KitText { visible: FontService.error !== ""; width: parent.width; text: FontService.error; color: Theme.red; wrapMode: Text.WordWrap }
  KitLine {}
  KitLabel { id: familiesLabel; text: "FAMILIES"; value: FontService.fonts.filter(f => f.installed).length + " INSTALLED" }
  Row {
    property bool kitUnboxed: true
    width: parent.width
    KitInput { width: parent.width; icon: "search"; placeholder: "Search installed fonts"; onTextEdited: root.query = text }
  }
  Column {
    property bool kitUnboxed: true
    width: parent.width
    spacing: Theme.gapHair
    Repeater {
      model: root.shown
      Rectangle {
        id: family
        required property var modelData
        readonly property bool picked: modelData.family === root.selected
        readonly property bool inUse: modelData.family === FontService.current
        width: parent.width
        height: 54
        radius: Theme.radiusControl
        color: picked ? Theme.pickFill : area.containsMouse ? Theme.controlHover : Theme.groupFill
        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.normal; easing.type: Motion.easing } }
        border.width: activeFocus ? Theme.focusWidth : Theme.frameWidth
        border.color: activeFocus ? Theme.focusRing : Theme.controlLine
        activeFocusOnTab: true
        Accessible.role: Accessible.RadioButton
        Accessible.name: modelData.family
        Accessible.checkable: true
        Accessible.checked: picked
        function choose() { root.selected = modelData.family; }
        Accessible.onPressAction: choose()
        Keys.onSpacePressed: choose()
        Keys.onReturnPressed: choose()
        Column {
          anchors { left: parent.left; leftMargin: Theme.gapWide; right: mark.left; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
          spacing: Theme.gapTight
          KitText { width: parent.width; text: family.modelData.family.replace(" Nerd Font", ""); font.family: family.modelData.installed && Qt.fontFamilies().includes(family.modelData.family) ? family.modelData.family : Theme.fontFamily; font.weight: family.picked ? Theme.pickWeight : Font.Normal; elide: Text.ElideRight }
          KitText { text: family.inUse ? "In use" : family.modelData.installed ? "Installed" : "Available to install"; color: Theme.muted; font.pixelSize: Theme.fontSize - 1 }
        }
        Row {
          id: mark
          z: 1
          anchors { right: parent.right; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
          spacing: Theme.gapSmall
          KitIcon { anchors.verticalCenter: parent.verticalCenter; name: family.inUse ? "check" : family.modelData.installed ? "text" : "download"; size: Theme.iconSmall; tint: family.inUse ? Theme.green : Theme.foreground2 }
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: family.choose() }
      }
    }
  }
  KitEmptyState { visible: root.shown.length === 0; icon: "text"; title: "No installed fonts match"; hint: "Try a shorter search" }
  KitLine {}
    KitGrouper {}
  }
  Column {
    width: parent.width; visible: root.tab === "size"
  KitLabel { id: sizeLabel; text: "TEXT SIZE" }
  KitRow {
    wide: true; label: "Text size"; hint: "Shell text and controls"
    KitSegments { model: [12, 13, 14, 15].map(n => ({ label: n + " px", value: n })); current: ShellSettings.textSize; onPicked: value => ShellSettings.set("textSize", value) }
  }
  KitRow {
    wide: true; label: "GTK apps text"; hint: "Applied at once, GTK only"
    KitSegments { disabled: DisplayService.busy; model: DisplayService.textScales.map(f => ({ label: Math.round(f * 100) + "%", value: f })); current: DisplayService.textFactor; onPicked: value => DisplayService.setText(value) }
  }
  KitRow {
    wide: true; label: "Input text"; hint: "Where text stands in a field; Auto: left"
    KitSegments { model: [{ label: "Auto", value: "auto" }, { label: "Left", value: "left" }, { label: "Centre", value: "center" }]; current: ShellSettings.inputAlign; onPicked: value => ShellSettings.set("inputAlign", value) }
  }
    KitGrouper {}
  }
  KitGrouper {}
}
