import QtQuick
import qs.config
import qs.kit

// Clipboard history, newest first: text previews and image thumbnails. Click
// to copy it back (COPIED, then the window closes), × to delete it; drag text
// or an image out into any app. A search field narrows the list; Clear empties
// it (the limit: Shell Manager › Shell apps › Clipboard).
KitFrame {
  id: root
  // rows already on show: a new one eases in (KitAppear)
  property KitSeen seen: KitSeen {}

  property string query: ""
  property bool confirmClear: false
  property string copiedId: ""      // the entry just copied: COPIED, then close

  // the bar's popup sets these (ClipboardBar); the window shows all of them
  property int maxRows: 0                // entries listed, 0 = all
  property bool search: true          // the search field

  readonly property var shown: ClipboardService.entries.filter(e =>
    query.trim() === "" || (e.kind === "text" && e.preview.toLowerCase().includes(query.trim().toLowerCase())))
    .slice(0, maxRows > 0 ? maxRows : undefined)

  signal picked()

  Timer {
    id: copiedTimer
    interval: 800
    onTriggered: {
      root.copiedId = "";
      root.picked();
    }
  }

  function when(time) {
    const d = new Date(time * 1000);
    const today = d.toDateString() === new Date().toDateString();
    return Qt.formatDateTime(d, today ? "HH:mm" : "dd.MM HH:mm");
  }

  // ---- header ----
  KitHeader {
    icon: "clipboard"
    title: "Clipboard"
    subtitle: ClipboardService.entries.length + " OF " + ClipboardService.limit + " KEPT"

    KitButton {
      icon: "trash"
      text: root.confirmClear ? "Sure?" : "Clear"
      disabled: ClipboardService.entries.length === 0
      onClicked: {
        if (ModuleSettings.get("clipboard", "confirm", true) && !root.confirmClear) { root.confirmClear = true; return; }
        root.confirmClear = false;
        ClipboardService.clear();
      }
    }
  }

  KitInput {
    width: parent.width
    visible: root.search && ClipboardService.entries.length > 0
    placeholder: "Search clips…"
    text: root.query
    onTextEdited: root.query = text
  }

  KitLine {}

  KitText {
    visible: root.shown.length === 0
    text: ClipboardService.entries.length === 0 ? "Nothing copied yet." : "No text matches \"" + root.query + "\"."
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 1
  }

  // ---- history ----
  Flickable {
    width: parent.width
    visible: root.shown.length > 0
    // the popup caps it at 440; the window stops it at the frame's bottom padding
    height: Math.max(0, Math.min(contentHeight, root.framed ? 440 : root.height - 2 * root.padding + root.headerInset - y))
    contentHeight: rows.implicitHeight
    interactive: contentHeight > height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: rows
      width: parent.width
      spacing: Theme.gapLoose

      Repeater {
        model: root.shown

        // like a notification: a caps line (kind left, time right), then
        // the content; lines between entries
        Column {
          id: item

          required property var modelData
          required property int index

          readonly property bool image: modelData.kind === "image"

          // a new copy eases in
          KitAppear { target: item; seen: root.seen; key: String(item.modelData.id) }
          readonly property bool hot: area.containsMouse || remove.containsMouse || area.activeFocus || remove.activeFocus

          width: rows.width
          spacing: 3

          KitLine { visible: item.index > 0 }
          Item { width: 1; height: item.index > 0 ? 6 : 0 }

          Item {
            width: parent.width
            height: entry.implicitHeight

            // hover: the entry is clickable
            Rectangle {
              radius: Theme.radiusControl
              anchors { fill: parent; margins: -4 }
              color: item.hot ? Theme.background1 : Theme.clear
              border.width: area.activeFocus || remove.activeFocus ? Math.max(2, Theme.frameWidth) : 0
              border.color: Theme.foreground0
            }

            Column {
              id: entry
              width: parent.width
              spacing: 3

              Item {
                width: parent.width
                height: kind.implicitHeight

                KitText {
                  id: kind
                  anchors { left: parent.left; right: time.left; rightMargin: Theme.gapMedium }
                  text: root.copiedId === item.modelData.id ? "COPIED"
                      : item.image ? "IMAGE · " + thumb.sourceSize.width + "×" + thumb.sourceSize.height : "TEXT"
                  elide: Text.ElideRight
                  color: root.copiedId === item.modelData.id ? Theme.green : Theme.muted
                  font.pixelSize: Theme.fontSize - 2
                  font.letterSpacing: 1
                }

                KitText {
                  id: time
                  anchors.right: parent.right
                  visible: !item.hot
                  text: root.when(item.modelData.time)
                  color: Theme.muted
                  font.pixelSize: Theme.fontSize - 2
                }

                // delete: takes the time's place on hover
                KitIcon {
                  anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                  visible: item.hot
                  name: "x"
                  size: Theme.iconSmall
                  tint: remove.containsMouse ? Theme.red : Theme.foreground2
                }
              }

              KitText {
                width: parent.width
                visible: !item.image
                text: item.modelData.preview.trim().replace(/\s+/g, " ")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }

              Image {
                id: thumb
                visible: item.image
                source: item.image ? "file://" + item.modelData.path : ""
                width: parent.width
                height: visible ? Math.min(240, implicitHeight * width / Math.max(1, implicitWidth)) : 0
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignHCenter
                asynchronous: true
                cache: false

                Rectangle {
                  radius: Theme.radiusControl
                  anchors.fill: parent
                  color: "transparent"
                  border.width: Theme.frameWidth
                  border.color: Theme.gray
                }
              }
            }

            // click copies; an image can be dragged out as its file
            MouseArea {
              id: area
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              drag.target: dragProxy
              activeFocusOnTab: true
              Accessible.role: Accessible.Button
              Accessible.name: (item.image ? "Copy image from clipboard, " : "Copy clipboard text, ")
                + root.when(item.modelData.time)
              Accessible.description: item.image ? "Copies the image to the clipboard" : item.modelData.preview
              Keys.onPressed: event => {
                if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
                if (!event.isAutoRepeat) {
                  ClipboardService.copy(item.modelData.id);
                  root.copiedId = item.modelData.id;
                  copiedTimer.restart();
                }
                event.accepted = true;
              }
              onClicked: {
                ClipboardService.copy(item.modelData.id);
                root.copiedId = item.modelData.id;
                copiedTimer.restart();
              }
            }

            MouseArea {
              id: remove
              anchors { right: parent.right; top: parent.top }
              width: 20
              height: kind.implicitHeight
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              activeFocusOnTab: true
              Accessible.role: Accessible.Button
              Accessible.name: "Delete clipboard entry"
              Accessible.description: root.when(item.modelData.time)
              Keys.onPressed: event => {
                if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
                if (!event.isAutoRepeat) ClipboardService.remove(item.modelData.id);
                event.accepted = true;
              }
              onClicked: ClipboardService.remove(item.modelData.id)
            }

            Item {
              id: dragProxy
              Drag.active: area.drag.active
              Drag.dragType: Drag.Automatic
              Drag.supportedActions: Qt.CopyAction
              Drag.mimeData: item.image ? { "text/uri-list": "file://" + item.modelData.path }
                                        : { "text/plain": item.modelData.preview }
              Drag.imageSource: item.image ? "file://" + item.modelData.path : ""
            }
          }
        }
      }
    }
  }

  KitText {
    width: parent.width
    visible: ClipboardService.error !== ""
    text: ClipboardService.error
    color: Theme.red
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSize - 1
  }
}
