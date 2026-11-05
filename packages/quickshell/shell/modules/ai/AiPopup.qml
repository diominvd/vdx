import QtQuick
import qs.config
import qs.kit

// AI popup: Claude Code limits, today's tokens and sessions; Codex's limits; the Ollama tab.
KitFrame {
  id: root

  property string tab: "claude"
  // Modules › AI › Compact popup: the limits only, no today's tokens and no sessions
  readonly property bool compact: ModuleSettings.get("ai", "compact", false)

  function shortPath(path) {
    return path.replace(/^\/home\/[^/]+/, "~");
  }

  // ---- header ----
  KitHeader {
    icon: "bot"
    title: root.tab === "claude" ? "Claude Code" : root.tab === "codex" ? "Codex" : "Ollama"
    subtitle: root.tab === "codex" ? (CodexService.plan.toUpperCase() || "CODEX CLI")
      : root.tab === "claude"
      ? [ClaudeService.plan.toUpperCase(),
         ClaudeService.sessions.length > 0
           ? (ClaudeService.busy > 0 ? ClaudeService.busy + " WORKING" : ClaudeService.sessions.length + " IDLE")
           : "NO SESSIONS"].filter(s => s).join(" · ")
      : !OllamaService.installed ? "NOT INSTALLED"
      : OllamaService.running ? "RUNNING · V" + OllamaService.status.version
      : "STOPPED"
    subtitleColor: (root.tab === "claude" ? ClaudeService.busy > 0 : root.tab === "ollama" && OllamaService.running) ? Theme.green : Theme.muted

    KitButton {
      visible: root.tab !== "ollama"
      icon: "refresh"
      busy: root.tab === "codex" ? CodexService.refreshing : ClaudeService.refreshing
      onClicked: root.tab === "codex" ? CodexService.refresh() : ClaudeService.refresh()
    }

    KitSwitch {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.tab === "ollama" && OllamaService.installed
      checked: OllamaService.running
      disabled: OllamaService.busy === "server"
      onToggled: OllamaService.setRunning(!OllamaService.running)
    }
  }

  KitChoices {
    width: parent.width
    stretch: true
    model: [
      { label: "Claude", value: "claude", icon: "bot" },
      { label: "Codex",  value: "codex",  icon: "zap" },
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
    spacing: Theme.sectionGap

    LimitsView {
      limits: ClaudeService.limits
      fetchedAt: ClaudeService.fetchedAt
      error: ClaudeService.error
    }

    KitLine { visible: !root.compact }

    Column {
      width: parent.width
      visible: !root.compact
      spacing: Theme.gapSmall

      KitLabel { text: "TODAY"; value: (ClaudeService.today.messages ?? 0) + " MESSAGES" }

      KitInfo { label: "Output";      value: Format.humanCount(ClaudeService.today.output ?? 0) }
      KitInfo { label: "Input";       value: Format.humanCount(ClaudeService.today.input ?? 0) }
      KitInfo { label: "Cache read";  value: Format.humanCount(ClaudeService.today.cache_read ?? 0) }
      KitInfo { label: "Cache write"; value: Format.humanCount(ClaudeService.today.cache_write ?? 0) }
    }

    KitLine { visible: !root.compact }

    Column {
      width: parent.width
      visible: !root.compact
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

  // ---- codex ----
  LimitsView {
    visible: root.tab === "codex"
    limits: CodexService.limits
    fetchedAt: CodexService.fetchedAt
    error: CodexService.error
    stamp: "As of Codex's last answer, "
  }

  OllamaView {
    width: parent.width
    visible: root.tab === "ollama"
  }
}
