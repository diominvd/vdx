import QtQuick
import qs.config
import qs.kit

// The cursor theme, calmly: one shape large on a stage (2×), what it is for under it, and the
// family as a strip of seven cells at the true size. A hover shows a shape on the stage, a click
// keeps it there. Nothing imitates a window: a cursor is judged by its shape and its size.
Item {
  id: root

  property int size: 24                      // the cursor's size in pixels
  readonly property var shapes: CursorService.shapes
  readonly property string key: CursorService.shapesKey
  readonly property var kinds: [
    { name: "default",     label: "Arrow",       use: "Pointing and clicking" },
    { name: "pointer",     label: "Link",        use: "Over links and buttons" },
    { name: "text",        label: "Text",        use: "Over text you can select" },
    { name: "wait",        label: "Busy",        use: "While something loads" },
    { name: "crosshair",   label: "Precise",     use: "Picking a spot or a colour" },
    { name: "grab",        label: "Grab",        use: "Dragging a window" },
    { name: "not-allowed", label: "Unavailable", use: "Over what can't be used now" }
  ]
  property string kept: "default"
  property string hovered: ""
  readonly property string shown: hovered !== "" ? hovered : kept
  readonly property var kind: kinds.find(k => k.name === shown) ?? kinds[0]


  function entry(name) { return shapes.find(s => s.name === name) ?? null; }

  Column {
    id: col
    anchors.fill: parent
    spacing: Theme.gapMedium

    // the stage: the shape on a dark and on a light surface, as large as the card leaves room for
    Row {
      width: parent.width
      height: Math.max(80, col.height - info.height - strip.height - 3 * col.spacing - line.height)
      spacing: Theme.gapMedium
      Repeater {
        model: [{ fill: Theme.background2, name: "Dark" }, { fill: Theme.foreground1, name: "Light" }]
        Rectangle {
          required property var modelData
          width: (parent.width - Theme.gapMedium) / 2
          height: parent.height
          radius: Theme.radiusCard
          color: modelData.fill
          Image {
            readonly property var e: root.entry(root.shown)
            anchors.centerIn: parent
            width: root.size * 2
            height: width
            visible: e !== null
            source: e ? "file://" + e.path + "?" + root.key : ""
            sourceSize: Qt.size(root.size * 4, root.size * 4)
            asynchronous: true
            smooth: true
          }
          KitText { x: Theme.gapSmall; anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.gapSmall; text: modelData.name; color: Theme.muted; font.pixelSize: Theme.fontSize - 2; font.letterSpacing: 1 }
        }
      }
    }

    // its name and where it appears
    Item {
      id: info
      width: parent.width
      height: label.implicitHeight
      Column {
        id: label
        anchors { left: parent.left; right: sizeText.left; rightMargin: Theme.gapMedium }
        spacing: Theme.gapHair
        KitText { width: parent.width; text: root.kind.label; font.weight: Font.Medium; elide: Text.ElideRight }
        KitText { id: use; width: parent.width; text: root.kind.use; color: Theme.hint; font.pixelSize: Theme.fontSize - 1; elide: Text.ElideRight }
      }
      KitText { id: sizeText; anchors.right: parent.right; text: root.size + " px · 2×"; color: Theme.muted; font.pixelSize: Theme.fontSize - 1 }
    }

    KitLine { id: line; sectionBreak: false }

    // the family at its true size
    Row {
      id: strip
      width: parent.width
      spacing: Theme.gapHair
      readonly property real cell: Math.floor((width - 6 * spacing) / 7)

      Repeater {
        model: root.kinds

        Rectangle {
          id: cellItem
          required property var modelData
          readonly property var e: root.entry(modelData.name)
          readonly property bool kept: root.kept === modelData.name
          width: parent.cell
          height: Math.max(56, root.size + 2 * Theme.gapMedium)
          radius: Theme.radiusControl
          color: kept ? Theme.pickFill : cellArea.containsMouse ? Theme.controlHover : Theme.clear
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
          Accessible.role: Accessible.Button
          Accessible.name: modelData.label

          Image {
            anchors.centerIn: parent
            width: root.size
            height: width
            visible: cellItem.e !== null
            source: cellItem.e ? "file://" + cellItem.e.path + "?" + root.key : ""
            sourceSize: Qt.size(root.size * 2, root.size * 2)
            asynchronous: true
            smooth: true
          }
          KitText { anchors.centerIn: parent; visible: cellItem.e === null; text: "--"; color: Theme.gray }

          MouseArea {
            id: cellArea
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.hovered = cellItem.modelData.name
            onExited: if (root.hovered === cellItem.modelData.name) root.hovered = ""
            onClicked: root.kept = cellItem.modelData.name
          }
        }
      }
    }
  }
}
