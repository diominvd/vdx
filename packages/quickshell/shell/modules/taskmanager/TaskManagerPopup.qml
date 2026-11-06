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

  // ---- load ----
  Column {
    width: parent.width
    spacing: Theme.gapMedium

    KitLabel { text: "CPU"; value: Math.round(root.tm.cpu) + "%"; valueColor: Theme.loadColor(root.tm.cpu) }
    KitBar { value: root.tm.cpu / 100; tint: Theme.loadColor(root.tm.cpu) }

    KitLabel {
      text: "MEMORY"
      value: Format.shortSize(root.tm.memUsed) + " / " + Format.shortSize(root.tm.memTotal)
      valueColor: Theme.loadColor(100 * root.tm.memUsed / root.tm.memTotal)
    }
    KitBar { value: root.tm.memUsed / root.tm.memTotal; tint: Theme.loadColor(100 * root.tm.memUsed / root.tm.memTotal) }

    KitLabel { text: "GPU · " + root.tm.gpuName; value: Math.round(root.tm.gpu) + "%"; valueColor: Theme.loadColor(root.tm.gpu) }
    KitBar { value: root.tm.gpu / 100; tint: Theme.loadColor(root.tm.gpu) }

    KitLabel { text: "NETWORK"; value: "↓ " + Format.humanRate(root.tm.rx) + "  ↑ " + Format.humanRate(root.tm.tx); valueColor: Theme.foreground2 }
  }

  KitLine {}

  // ---- the busiest ----
  Column {
    width: parent.width
    spacing: Theme.gapSmall

    KitLabel {
      text: root.tm.sortBy === "mem" ? "TOP BY MEMORY" : root.tm.sortBy === "name" ? "BY NAME" : "TOP BY CPU"
      value: root.tm.group ? "PROGRAMS" : "PROCESSES"
    }

    Repeater {
      model: root.tm.popupRows.slice(0, root.count)

      Item {
        id: row

        required property var modelData

        width: parent.width
        height: 28

        KitText {
          anchors { left: parent.left; right: cpuText.left; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
          text: row.modelData.name + (row.modelData.count > 1 ? "  ×" + row.modelData.count : "")
          elide: Text.ElideRight
        }

        KitText {
          id: cpuText
          anchors { right: memText.left; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
          width: 52
          horizontalAlignment: Text.AlignRight
          text: row.modelData.cpu.toFixed(1) + "%"
          color: row.modelData.cpu >= 1 ? Theme.loadColor(row.modelData.cpu) : Theme.foreground2
        }

        KitText {
          id: memText
          anchors { right: endButton.left; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }
          width: 64
          horizontalAlignment: Text.AlignRight
          text: Format.shortSize(row.modelData.mem)
          color: Theme.foreground2
        }

        KitButton {
          id: endButton
          anchors { right: parent.right; verticalCenter: parent.verticalCenter }
          icon: root.armed === row.modelData.key ? "check" : "x"
          selected: root.armed === row.modelData.key
          busy: root.tm.busy && root.ending === row.modelData.key
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
