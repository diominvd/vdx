import QtQuick
import qs.config
import qs.kit

// This computer: the storage of the system. The view button decides the look: grid (a raised card per
// storage, used and free space as a bar) or list (the folder list's table: a row per storage). A mounted one opens on a
// click; a removable drive not mounted yet mounts on a click and opens. Right click for the menu.
Rectangle {
  id: root

  required property var files   // the Files window

  readonly property bool asGrid: FilesService.computerView === "grid"
  // the storage in the sort's order: by name, or by size (the largest first)
  readonly property var storage: FilesService.volumes.slice().sort((a, b) =>
    FilesService.computerSort === "size" ? b.total - a.total : a.name.localeCompare(b.name))
  // Keep a useful name column when the window is narrow; right-side columns
  // shrink before they are allowed to push their start positions off-screen.
  readonly property real barWidth: Math.max(0, Math.min(140, (root.width - 120 - 2 * Theme.gapWide) / 2))
  readonly property real spaceWidth: Math.max(0, Math.min(180, root.width - 120 - 2 * Theme.gapWide - barWidth))
  readonly property int rowH: 48

  radius: Theme.radiusCard
  color: "transparent"
  clip: true

  function kindOf(d) { return ({ disk: "DISK", removable: "REMOVABLE", network: "NETWORK" })[d.kind] ?? "DISK"; }
  function usedOf(d) { return d.total > 0 ? (d.total - d.free) / d.total : 0; }
  // nearly full: the warning colours, as the sidebar's storage
  function levelOf(v) { return v > 0.95 ? Theme.red : v > 0.85 ? Theme.yellow : Theme.foreground1; }
  function iconOf(d) { return d.kind === "network" ? "server" : d.kind === "removable" ? "package" : "hard-drive"; }
  function caption(d) {
    return d.mount !== "" ? kindOf(d) + " · " + (d.fstype ?? "").toUpperCase()
                          : kindOf(d) + " · NOT MOUNTED" + (d.size ? " · " + d.size : "");
  }
  function space(d) {
    return d.mount !== "" ? Format.humanSize(d.free) + " free of " + Format.humanSize(d.total) : "";
  }
  function open(d) {
    if (d.mount !== "") FilesService.go(d.mount);
    else FilesService.mountDevice(d, true);
  }
  function menu(d, at) {
    root.files.menuAt(at, [
      { label: "Open", disabled: d.mount === "", run: () => FilesService.go(d.mount) },
      { label: "Mount", disabled: d.mount !== "", run: () => FilesService.mountDevice(d, false) },
      { label: "Unmount", disabled: d.mount === "", run: () => FilesService.unmountDevice(d) },
      { label: "Properties", run: () => FilesService.deviceProperties(d) },
    ]);
  }

  KitText {
    visible: root.storage.length === 0
    anchors { left: parent.left; top: parent.top; topMargin: Theme.gapGroup }
    width: Math.max(0, parent.width - 2 * Theme.gapWide)
    wrapMode: Text.WordWrap
    text: "No storage found"
    color: Theme.muted
  }

  // ---- grid: a raised card each ----
  Flickable {
    visible: root.asGrid
    anchors.fill: parent
    contentHeight: flow.implicitHeight
    clip: true
    interactive: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds

    Grid {
      id: flow
      // as many cards as fit at ~240 px; they share the width, so the row is always full
      readonly property int across: Math.max(1, Math.floor((width + Theme.gapMedium) / (240 + Theme.gapMedium)))
      readonly property real cardWidth: (width - Theme.gapMedium * (across - 1)) / across
      width: parent.width
      columns: across
      spacing: Theme.gapMedium

      Repeater {
        model: root.asGrid ? root.storage : []

        Rectangle {
          id: card
          required property var modelData
          readonly property bool mounted: modelData.mount !== ""

          width: flow.cardWidth
          height: 96
          radius: Theme.radiusCard
          color: area.containsMouse ? Theme.background2 : Theme.background1
          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

          KitIcon {
            id: glyph
            anchors { left: parent.left; top: parent.top; leftMargin: Theme.gapWide; topMargin: Theme.gapWide + 2 }
            name: root.iconOf(card.modelData)
            size: Theme.iconSmall + 2
          }

          Column {
            anchors { left: glyph.right; leftMargin: Theme.gapMedium; right: parent.right; rightMargin: Theme.gapWide; top: parent.top; topMargin: Theme.gapWide }

            KitText {
              width: parent.width
              text: card.modelData.name
              elide: Text.ElideRight
              font.weight: Font.ExtraBold
            }

            KitText {
              width: parent.width
              text: root.caption(card.modelData)
              elide: Text.ElideRight
              color: Theme.muted
              font.pixelSize: Theme.fontSize - 2
            }
          }

          KitBar {
            visible: card.mounted
            anchors { left: parent.left; right: parent.right; leftMargin: Theme.gapWide; rightMargin: Theme.gapWide; bottom: space.top; bottomMargin: Theme.gapSmall }
            value: root.usedOf(card.modelData)
            tint: root.levelOf(value)
          }

          KitText {
            id: space
            visible: card.mounted
            anchors { left: parent.left; leftMargin: Theme.gapWide; bottom: parent.bottom; bottomMargin: Theme.gapWide }
            text: root.space(card.modelData)
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 2
          }

          MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
              if (mouse.button === Qt.RightButton) root.menu(card.modelData, card.mapToItem(null, mouse.x, mouse.y));
              else root.open(card.modelData);
            }
          }
        }
      }
    }
  }

  // ---- list: the folder list's table: captions, then a row each, in one raised box ----
  Flickable {
    visible: !root.asGrid && root.storage.length > 0
    anchors.fill: parent
    contentHeight: box.height
    clip: true
    interactive: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds

    Rectangle {
      id: box
      width: parent.width
      height: table.implicitHeight + Theme.gapSmall
      radius: Theme.radiusCard
      color: Theme.background1

      // the fixed columns from the right: the used bar, the space; the name takes the rest
      readonly property real barX: Math.max(0, width - Theme.gapWide - root.barWidth)
      readonly property real spaceX: Math.max(0, barX - Theme.gapWide - root.spaceWidth)
      readonly property var seps: [Math.max(0, barX - Theme.gapWide / 2), Math.max(0, spaceX - Theme.gapWide / 2)]

      Column {
        id: table
        width: parent.width

        Item {
          id: captions
          width: parent.width
          height: 34

          FilesCaption { x: 0; width: box.spaceX; height: parent.height; textX: Theme.gapWide + Theme.iconSmall + 2 + Theme.gapMedium; text: "NAME" }
          FilesCaption { x: box.spaceX; width: root.spaceWidth; height: parent.height; alignRight: true; text: "FREE OF TOTAL" }
          FilesCaption { x: box.barX; width: root.barWidth; height: parent.height; textX: 0; text: "USED" }

          Repeater {
            model: box.seps
            Rectangle { required property real modelData; x: modelData; y: Theme.gapMedium; width: 1; height: captions.height - 2 * Theme.gapMedium; color: Theme.background3 }
          }

          Rectangle { anchors.bottom: parent.bottom; x: Theme.gapWide; width: Math.max(0, parent.width - 2 * Theme.gapWide); height: 1; color: Theme.background3 }
        }

        Repeater {
          model: root.asGrid ? [] : root.storage

          Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool mounted: modelData.mount !== ""

            width: table.width
            height: root.rowH

            Rectangle {
              anchors { fill: parent; leftMargin: Theme.gapHair; rightMargin: Theme.gapHair }
              radius: Theme.radiusControl
              color: rowArea.containsMouse ? Theme.background2 : Theme.clear
              Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
            }

            // the hairline between rows
            Rectangle {
              visible: row.index > 0
              x: Theme.gapWide
              width: parent.width - 2 * Theme.gapWide
              height: 1
              color: Theme.background2
            }

            Repeater {
              model: box.seps
              Rectangle { required property real modelData; x: modelData; y: Theme.gapSmall; width: 1; height: row.height - 2 * Theme.gapSmall; color: Theme.background2 }
            }

            KitIcon {
              id: rowGlyph
              x: Theme.gapWide
              anchors.verticalCenter: parent.verticalCenter
              name: root.iconOf(row.modelData)
              size: Theme.iconSmall + 2
            }

            Column {
              x: rowGlyph.x + rowGlyph.width + Theme.gapMedium
              width: Math.max(0, box.spaceX - Theme.gapWide - x)
              anchors.verticalCenter: parent.verticalCenter

              KitText {
                width: parent.width
                text: row.modelData.name
                elide: Text.ElideRight
                font.weight: Font.ExtraBold
              }
              KitText {
                width: parent.width
                text: root.caption(row.modelData)
                elide: Text.ElideRight
                color: Theme.muted
                font.pixelSize: Theme.fontSize - 2
              }
            }

            KitText {
              x: box.spaceX
              width: root.spaceWidth
              anchors.verticalCenter: parent.verticalCenter
              horizontalAlignment: Text.AlignRight
              text: row.mounted ? Format.humanSize(row.modelData.free) + " of " + Format.humanSize(row.modelData.total) : "--"
              color: Theme.muted
              font.pixelSize: Theme.fontSize - 1
            }

            KitBar {
              visible: row.mounted
              x: box.barX
              width: root.barWidth
              anchors.verticalCenter: parent.verticalCenter
              value: root.usedOf(row.modelData)
              tint: root.levelOf(value)
            }

            MouseArea {
              id: rowArea
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              cursorShape: Qt.PointingHandCursor
              onClicked: mouse => {
                if (mouse.button === Qt.RightButton) root.menu(row.modelData, row.mapToItem(null, mouse.x, mouse.y));
                else root.open(row.modelData);
              }
            }
          }
        }
      }
    }
  }
}
