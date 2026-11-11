import QtQuick
import qs.config
import qs.kit

// The icon set in use, as CursorScene shows a cursor: one glyph large on two plates — off
// (outline, as the shell draws a quiet state) and on (solid on a filled plate, as it draws
// "on") — its name and where the shell uses it, and under them seven of the shell's own
// icons at their real size. A hover shows a glyph on the plates, a click keeps it there.
Item {
  id: root

  property int size: Theme.fontSize + 2          // the bar's icon size, the real one
  readonly property var glyphs: [
    { name: "settings",     label: "Settings",  use: "Shell Manager and options" },
    { name: "bell",         label: "Bell",      use: "Notifications" },
    { name: "wifi",         label: "Wi-Fi",     use: "Network" },
    { name: "bluetooth",    label: "Bluetooth", use: "Bluetooth" },
    { name: "volume",       label: "Volume",    use: "Sound" },
    { name: "battery-full", label: "Battery",   use: "Power" },
    { name: "folder",       label: "Folder",    use: "Files" }
  ]
  property string kept: "settings"
  property string hovered: ""
  readonly property string shown: hovered !== "" ? hovered : kept
  readonly property var glyph: glyphs.find(g => g.name === shown) ?? glyphs[0]

  Column {
    id: col
    anchors.fill: parent
    spacing: Theme.gapMedium

    // the plates
    Row {
      width: parent.width
      height: Math.max(80, col.height - info.height - strip.height - 3 * col.spacing - line.height)
      spacing: Theme.gapMedium
      Repeater {
        model: [{ on: false, name: "Off" }, { on: true, name: "On" }]
        Rectangle {
          required property var modelData
          width: (parent.width - Theme.gapMedium) / 2
          height: parent.height
          radius: Theme.radiusCard
          color: modelData.on ? Theme.foreground1 : Theme.background2
          KitIcon {
            anchors.centerIn: parent
            name: root.shown
            size: root.size * 4
            solid: modelData.on || ShellSettings.solidIcons
            tint: modelData.on ? Theme.background0 : Theme.foreground0
          }
          KitText {
            x: Theme.gapSmall
            anchors { bottom: parent.bottom; bottomMargin: Theme.gapSmall }
            text: modelData.name
            color: modelData.on ? Theme.background2 : Theme.muted
            font.pixelSize: Theme.fontSize - 2
            font.letterSpacing: 1
          }
        }
      }
    }

    Item {
      id: info
      width: parent.width
      height: label.implicitHeight
      Column {
        id: label
        anchors { left: parent.left; right: sizeText.left; rightMargin: Theme.gapMedium }
        spacing: Theme.gapHair
        KitText { width: parent.width; text: root.glyph.label; font.weight: Font.Medium; elide: Text.ElideRight }
        KitText { width: parent.width; text: root.glyph.use; color: Theme.hint; font.pixelSize: Theme.fontSize - 1; elide: Text.ElideRight }
      }
      KitText { id: sizeText; anchors.right: parent.right; text: root.size + " px · 4×"; color: Theme.muted; font.pixelSize: Theme.fontSize - 1 }
    }

    KitLine { id: line; sectionBreak: false }

    // the same icons at their real size
    Row {
      id: strip
      width: parent.width
      spacing: Theme.gapHair
      readonly property real cell: Math.floor((width - 6 * spacing) / 7)

      Repeater {
        model: root.glyphs

        Rectangle {
          id: cell
          required property var modelData
          readonly property bool kept: root.kept === modelData.name
          width: parent.cell
          height: 56
          radius: Theme.radiusControl
          color: kept ? Theme.pickFill : area.containsMouse ? Theme.controlHover : Theme.clear
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
          Accessible.role: Accessible.Button
          Accessible.name: modelData.label
          activeFocusOnTab: true
          border.width: activeFocus ? Theme.focusWidth : 0
          border.color: Theme.focusRing
          function choose() { root.kept = modelData.name; }
          Accessible.onPressAction: choose()
          Keys.onSpacePressed: choose()
          Keys.onReturnPressed: choose()
          Keys.onEnterPressed: choose()

          KitIcon { anchors.centerIn: parent; name: cell.modelData.name; size: root.size; tint: Theme.foreground1 }

          MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.hovered = cell.modelData.name
            onExited: if (root.hovered === cell.modelData.name) root.hovered = ""
            onClicked: cell.choose()
          }
        }
      }
    }
  }
}
