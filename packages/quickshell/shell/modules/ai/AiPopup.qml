import QtQuick
import qs.components
import qs.config
import qs.kit

// AI popup: Claude Code limits, today's tokens and sessions; the Ollama tab.
KitFrame {
  id: root

  property string tab: "claude"

  readonly property var labels: ({
    session: "Session · 5h",
    weekly_all: "Week",
    weekly_opus: "Week · Opus",
    weekly_sonnet: "Week · Sonnet"
  })

  function resetsIn(iso) {
    if (!iso) return "";
    const ms = new Date(iso) - Date.now();
    if (ms <= 0) return "resets now";
    const h = Math.floor(ms / 3600000);
    const m = Math.floor(ms % 3600000 / 60000);
    if (h < 24) return "resets in " + (h > 0 ? h + "h " : "") + m + "m";
    return "resets " + Qt.formatDateTime(new Date(iso), "ddd HH:mm");
  }

  function shortPath(path) {
    return path.replace(/^\/home\/[^/]+/, "~");
  }

  // ---- header ----
  KitHeader {
    icon: "bot"
    title: root.tab === "claude" ? "Claude Code" : "Ollama"
    subtitle: root.tab === "claude"
      ? [ClaudeService.plan.toUpperCase(),
         ClaudeService.sessions.length > 0
           ? (ClaudeService.busy > 0 ? ClaudeService.busy + " WORKING" : ClaudeService.sessions.length + " IDLE")
           : "NO SESSIONS"].filter(s => s).join(" · ")
      : !OllamaService.installed ? "NOT INSTALLED"
      : OllamaService.running ? "RUNNING · V" + OllamaService.status.version
      : "STOPPED"
    subtitleColor: (root.tab === "claude" ? ClaudeService.busy > 0 : OllamaService.running) ? Theme.green : Theme.muted

    KitButton {
      visible: root.tab === "claude"
      icon: "refresh"
      busy: ClaudeService.refreshing
      onClicked: ClaudeService.refresh()
    }

    KitSwitch {
      accessibleName: "Ollama service"
      anchors.verticalCenter: parent.verticalCenter
      visible: root.tab === "ollama" && OllamaService.installed
      checked: OllamaService.running
      disabled: OllamaService.busy === "server"
      onToggled: OllamaService.setRunning(!OllamaService.running)
    }
  }

  KitChoices {
    model: [
      { label: "Claude", value: "claude", icon: "bot" },
      { label: "Ollama", value: "ollama", icon: "cpu" }
    ]
    current: root.tab
    onPicked: value => root.tab = value
  }

  KitLine {}

  Binding {
    target: OllamaService
    property: "watching"
    value: ClaudeService.popupOpen && root.tab === "ollama"
  }

  // ---- claude ----
  Column {
    width: parent.width
    visible: root.tab === "claude"
    spacing: Theme.gapGroup

    Column {
      width: parent.width
      spacing: Theme.gapWide

      KitLabel { text: "PLAN LIMITS" }

      Repeater {
        model: ClaudeService.limits

        Column {
          required property var modelData

          readonly property color tint: Theme.qualityColor(modelData.percent, ClaudeService.warning - 25, ClaudeService.warning)

          width: parent.width
          spacing: 5

          KitInfo {
            label: root.labels[modelData.kind] ?? modelData.kind.replace(/_/g, " ")
            value: modelData.percent + "%"
            valueColor: parent.tint
          }

          KitBar {
            value: modelData.percent / 100
            tint: parent.tint
          }

          KitText {
            text: root.resetsIn(modelData.resets_at)
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 2
          }
        }
      }

      KitText {
        visible: ClaudeService.limits.length === 0 && ClaudeService.error === ""
        text: "Loading…"
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 1
      }

      // when the limits are from; a failed refresh keeps them and says so
      KitText {
        width: parent.width
        visible: ClaudeService.fetchedAt > 0 || ClaudeService.error !== ""
        text: ClaudeService.fetchedAt > 0
          ? (ClaudeService.error !== "" ? "Couldn't refresh (" + ClaudeService.error + ") · data from " : "Updated ")
            + Qt.formatDateTime(new Date(ClaudeService.fetchedAt),
                                new Date(ClaudeService.fetchedAt).toDateString() === new Date().toDateString() ? "HH:mm" : "dd MMM HH:mm")
          : ClaudeService.error
        color: ClaudeService.error !== "" && ClaudeService.fetchedAt === 0 ? Theme.red : Theme.muted
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSize - 2
      }
    }

    KitLine {}

    Column {
      width: parent.width
      spacing: Theme.gapSmall

      KitLabel { text: "TODAY"; value: (ClaudeService.today.messages ?? 0) + " MESSAGES" }

      KitInfo { label: "Output";      value: Format.humanCount(ClaudeService.today.output ?? 0) }
      KitInfo { label: "Input";       value: Format.humanCount(ClaudeService.today.input ?? 0) }
      KitInfo { label: "Cache read";  value: Format.humanCount(ClaudeService.today.cache_read ?? 0) }
      KitInfo { label: "Cache write"; value: Format.humanCount(ClaudeService.today.cache_write ?? 0) }
    }

    KitLine {}

    Column {
      width: parent.width
      spacing: Theme.gapMedium

      KitLabel {
        text: "SESSIONS (" + ClaudeService.sessions.length + ")"
        value: ClaudeService.busy > 0 ? ClaudeService.busy + " BUSY" : ""
        valueColor: Theme.green
      }

      Repeater {
        model: ClaudeService.sessions

        Column {
          id: session

          required property var modelData

          readonly property bool busy: modelData.status === "busy"

          width: parent.width
          spacing: Theme.gapTight

          Item {
            width: parent.width
            height: name.implicitHeight

            KitText {
              id: name
              anchors { left: parent.left; right: statusText.left; rightMargin: Theme.gapMedium }
              text: session.modelData.name || "—"
              elide: Text.ElideRight
              font.weight: Font.ExtraBold
            }

            KitText {
              id: statusText
              anchors.right: parent.right
              text: session.modelData.status
              color: session.busy ? Theme.green : Theme.muted
              font.pixelSize: Theme.fontSize - 1
            }
          }

          KitText {
            width: parent.width
            text: root.shortPath(session.modelData.cwd) + " · v" + session.modelData.version
            elide: Text.ElideMiddle
            color: Theme.muted
            font.pixelSize: Theme.fontSize - 2
          }
        }
      }

      KitText {
        visible: ClaudeService.sessions.length === 0
        text: "No running sessions."
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 1
      }
    }
  }

  OllamaView {
    width: parent.width
    visible: root.tab === "ollama"
  }
}
