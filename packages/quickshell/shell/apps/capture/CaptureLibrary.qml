import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.config
import qs.kit

// The saved screenshots and recordings: a searchable, sortable file list on the
// left; the selected file on the right with a preview and what to do with it.
// A row's click selects it; the buttons of the preview act on it. It fills
// the window: the label, the search and the heads stay, only the rows scroll.
Item {
  id: root

  property var items: []
  property bool loading: false
  property string query: ""
  property string sortKey: "date"
  property bool sortDesc: true
  property string selectedPath: ""
  // the first press asks again; a second press within a few seconds moves them all
  property bool confirming: false

  readonly property int previewWidth: Math.min(232, Math.max(0, Math.floor(width * 0.38)))
  readonly property var selected: items.find(i => i.path === selectedPath) ?? null
  readonly property string thumbDir: Quickshell.env("HOME") + "/.cache/quickshell-capture/thumbs"

  // the columns after the name: the heads and the rows share them
  readonly property var colWidths: ({ type: 96, date: 150, size: 72 })
  readonly property var colOrder: ["type", "date", "size"]
  readonly property int nameMin: 140
  // a narrow list (the preview open, a small window) drops columns, type first
  readonly property var dropOrder: ["type", "size", "date"]

  // the columns after the name that fit in a row `total` wide, left to right
  function cols(total) {
    const out = colOrder.slice();
    for (const k of dropOrder) {
      if (total - out.reduce((sum, c) => sum + colWidths[c], 0) >= nameMin) break;
      out.splice(out.indexOf(k), 1);
    }
    return out;
  }

  // where a column starts and how wide it is in a row `total` wide; a dropped one is 0 wide
  function colLeft(key, total) {
    if (key === "name") return 0;
    const shownCols = cols(total);
    let x = total;
    for (let i = shownCols.length - 1; i >= 0; i--) {
      x -= colWidths[shownCols[i]];
      if (shownCols[i] === key) return x;
    }
    return total;
  }

  function colWidth(key, total) {
    const shownCols = cols(total);
    if (key === "name") return total - shownCols.reduce((sum, k) => sum + colWidths[k], 0);
    return shownCols.includes(key) ? colWidths[key] : 0;
  }

  // the rows on show: filtered by the search, sorted by the column
  readonly property var shown: {
    const q = query.trim().toLowerCase();
    const keys = {
      name: i => i.name.toLowerCase(),
      type: i => i.video ? 1 : 0,
      date: i => i.time,
      size: i => i.bytes
    };
    const key = keys[sortKey];
    const rows = items.filter(i => q === "" || i.name.toLowerCase().includes(q));
    rows.sort((a, b) => {
      const x = key(a), y = key(b);
      return x < y ? -1 : x > y ? 1 : 0;
    });
    return sortDesc ? rows.reverse() : rows;
  }

  function refresh() {
    loading = true;
    list.running = true;
  }

  function sortBy(key) {
    if (sortKey === key) sortDesc = !sortDesc;
    else { sortKey = key; sortDesc = key === "date" || key === "size"; }
  }

  function size(bytes) {
    return bytes >= 1048576 ? (bytes / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(bytes / 1024)) + " KB";
  }

  function when(seconds) {
    return Qt.formatDateTime(new Date(seconds * 1000), "d MMM yyyy, HH:mm");
  }

  function duration(seconds) {
    const s = Math.round(seconds);
    return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
  }

  // every file in the library goes to the trash (gio trash keeps it recoverable),
  // not only the rows the search shows
  function clearAll() {
    if (!confirming) { confirming = true; confirmTimer.restart(); return; }
    confirming = false;
    const paths = items.map(i => i.path);
    if (paths.length === 0) return;
    Quickshell.execDetached(["sh", "-c", 'for f in "$@"; do gio trash -- "$f"; done; notify-send -a Capture "Library cleared" "$# files moved to trash"', "sh"].concat(paths));
    selectedPath = "";
    reloadTimer.restart();
  }

  // the selected file, one at a time
  function trashSelected() {
    if (!selected) return;
    Quickshell.execDetached(["gio", "trash", "--", selected.path]);
    selectedPath = "";
    reloadTimer.restart();
  }

  function select(path) {
    selectedPath = path;
    if (path === "") return;
    const item = items.find(i => i.path === path);
    if (item && item.video) probe.path = path;
  }

  Timer {
    id: confirmTimer

    interval: 4000
    onTriggered: root.confirming = false
  }

  // gio trash runs outside this process, so the list is read again once it is done
  Timer {
    id: reloadTimer

    interval: 800
    onTriggered: root.refresh()
  }

  Column {
    id: listColumn

    anchors { left: parent.left; top: parent.top; right: parent.right; rightMargin: root.selected ? root.previewWidth + Theme.gapWide : 0 }
    spacing: Theme.gapMedium

    KitLabel {
      text: "LIBRARY"
      value: root.loading ? "LOADING…" : root.shown.length === root.items.length
        ? root.items.length + " FILES" : root.shown.length + " OF " + root.items.length
    }

    KitInput {
      placeholder: "Search by name…"
      onTextEdited: root.query = text
    }

    // the column heads: the active one carries its direction
    Item {
      id: heads

      width: parent.width
      height: Theme.fontSize + 10

      Repeater {
        model: ["name"].concat(root.cols(heads.width))

        Item {
          required property string modelData

          x: root.colLeft(modelData, heads.width)
          width: root.colWidth(modelData, heads.width)
          height: heads.height

          KitText {
            anchors { left: parent.left; right: parent.right; leftMargin: Theme.gapSmall; rightMargin: Theme.gapSmall; verticalCenter: parent.verticalCenter }
            horizontalAlignment: modelData === "size" ? Text.AlignRight : Text.AlignLeft
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSize - 2
            font.letterSpacing: 1
            color: root.sortKey === modelData ? Theme.foreground0 : Theme.muted
            text: ({ name: "NAME", type: "TYPE", date: "DATE", size: "SIZE" })[modelData]
              + (root.sortKey === modelData ? (root.sortDesc ? " ↓" : " ↑") : "")
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.sortBy(modelData)
          }
        }
      }
    }

    KitLine {}
  }

  // the rows: icon and name, then type, date and size; a click selects the
  // file. The only part that scrolls, and only up and down.
  Flickable {
    id: rows

    anchors { left: listColumn.left; right: listColumn.right; top: listColumn.bottom; topMargin: Theme.gapMedium; bottom: parent.bottom }
    contentWidth: width
    contentHeight: rowsColumn.implicitHeight
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    clip: true

    Column {
      id: rowsColumn
      width: rows.width

      Repeater {
        model: root.shown

        Rectangle {
          required property var modelData

          readonly property bool current: modelData.path === root.selectedPath

          width: parent.width
          height: Theme.fontSize + 14
          radius: Theme.radiusControl
          color: current ? Theme.background3 : rowArea.containsMouse ? Theme.controlHover : Theme.clear

          Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

          KitIcon {
            id: icon

            x: Theme.gapSmall
            anchors.verticalCenter: parent.verticalCenter
            name: modelData.video ? "video" : "camera"
            tint: Theme.muted
            size: Theme.fontSize
          }

          KitText {
            x: icon.x + icon.width + Theme.gapSmall
            width: root.colWidth("name", parent.width) - x - Theme.gapSmall
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            font.weight: parent.current ? Font.ExtraBold : Theme.fontWeight
            text: modelData.name
          }

          KitText {
            visible: width > 0
            x: root.colLeft("type", parent.width) + Theme.gapSmall
            width: root.colWidth("type", parent.width) - Theme.gapSmall
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            color: Theme.muted
            text: modelData.video ? "Recording" : "Screenshot"
          }

          KitText {
            visible: width > 0
            x: root.colLeft("date", parent.width) + Theme.gapSmall
            width: root.colWidth("date", parent.width) - Theme.gapSmall
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            color: Theme.muted
            text: root.when(modelData.time)
          }

          KitText {
            visible: root.colWidth("size", parent.width) > 0
            x: root.colLeft("size", parent.width)
            width: root.colWidth("size", parent.width) - Theme.gapSmall
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            color: Theme.muted
            text: root.size(modelData.bytes)
          }

          MouseArea {
            id: rowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.select(modelData.path)
          }
        }
      }

      KitText {
        visible: !root.loading && root.items.length === 0
        color: Theme.muted
        text: "Nothing saved yet"
      }

      KitText {
        visible: !root.loading && root.items.length > 0 && root.shown.length === 0
        color: Theme.muted
        text: "No file matches " + root.query.trim()
      }
    }
  }

  // the preview of the selected file, and what to do with it
  Column {
    id: preview

    visible: root.selected !== null
    anchors { top: parent.top; right: parent.right }
    width: root.previewWidth
    spacing: Theme.gapMedium

    Rectangle {
      width: parent.width
      height: width * 0.66
      radius: Theme.radiusCard
      color: Theme.background1
      clip: true

      Image {
        id: picture

        anchors.fill: parent
        anchors.margins: Theme.gapSmall
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        // a screenshot is its own picture; a recording shows a frame made once (ffmpegthumbnailer)
        source: root.selected === null ? ""
          : root.selected.video ? (thumbs.ready ? "file://" + thumbs.target : "")
          : "file://" + root.selected.path
      }

      KitIcon {
        anchors.centerIn: parent
        visible: picture.status !== Image.Ready
        name: root.selected && root.selected.video ? "video" : "camera"
        tint: Theme.muted
        size: Theme.fontSize + 12
      }
    }

    KitText {
      width: parent.width
      wrapMode: Text.WrapAnywhere
      font.weight: Font.ExtraBold
      text: root.selected ? root.selected.name : ""
    }

    KitText {
      width: parent.width
      wrapMode: Text.WordWrap
      color: Theme.muted
      font.pixelSize: Theme.fontSize - 2
      text: {
        if (!root.selected) return "";
        const kind = root.selected.video ? "Recording" + (probe.seconds > 0 ? " · " + root.duration(probe.seconds) : "")
          : "Screenshot" + (picture.sourceSize.width > 0 ? " · " + picture.sourceSize.width + " × " + picture.sourceSize.height + " px" : "");
        return kind + " · " + root.size(root.selected.bytes) + "\n" + root.when(root.selected.time);
      }
    }

    KitButton {
      width: parent.width
      icon: "external"
      text: "Open"
      onClicked: Quickshell.execDetached(["xdg-open", root.selected.path])
    }

    KitButton {
      width: parent.width
      visible: root.selected !== null && !root.selected.video
      icon: "clipboard"
      text: "Copy image"
      onClicked: Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1" && notify-send -a Capture "Copied" "$2"', "sh", root.selected.path, root.selected.name])
    }

    KitButton {
      width: parent.width
      icon: "folder"
      text: "Show in folder"
      onClicked: ShellIpc.call("files", "reveal", [root.selected.path])
    }

    KitButton {
      width: parent.width
      icon: "trash"
      iconTint: Theme.red
      text: "Move to trash"
      onClicked: root.trashSelected()
    }
  }

  // a recording's frame, made once into the cache; the file is not decoded again
  Process {
    id: thumbs

    // the frame on show and the one being made; set together with the command
    // (a binding would still hold the last file when the selection starts it)
    property string target: ""
    property string next: ""
    property string nextVideo: ""
    property bool ready: false

    function make(video, png) {
      ready = false;
      next = png;
      nextVideo = video;
      if (!running) start();
    }

    function start() {
      target = next;
      command = ["sh", "-c", 'mkdir -p "$1" && { [ -s "$2" ] || ffmpegthumbnailer -i "$3" -o "$2" -s 512 -t 10; }',
                 "sh", root.thumbDir, next, nextVideo];
      running = true;
    }

    // the selection moved on while it ran: make the new one; else it is in
    // when the file is there
    onExited: code => {
      if (next !== target) { start(); return; }
      ready = code === 0;
    }
  }

  // a recording's length
  Process {
    id: probe

    property string path: ""
    property real seconds: 0

    stdout: StdioCollector {
      onStreamFinished: probe.seconds = Number(text.trim()) || 0
    }
    // the command is set here, not bound: the binding would still hold the last path
    onPathChanged: {
      seconds = 0;
      if (path === "") return;
      command = ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path];
      running = true;
    }
  }

  // the picture follows the selection: a recording's frame is made when it is picked
  onSelectedChanged: {
    if (!selected || !selected.video) { thumbs.ready = false; return; }
    const png = thumbDir + "/" + selected.name.replace(/\.mp4$/, "") + ".png";
    if (png === thumbs.target && thumbs.ready) return;     // the list was read again
    thumbs.make(selected.path, png);
  }

  Process {
    id: list

    command: ["sh", "-c", 'find "$1" "$2" -maxdepth 1 -type f \\( -name "*.png" -o -name "*.mp4" \\) -printf "%T@ %s %p\\n" 2>/dev/null | sort -u | sort -rn | head -200',
              "sh", CaptureService.shotDir, CaptureService.videoDir]
    stdout: StdioCollector {
      onStreamFinished: {
        const rows = [];
        for (const line of text.split("\n")) {
          const m = line.match(/^(\d+)(?:\.\d+)? (\d+) (.+)$/);
          if (!m) continue;
          rows.push({ time: Number(m[1]), bytes: Number(m[2]), path: m[3], name: m[3].split("/").pop(),
                      video: m[3].endsWith(".mp4") });
        }
        root.items = rows;
        root.loading = false;
      }
    }
  }
}
