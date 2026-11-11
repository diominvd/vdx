import QtQuick
import Quickshell
import qs.components
import qs.apps.taskmanager
import qs.config
import qs.kit

// The task manager in brief: CPU and memory, the busiest programs (by the
// list's sort) with End on each — a second click confirms when the option
// asks — and a button to the full window.
KitFrame {
  id: root

  readonly property var tm: TaskManagerService
  readonly property int count: ModuleSettings.get("taskmanager", "popupRows", 5)
  // the row whose End waits for a second click
  property string armed: ""
  property string ending: ""                // the row being ended (its button spins)

  signal openWindow()

  function end(row) {
    if (tm.confirm && armed !== row.key) { armed = row.key; disarm.restart(); return; }
    armed = "";
    ending = row.key;
    tm.endRow(row, false);
  }

  Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }

  KitHeader {
    icon: "activity"
    title: "Task Manager"
    subtitle: Format.count(root.tm.procs.length, "PROCESS", "PROCESSES") + " · " + (root.tm.group ? "BY PROGRAM" : "EACH PROCESS")

    KitButton {
      icon: "external"
      onClicked: {
        root.openWindow();
        ShellIpc.call("taskmanager", "open");
      }
    }
  }

  KitLine {}

  // ---- load: four tiles ----
  Grid {
    id: tiles
    width: parent.width
    columns: 2
    spacing: Theme.gapSmall
    readonly property real tile: Math.floor((width - spacing) / 2)

    Repeater {
      model: [
        { name: "CPU", value: root.tm.cpu, text: Math.round(root.tm.cpu) + "%" },
        { name: "MEMORY", value: 100 * root.tm.memUsed / Math.max(1, root.tm.memTotal), text: Format.shortSize(root.tm.memUsed) + " / " + Format.shortSize(root.tm.memTotal) },
        { name: "GPU", value: root.tm.gpu, text: Math.round(root.tm.gpu) + "%" },
        { name: "NETWORK", value: -1, text: "" }
      ]

      Rectangle {
        id: tile
        required property var modelData
        readonly property bool bar: modelData.value >= 0
        width: tiles.tile
        height: 58
        radius: Theme.radiusControl
        color: Theme.groupFill
        border.width: Theme.frameWidth
        border.color: Theme.controlLine

        KitText {
          x: Theme.gapMedium; y: Theme.gapMedium - 2
          text: tile.modelData.name
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 2
          font.letterSpacing: 1
        }

        KitText {
          visible: tile.bar
          anchors { right: parent.right; rightMargin: Theme.gapMedium; top: parent.top; topMargin: Theme.gapMedium - 3 }
          text: tile.modelData.text
          color: Theme.loadColor(tile.modelData.value)
          font.weight: Font.Medium
        }

        KitBar {
          visible: tile.bar
          anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.gapMedium }
          value: Math.min(1, tile.modelData.value / 100)
          tint: Theme.loadColor(tile.modelData.value)
        }

        Column {
          visible: !tile.bar
          anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.gapMedium }
          KitText { text: "↓ " + Format.humanRate(root.tm.rx); font.pixelSize: Theme.fontSize - 1; color: Theme.foreground2 }
          KitText { text: "↑ " + Format.humanRate(root.tm.tx); font.pixelSize: Theme.fontSize - 1; color: Theme.foreground2 }
        }
      }
    }
  }

  KitLine {}

  // ---- the busiest ----
  Column {
    width: parent.width
    spacing: Theme.gapHair

    KitLabel {
      text: root.tm.sortBy === "mem" ? "TOP BY MEMORY" : root.tm.sortBy === "name" ? "BY NAME" : "TOP BY CPU"
      value: root.tm.group ? "PROGRAMS" : "PROCESSES"
    }

    Repeater {
      model: root.tm.popupRows.slice(0, root.count)

      Rectangle {
        id: row

        required property var modelData
        readonly property bool armed: root.armed === modelData.key
        readonly property bool busy: root.tm.busy && root.ending === modelData.key

        width: parent.width
        height: 32
        radius: Theme.radiusControl
        color: armed ? Theme.mix(Theme.background0, Theme.red, 0.14) : hover.hovered ? Theme.controlHover : Theme.clear
        Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
        HoverHandler { id: hover }

        KitText {
          anchors { left: parent.left; leftMargin: Theme.gapMedium; right: cpuText.left; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
          text: row.modelData.name + (row.modelData.count > 1 ? "  ×" + row.modelData.count : "")
          elide: Text.ElideRight
        }

        KitText {
          id: cpuText
          anchors { right: memText.left; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
          width: 48
          horizontalAlignment: Text.AlignRight
          text: row.modelData.cpu.toFixed(1) + "%"
          color: row.modelData.cpu >= 1 ? Theme.loadColor(row.modelData.cpu) : Theme.muted
        }

        KitText {
          id: memText
          anchors { right: endButton.left; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
          width: 60
          horizontalAlignment: Text.AlignRight
          text: Format.shortSize(row.modelData.mem)
          color: Theme.foreground2
        }

        // End shows on hover (and stays while it waits for its second click or runs)
        KitButton {
          id: endButton
          anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
          icon: row.armed ? "check" : "x"
          selected: row.armed
          busy: row.busy
          opacity: hover.hovered || row.armed || row.busy ? 1 : 0.35
          Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
          onClicked: root.end(row.modelData)
        }
      }
    }

    KitText {
      visible: root.tm.popupRows.length === 0
      text: "Reading processes…"
      color: Theme.muted
    }
  }

  KitText {
    width: parent.width
    visible: root.tm.status === "error"
    text: root.tm.error
    color: Theme.red
    wrapMode: Text.WordWrap
  }
}
