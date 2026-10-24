import QtQuick
import qs.config
import qs.kit

// The sidebar, in sections: PLACES (This computer, Recent, Starred, the places, Trash), PINNED (the folders
// you pinned), USB (removable drives, plugged in or not: a button mounts or unmounts), DEVICES (other drives
// mounted for you), then the space left on Home's filesystem. Each section keeps its own order: a drag moves a
// row within its section. Right click a row for its menu.
// No frame: the strip beside it (Files' split) is the only line.
Item {
  id: root

  required property var files   // the Files window
  // the stored list, each row with its place in it ("at"), by section
  readonly property var placeItems: FilesService.sidebarItems.map((i, at) => Object.assign({ at: at }, i)).filter(i => i.kind !== "folder")
  readonly property var pinnedItems: FilesService.sidebarItems.map((i, at) => Object.assign({ at: at }, i)).filter(i => i.kind === "folder")
  readonly property var usbDevices: FilesService.showDevices ? FilesService.devices.filter(d => d.removable) : []
  readonly property var otherDevices: FilesService.showDevices ? FilesService.devices.filter(d => !d.removable) : []
  readonly property int visiblePlaces: placeItems.filter(i => !i.hidden).length

  // the row being dragged (its place in the stored list, its section), and the row a drop would land beside
  property int dragFrom: -1
  property string dragKind: ""
  property int dropAt: -1

  // the nearest row of the dragged row's section to a scene height
  function rowAt(sceneY) {
    const rep = dragKind === "folder" ? pinnedRows : placeRows;
    let best = -1, dist = Infinity;
    for (let i = 0; i < rep.count; i++) {
      const r = rep.itemAt(i);
      if (!r || !r.visible) continue;
      const d = Math.abs(r.mapToItem(null, 0, r.height / 2).y - sceneY);
      if (d < dist) { dist = d; best = r.modelData.at; }
    }
    return best;
  }

  // the row at a place in the stored list (the drop line's target)
  function rowFor(at) {
    for (const rep of [placeRows, pinnedRows])
      for (let i = 0; i < rep.count; i++) {
        const r = rep.itemAt(i);
        if (r && r.modelData.at === at) return r;
      }
    return null;
  }

  function drop() {
    if (dragFrom >= 0 && dropAt >= 0 && dropAt !== dragFrom) FilesService.moveSidebar(dragFrom, dropAt);
    dragFrom = -1;
    dropAt = -1;
  }

  function rowMenu(item) {
    const pinned = item.kind === "folder";
    return [
      { label: "Open", run: () => FilesService.go(item.path) },
      pinned ? { label: "Unpin", run: () => FilesService.unpin(item.path) }
             : { label: "Hide from the sidebar", run: () => FilesService.unpin(item.path) },
    ];
  }

  function deviceMenu(d) {
    return [
      { label: "Open", disabled: d.mount === "", run: () => FilesService.go(d.mount) },
      { label: "Mount", disabled: d.mount !== "", run: () => FilesService.mountDevice(d, false) },
      { label: "Unmount", disabled: d.mount === "", run: () => FilesService.unmountDevice(d) },
      { label: "Properties", run: () => FilesService.deviceProperties(d) },
    ];
  }

  Flickable {
    id: sidebar
    anchors.fill: parent
    contentHeight: sideColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: sideColumn
      width: sidebar.width
      spacing: Theme.gapTight

      KitSideCaption { text: "PLACES"; visible: root.visiblePlaces > 0 }

      Repeater {
        id: placeRows
        model: root.placeItems

        KitSideRow {
          required property var modelData
          visible: !modelData.hidden
          draggable: true
          icon: ({ computer: "monitor", trash: "trash", recent: "history", starred: "star" })[modelData.kind]
              ?? (modelData.kind === "place" ? root.files.placeIcon(modelData.name) : "folder")
          hint: modelData.kind === "starred" && FilesService.starred.length > 0 ? FilesService.starred.length + "" : ""
          text: modelData.name
          current: FilesService.path === modelData.path
          onClicked: FilesService.go(modelData.path)
          onRightClicked: at => root.files.menuAt(at, root.rowMenu(modelData))
          onDragged: sceneY => { root.dragFrom = modelData.at; root.dragKind = "place"; root.dropAt = root.rowAt(sceneY); }
          onDropped: sceneY => { root.dropAt = root.rowAt(sceneY); root.drop(); }
        }
      }

      KitSideCaption { text: "PINNED"; lead: root.visiblePlaces > 0 ? Theme.gapMedium : 0 }

      Repeater {
        id: pinnedRows
        model: root.pinnedItems

        KitSideRow {
          required property var modelData
          visible: !modelData.hidden
          draggable: true
          icon: "folder"
          text: modelData.name
          current: FilesService.path === modelData.path
          onClicked: FilesService.go(modelData.path)
          onRightClicked: at => root.files.menuAt(at, root.rowMenu(modelData))
          onDragged: sceneY => { root.dragFrom = modelData.at; root.dragKind = "folder"; root.dropAt = root.rowAt(sceneY); }
          onDropped: sceneY => { root.dropAt = root.rowAt(sceneY); root.drop(); }
        }
      }

      // nothing pinned: the hairline that the section has no rows
      Rectangle {
        visible: root.pinnedItems.length === 0
        x: Theme.gapLoose
        width: sidebar.width - 2 * Theme.gapLoose
        height: 1
        color: Theme.background3
      }

      // removable drives: plugged in, mounted or not; the button at the end mounts or unmounts
      KitSideCaption { text: "USB"; lead: Theme.gapMedium; visible: root.usbDevices.length > 0 }

      Repeater {
        model: root.usbDevices

        KitSideRow {
          required property var modelData
          icon: "usb"
          text: modelData.name
          hint: modelData.mount !== "" ? "" : modelData.size
          action: modelData.mount !== "" ? "eject" : "power"
          actionLabel: modelData.mount !== "" ? qsTr("Unmount %1").arg(modelData.name) : qsTr("Mount %1").arg(modelData.name)
          current: modelData.mount !== "" && FilesService.path.startsWith(modelData.mount)
          onClicked: modelData.mount !== "" ? FilesService.go(modelData.mount) : FilesService.mountDevice(modelData, true)
          onActioned: modelData.mount !== "" ? FilesService.unmountDevice(modelData) : FilesService.mountDevice(modelData, false)
          onRightClicked: at => root.files.menuAt(at, root.deviceMenu(modelData))
        }
      }

      // the other drives udisks mounted for the user
      KitSideCaption { text: "DEVICES"; lead: Theme.gapMedium; visible: root.otherDevices.length > 0 }

      Repeater {
        model: root.otherDevices

        KitSideRow {
          required property var modelData
          icon: "hard-drive"
          text: modelData.name
          hint: modelData.mount !== "" ? "" : modelData.size
          current: modelData.mount !== "" && FilesService.path.startsWith(modelData.mount)
          onClicked: modelData.mount !== "" ? FilesService.go(modelData.mount) : FilesService.mountDevice(modelData, true)
          onRightClicked: at => root.files.menuAt(at, root.deviceMenu(modelData))
        }
      }
    }

    // the drop line: where the dragged row lands
    Rectangle {
      visible: root.dragFrom >= 0 && root.dropAt >= 0 && root.dropAt !== root.dragFrom
      readonly property var target: visible ? root.rowFor(root.dropAt) : null
      x: 0
      width: sideColumn.width
      height: 2
      radius: 1
      color: Theme.accent
      y: target ? (root.dropAt > root.dragFrom ? target.y + target.height : target.y) - 1 : 0
    }
  }
}
