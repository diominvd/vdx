import QtQuick
import qs.config
import qs.kit

// The path above the list: the folders down to the one shown as crumbs, each a click away (Home stands
// for the home folder). A click on the empty end, or Ctrl + L, types a path instead; Enter goes there,
// Escape gives the crumbs back. Settings › Path bar › Field: always the typed path.
Item {
  id: root

  signal done()                          // the field gave the keys back (Enter or Escape)

  readonly property bool editing: FilesService.pathBar === "field" || field.input.activeFocus
  implicitHeight: Theme.controlHeight

  // the crumbs: [{name, path}] from Home (or the root) down to the folder shown
  readonly property var crumbs: {
    const p = FilesService.path;
    if (FilesService.virtual) return [{ name: FilesService.title, path: p }];
    const home = FilesService.home;
    const inHome = p === home || p.startsWith(home + "/");
    const list = [inHome ? { name: "Home", path: home } : { name: "Root", path: "/" }];
    const rest = inHome ? p.slice(home.length) : p;
    let at = inHome ? home : "";
    for (const part of rest.split("/").filter(x => x !== "")) {
      at += "/" + part;
      list.push({ name: part, path: at });
    }
    return list;
  }

  function edit() {
    field.text = FilesService.virtual ? "" : FilesService.path;
    field.input.forceActiveFocus();
    field.input.selectAll();
  }

  // the field: the bar's look (a field), and the typed path while editing
  KitInput {
    id: field
    anchors.fill: parent
    placeholder: root.editing ? "path" : ""
    passKeys: [Qt.Key_Escape]
    text: ""
    onAccepted: {
      const typed = text.trim().replace(/^~(?=\/|$)/, FilesService.home);
      if (typed.startsWith("/")) FilesService.go(typed);
      root.done();
    }
    onKeyPassed: root.done()
    Connections {
      target: FilesService
      function onPathChanged() { if (!field.input.activeFocus) field.text = FilesService.pathBar === "field" && !FilesService.virtual ? FilesService.path : ""; }
    }
    Component.onCompleted: text = FilesService.pathBar === "field" && !FilesService.virtual ? FilesService.path : ""
  }

  // the empty end of the bar: a click types a path
  MouseArea {
    anchors.fill: parent
    visible: !root.editing
    cursorShape: Qt.IBeamCursor
    onClicked: root.edit()
  }

  Flickable {
    id: strip
    visible: !root.editing
    anchors { left: parent.left; leftMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
    width: Math.max(0, Math.min(row.implicitWidth, parent.width - 2 * Theme.gapSmall))
    height: parent.height
    contentWidth: row.implicitWidth
    contentX: Math.max(0, row.implicitWidth - width)     // the end (the folder shown) stays in sight
    interactive: false
    clip: true

    Row {
      id: row
      height: parent.height

      Repeater {
        model: root.crumbs

        Row {
          id: crumb
          required property var modelData
          required property int index
          readonly property bool last: index === root.crumbs.length - 1
          height: row.height

          KitIcon {
            visible: crumb.index > 0
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron-right"
            size: Theme.iconSmall
            tint: Theme.gray
          }

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: crumbRow.implicitWidth + 2 * Theme.gapSmall
            height: Theme.controlHeight - 8
            radius: Theme.radiusFor(height)
            color: crumbArea.containsMouse && !crumb.last ? Theme.controlHover : Theme.clear
            Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

            Row {
              id: crumbRow
              anchors.centerIn: parent
              spacing: Theme.gapSmall

              KitIcon {
                visible: crumb.index === 0
                anchors.verticalCenter: parent.verticalCenter
                name: crumb.modelData.path === FilesService.home ? "home" : FilesService.virtual ? root.placeIcon() : "server"
                size: Theme.iconSmall
                tint: crumb.last ? Theme.foreground0 : Theme.foreground2
              }

              KitText {
                anchors.verticalCenter: parent.verticalCenter
                text: crumb.modelData.name
                color: crumb.last ? Theme.foreground0 : Theme.foreground2
                font.weight: crumb.last ? Font.ExtraBold : Theme.fontWeight
              }
            }

            MouseArea {
              id: crumbArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: crumb.last ? Qt.ArrowCursor : Qt.PointingHandCursor
              onClicked: if (!crumb.last) FilesService.go(crumb.modelData.path)
            }
          }
        }
      }
    }
  }

  function placeIcon() {
    return FilesService.atComputer ? "monitor" : FilesService.inTrash ? "trash" : FilesService.atRecent ? "history" : "star";
  }
}
