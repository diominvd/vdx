import QtQuick
import QtQuick.Controls as Controls
import qs.config
import qs.kit

// Compact layout map and one shared board, following the supplied reference.
Column {
  id: editor
  property bool kitUnboxed: true
  property bool showOverview: true
  property bool showAvailable: true
  property bool island: false
  property bool clockVisible: true
  property string scope: ""
  property var extraZones: []
  property var extraBars: []
  property var idsOf: zone => []
  property var labelOf: id => id
  property var iconOf: id => ""
  property var tileOf: id => false
  property var accepts: (id, zone) => true
  property var zoneLabel: zone => zone
  property string selectedId: ""
  property Flickable scrollViewport: null
  readonly property alias dragBoard: board
  readonly property bool dragging: board.dragId !== ""
  readonly property var mainZones: island ? ["start", "end"].concat(HubBlocks.tilesFirst ? ["tiles", "hub"] : ["hub", "tiles"]) : ["left", "center", "right", "folder"]
  readonly property var zones: mainZones.concat(extraZones, showAvailable ? ["hidden"] : [])
  readonly property var strips: {
    const main = {id: "main", ids: island
      ? idsOf("start").concat(clockVisible ? ["clock"] : [], idsOf("end"))
      : idsOf("left").concat(idsOf("center"), idsOf("right"))};
    const extras = extraZones.map(zone => {
      const bar = extraBars.find(b => zone === "bar:" + b.id);
      return {id: zone, ids: idsOf(zone), side: bar?.side ?? "right", place: bar?.place ?? "island"};
    });
    const before = extras.filter(b => b.side === "left").sort((a,b) => (a.place === "edge" ? 0 : 1) - (b.place === "edge" ? 0 : 1));
    const after = extras.filter(b => b.side !== "left").sort((a,b) => (a.place === "edge" ? 1 : 0) - (b.place === "edge" ? 1 : 0));
    return before.concat([main], after);
  }
  signal moved(string id, string zone, int index)
  signal selected(string id)
  signal removed(string id)
  signal addBarRequested()
  signal addSeparatorRequested()
  signal barChanged(string id, string side, string place)
  signal barRemoved(string id)
  spacing: Theme.gapWide

  FontMetrics { id: previewMetrics; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSize - 2; font.weight: Theme.fontWeight }
  function nameWidth(id) { return String(id).startsWith("sep-") ? 10 : Math.ceil(previewMetrics.advanceWidth(labelOf(id))) + 24; }

  Rectangle {
    id: preview
    visible: editor.showOverview
    width: parent.width
    height: Math.max(48, previewBars.implicitHeight + 20)
    radius: Theme.radiusCard
    color: Theme.background0   // a well inside a box
    Accessible.role: Accessible.Pane
    Accessible.name: "Bar layout overview"
    Flow {
      id: previewBars
      x: 10; y: 10
      width: parent.width - 20
      spacing: Theme.gapMedium
      Repeater {
        model: editor.strips
        Rectangle {
          id: strip
          required property var modelData
          readonly property bool extra: modelData.id !== "main"
          readonly property real naturalWidth: modelData.ids.reduce((n,id) => n + editor.nameWidth(id), 0) + 8
          width: Math.min(previewBars.width, Math.max(36, naturalWidth))
          height: Math.max(28, faces.implicitHeight) + 4
          radius: Theme.radiusControl
          color: Theme.background2
          Flow {
            id: faces
            x: 4; y: 2
            width: parent.width - 8
            Repeater {
              model: strip.modelData.ids
              Rectangle {
                id: face
                required property string modelData
                readonly property bool separator: String(modelData).startsWith("sep-")
                width: Math.min(faces.width, editor.nameWidth(modelData))
                height: 28
                radius: Theme.radiusControl
                color: faceHover.containsMouse || activeFocus ? Theme.pickFill : Theme.clear
                Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.normal; easing.type: Motion.easing } }
                activeFocusOnTab: !separator
                Accessible.role: Accessible.Button
                Accessible.name: "Preview " + editor.labelOf(modelData)
                Accessible.onPressAction: editor.selected(modelData)
                Keys.onReturnPressed: editor.selected(modelData)
                Keys.onSpacePressed: editor.selected(modelData)
                Controls.ToolTip.visible: faceHover.containsMouse || activeFocus
                Controls.ToolTip.text: editor.labelOf(modelData)
                Controls.ToolTip.delay: 350
                KitText { visible: !face.separator; anchors.centerIn: parent; text: editor.labelOf(face.modelData); font.pixelSize: Theme.fontSize - 2 }
                Rectangle { visible: face.separator; anchors.centerIn: parent; width: 1; height: 16; color: Theme.muted }
                MouseArea { id: faceHover; anchors.fill: parent; hoverEnabled: true; onClicked: editor.selected(face.modelData) }
              }
            }
          }
          KitButton {
            visible: strip.extra && (hovered || stripHover.containsMouse)
            anchors { right: parent.right; top: parent.top; rightMargin: -5; topMargin: -5 }
            width: 18; height: 18; icon: "x"
            Accessible.name: "Remove " + editor.zoneLabel(strip.modelData.id)
            onClicked: editor.barRemoved(strip.modelData.id.slice(4))
          }
          MouseArea { id: stripHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton; z: -1 }
        }
      }
      KitButton {
        width: 32; height: 32
        icon: "plus"
        Accessible.name: "Add bar"
        color: hovered ? Theme.pickFill : Theme.accentFor("choices", Theme.background3)
        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.normal; easing.type: Motion.easing } }
        iconTint: Theme.background0
        onClicked: editor.addBarRequested()
      }
    }
  }

  Item {
    width: parent.width
    height: board.height
    Rectangle {
      anchors.fill: parent
      radius: Theme.radiusCard
      color: Theme.groupFill
      border.width: Theme.frameWidth
      border.color: Theme.controlLine
    }
    KitChipBands {
      id: board
      width: parent.width
      joinedRows: true
      countBadges: true
      compactRows: true
      chipHeight: 28
      chipFontSize: Theme.fontSize - 1
      showIcons: true
      scope: editor.scope + ":" + editor.island
      zones: editor.zones
      idsOf: editor.idsOf
      labelOf: editor.labelOf
      iconOf: editor.iconOf
      tileOf: editor.tileOf
      selectedId: editor.selectedId
      accepts: editor.accepts
      scrollViewport: editor.scrollViewport
      lineOf: id => String(id).startsWith("sep-")
      removable: id => id !== "folder" && !editor.idsOf("hidden").includes(id)
      zoneLabel: zone => ({start: "Left", end: "Right", hidden: "Available"})[zone] ?? editor.zoneLabel(zone)
      emptyText: zone => zone === "hidden" ? "Drop a module here to take it off the bar" : "Drag here"
      bandRemovable: zone => zone.startsWith("bar:")
      onBandRemoved: zone => editor.barRemoved(zone.slice(4))
      onInspected: id => editor.selected(id)
      onDropped: (id, zone, index) => editor.moved(id, zone, index)
      onRemoved: id => editor.removed(id)
    }
  }
}
