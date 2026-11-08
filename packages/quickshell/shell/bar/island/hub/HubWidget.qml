import QtQuick
import qs.bar.island
import qs.config
import qs.kit

// One renderer for the live grid, gallery previews and the moving drag item.
Item {
  id: root
  required property var hub
  required property var widget
  property bool preview: false
  property bool thumbnail: false
  enabled: !preview
  readonly property bool control: HubWidgets.sliderIds.includes(widget.id) && widget.fmt === "Tall"
  readonly property bool tile: HubWidgets.isModule(widget.id) && HubWidgets.formats(widget.id).includes("M") && widget.fmt !== "Chip"
  implicitHeight: content.item?.implicitHeight || Theme.controlHeight + 2 * Theme.gapSmall
  Loader {
    id: content
    anchors.fill: parent
    property string fmt: root.widget.fmt
    sourceComponent: root.control ? controlView : root.widget.fmt === "Day" ? dayView
      : HubWidgets.isModule(root.widget.id) ? (root.tile ? tileView : chipView) : root.hub.blockOf(root.widget.id)
  }
  Component { id: controlView; HubControl { widgetId: root.widget.id; fmt: root.widget.fmt; preview: root.preview } }
  Component { id: tileView; HubTileCell { hub: root.hub; widget: root.widget; preview: root.preview } }
  Component { id: chipView; HubChipCell { hub: root.hub; widget: root.widget; preview: root.preview } }
  Component {
    id: dayView
    Rectangle {
      implicitHeight: 128
      radius: Theme.radiusCard
      color: Theme.controlFill
      border.width: Theme.frameWidth
      border.color: Theme.controlLineRest
      Column {
        anchors { fill: parent; margins: Theme.gapWide }
        spacing: Theme.gapSmall
        KitText { text: Qt.formatDateTime(root.hub.now, "MMM · yyyy").toUpperCase(); font.pixelSize: Theme.fontSize - 3; color: Theme.muted }
        KitText { text: Qt.formatDateTime(root.hub.now, "dd"); font.pixelSize: Theme.fontSize + 28; font.weight: Font.DemiBold }
        KitText { text: "П В С Ч П С В"; font.pixelSize: Theme.fontSize - 3; color: Theme.muted }
      }
      MouseArea { anchors.fill: parent; enabled: !root.preview; cursorShape: Qt.PointingHandCursor; onClicked: root.hub.calendarOpen = true }
    }
  }
}
