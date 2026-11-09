import QtQuick
import Quickshell
import Quickshell.Io
import qs.apps.files
import qs.apps.shellmanager
import qs.config
import qs.kit

// About: what this shell believes, how it is put together, who made it and
// what it runs on, the options as one file (export, import, reset everything:
// scripts/settings_io.py) and a forced restart of the shell.
Column {
  id: root
  property string tab: "system"
  readonly property var tabs: [{ label: "System", value: "system" }, { label: "Settings", value: "settings" }, { label: "About", value: "about" }]
  function jump(key) { tab = key === "settings" || key === "system" ? key : "about"; }

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "info"
  readonly property string title: "About"
  readonly property string description: "Version, your settings and the shell itself."

  // groups for the Shell Manager's sidebar: a click scrolls to `y`
  readonly property var jumps: [
    { key: "philosophy", label: "Philosophy", y: philosophy.y },
    { key: "concept",    label: "Concept",    y: concept.y },
    { key: "author",     label: "Author",     y: author.y },
    { key: "settings",   label: "Settings",   y: settings.y },
    { key: "system",     label: "System",     y: system.y }
  ].filter(j => tab === "about" ? !["settings", "system"].includes(j.key) : j.key === tab)

  property var versions: ({})
  property string ioStatus: ""                 // the last export, on the group's label
  property string healthReport: ""
  property string resourceReport: ""
  property var healthItems: []
  property var resourceMetrics: []

  QtObject { id: sectionIn; property real shown: 1 }
  NumberAnimation { id: sectionAnim; target: sectionIn; property: "shown"; from: 0; to: 1; duration: Motion.ms(240); easing.type: Motion.easing }
  onTabChanged: if (Motion.tabs) sectionAnim.restart()

  function setHealthReport(raw) {
    healthReport = raw;
    healthItems = raw.replace(/\x1b\[[0-9;]*m/g, "").split("\n")
      .map(line => line.trim()).filter(line => line !== "" && !line.startsWith(":: Doctor:"))
      .map(line => {
        const match = line.match(/^([✓!✗])\s*(.*)$/);
        const body = match ? match[2] : line;
        const parts = body.split(" · ");
        return { level: match && match[1] === "✗" ? "error" : match && match[1] === "✓" ? "ok" : "warning",
                 summary: parts[0], fix: parts.slice(1).join(" · ") };
      });
  }

  function formatMemory(kib) {
    const mib = Number(kib) / 1024;
    return mib >= 1024 ? (mib / 1024).toFixed(1) + " GiB" : Math.round(mib) + " MiB";
  }

  function formatElapsed(value) {
    const dayParts = value.split("-");
    const clock = dayParts[dayParts.length - 1].split(":").map(Number);
    const days = dayParts.length > 1 ? Number(dayParts[0]) : 0;
    const minutes = days * 1440 + (clock.length === 3 ? clock[0] * 60 : 0) + clock[clock.length - 2];
    if (minutes >= 60) return Math.floor(minutes / 60) + "h " + String(minutes % 60).padStart(2, "0") + "m";
    return minutes + "m " + String(clock[clock.length - 1]).padStart(2, "0") + "s";
  }

  function setResourceReport(raw) {
    resourceReport = raw;
    const fields = raw.trim().split(/\s+/);
    if (fields.length < 6 || fields.some(value => value === "")) { resourceMetrics = []; return; }
    resourceMetrics = [
      { label: "Memory", value: formatMemory(fields[1]) },
      { label: "Virtual memory", value: formatMemory(fields[2]) },
      { label: "CPU", value: fields[4] + "%" },
      { label: "Runtime", value: formatElapsed(fields[3]) },
      { label: "Threads", value: fields[5] },
      { label: "Process", value: fields[0] }
    ];
  }

  function checkHealth() {
    healthReport = "Checking…";
    healthItems = [];
    doctorProc.running = false;
    doctorProc.command = ["python3", ThemeService.dotfiles + "/install.py", "doctor"];
    doctorProc.running = true;
  }
  function measureShell() {
    resourceReport = "Measuring…";
    measureProc.running = false;
    measureProc.command = ["ps", "-p", String(Quickshell.processId), "-o", "pid=,rss=,vsz=,etime=,%cpu=,nlwp="];
    measureProc.running = true;
  }

  Process {
    id: doctorProc
    stdout: StdioCollector {
      onStreamFinished: root.setHealthReport(text.trim() || "No diagnostic output")
    }
  }
  Process {
    id: measureProc
    stdout: StdioCollector {
      onStreamFinished: root.setResourceReport(text.trim() || "No process data")
    }
  }

  // import and reset stop this shell, write the files and start it again: run
  // outside it, a failure told by a notification
  function detached(args) {
    Quickshell.execDetached(["bash", "-c", "out=$(python3 \"$0\" \"$@\") || notify-send -a Shell \"Settings not changed\" "
                             + "\"$(jq -r .error <<<\"$out\")\"", Paths.scriptsDir + "/settings_io.py"]
                            .concat(args, ["--pid", String(Quickshell.processId)]));
  }

  function exportTo(args) {
    ioProc.command = ["python3", Paths.scriptsDir + "/settings_io.py"].concat(args);
    ioProc.running = true;
  }

  Process {
    id: ioProc
    stdout: StdioCollector {
      onStreamFinished: {
        let r = {};
        try { r = JSON.parse(text); } catch (e) { r = { ok: false, error: "no answer" }; }
        root.ioStatus = r.ok ? "Exported" : r.error;
      }
    }
  }

  spacing: Theme.gapGroup

  Component.onCompleted: if (visible) versionProc.running = true
  onVisibleChanged: if (visible && !versionProc.running) versionProc.running = true

  Process {
    id: versionProc
    command: ["bash", "-c", "printf '%s\\n' \"$(hyprctl version -j | jq -r .version)\" \"$(qs --version | awk '{print $2}')\" "
                          + "\"$(uname -r)\" \"$(cat \"$1/.theme\" 2>/dev/null || echo gruvbox)\" \"$(git -C \"$1\" rev-parse --short HEAD)\"",
              "_", ThemeService.dotfiles]
    stdout: StdioCollector {
      onStreamFinished: {
        const [hypr, qs, kernel, theme, commit] = text.trim().split("\n");
        root.versions = { hypr, qs, kernel, theme, commit };
      }
    }
  }

  component Paragraph: KitText {
    width: parent.width
    wrapMode: Text.WordWrap
    color: Theme.foreground2
    lineHeight: 1.15
  }

  Column {
  spacing: Theme.sectionGap

    width: parent.width; visible: root.tab === "about"
    opacity: sectionIn.shown
  // ---- philosophy ----
  KitLabel { id: philosophy; text: "PHILOSOPHY" }

  Paragraph {
    text: "Quiet by default. A desktop should stay out of the way until you need it, then answer at once "
        + "and say exactly what it is doing — nothing blinks, nothing guesses."
  }
  Paragraph {
    text: "Terminal-minded: one monospace font, sharp corners, nearly monochrome. Colour is state — "
        + "green means fine, yellow wants attention, red is wrong. Your accent, if you set one, marks only what you choose."
  }
  Paragraph {
    text: "Yours to change, never to fight: every option lives in one place, every change shows at once, "
        + "and anything touching the system tells you what it will do before it does it."
  }

  KitLine {}

  // ---- concept ----
  KitLabel { id: concept; text: "CONCEPT" }

  Paragraph {
    text: "Plain files in one git repository. Each program's config is linked into ~/.config file by file "
        + "(install.py), a theme overrides only the files it colours, and /etc gets copies, never links."
  }
  Paragraph {
    text: "The shell is one Quickshell config: a bar of modules, each a script that talks to the system, "
        + "a service that keeps the state and a view that only reads it — all drawn from the same small kit "
        + "of parts, so a new one looks as if it was always there."
  }
  Paragraph {
    text: "Apps of the shell — this Shell Manager, the Task Manager, the Cleaner, the capture tool — are "
        + "windows of their own, opened by a key, set up here."
  }

  KitLine {}

  // ---- author ----
  KitLabel { id: author; text: "AUTHOR" }

  KitRow {
    label: "diominvd"
    hint: "Made for his own laptop, shared as it is"

    KitButton {
      width: Theme.buttonWidth
      icon: "external"
      text: "GitHub"
      onClicked: Qt.openUrlExternally("https://github.com/diominvd/dotfiles")
    }
  }

  KitLine {}

    KitGrouper {}
  }
  Column {
  spacing: Theme.sectionGap

    width: parent.width; visible: root.tab === "settings"
    opacity: sectionIn.shown
  // ---- system ----
  KitLabel { id: settings; text: "SETTINGS"; value: root.ioStatus.toUpperCase() }

  KitRow {
    label: "Export"
    hint: "Options, bar layout, windows"

    KitButton {
      width: Theme.buttonWidth
      icon: "arrow-up"
      text: "Export…"
      busy: ioProc.running
      onClicked: FilesService.pickFolder("Export the settings to", FilesService.home,
                                         p => { if (p !== "") root.exportTo(["export", p + "/shell-settings.json"]); })
    }
  }

  KitRow {
    label: "Import"
    hint: "Replaces options, restarts the shell"

    KitButton {
      width: Theme.buttonWidth
      icon: "download"
      text: "Import…"
      onClicked: FilesService.pick("Import the settings", FilesService.home, false, ["application/json"],
                                   p => { if (p !== "") root.detached(["import", p]); })
    }
  }

  KitRow {
    label: "Reset everything"
    hint: "Defaults, the old set kept as a file"

    KitResetButton {
      width: Theme.buttonWidth
      onReset: root.detached(["reset"])
    }
  }

  KitText {
    visible: root.ioStatus !== ""
    width: parent.width
    text: root.ioStatus
    color: root.ioStatus === "Exported" ? Theme.green : Theme.red
    wrapMode: Text.WordWrap
    font.pixelSize: Theme.fontSize - 1
  }

  KitLine {}

    KitGrouper {}
  }
  Column {
    width: parent.width; visible: root.tab === "system"
  opacity: sectionIn.shown
  KitLabel { id: system; text: "SYSTEM"; value: (root.versions.commit ?? "").toUpperCase() }

  KitInfo { width: parent.width; label: "Theme"; value: root.versions.theme ?? "--" }
  KitInfo { width: parent.width; label: "Hyprland"; value: root.versions.hypr ?? "--" }
  KitInfo { width: parent.width; label: "Quickshell"; value: root.versions.qs ?? "--" }
  KitInfo { width: parent.width; label: "Kernel"; value: root.versions.kernel ?? "--" }

  KitLine {}

  KitLabel { text: "DIAGNOSTICS & RECOVERY" }
  KitRow {
    label: "Machine health"
    hint: "Files, services and the running desktop"
    KitButton { width: Theme.buttonWidth; icon: "activity"; text: "Run check"; busy: doctorProc.running; onClicked: root.checkHealth() }
  }
  KitRow {
    label: "Shell resources"
    hint: "A one-time snapshot of the shell process"
    KitButton { width: Theme.buttonWidth; text: "Measure"; busy: measureProc.running; onClicked: root.measureShell() }
  }
  KitRow {
    label: "Recovery"
    hint: "Restores the last backed-up files"
    KitButton {
      width: Theme.buttonWidth
      icon: "rotate-ccw"
      text: "Rollback…"
      onClicked: Quickshell.execDetached(["kitty", "-e", "python3", ThemeService.dotfiles + "/install.py", "rollback"])
    }
  }

  // a fresh process: this one is killed, Hyprland starts a new one (through
  // the supervisor, as at login: FontService.restartShell)
  KitRow {
    label: "Restart the shell"
    hint: "Kills Quickshell and starts it anew"

    KitButton {
      width: Theme.buttonWidth
      icon: "refresh"
      text: "Restart"
      onClicked: FontService.restartShell()
    }
  }

  // what a check or a measure found stands under the rows: between them it splits the group's box
  Column {
    visible: root.healthItems.length > 0
    width: parent.width
    spacing: Theme.gapTight

    KitNotice {
      shown: root.healthItems.length === 1 && root.healthItems[0].level === "ok"
      width: parent.width
      icon: "check"
      tone: Theme.green
      title: "System healthy"
      text: "Managed files, services and desktop checks passed."
    }

    Repeater {
      model: root.healthItems.filter(item => item.level !== "ok")
      KitRow {
        required property var modelData
        label: modelData.summary
        hint: modelData.fix !== "" ? "Suggested fix: " + modelData.fix : ""
        labelColor: modelData.level === "error" ? Theme.red : Theme.yellow
      }
    }

    KitGrouper {}
  }
  KitNotice {
    shown: root.resourceMetrics.length > 0 || (!measureProc.running && root.resourceReport !== "")
    width: parent.width
    icon: root.resourceMetrics.length > 0 ? "activity" : "info"
    tone: root.resourceMetrics.length > 0 ? Theme.clear : Theme.red
    title: root.resourceMetrics.length > 0 ? "Process snapshot" : "Snapshot unavailable"
    text: root.resourceMetrics.length > 0
      ? root.resourceMetrics.map(metric => metric.label + " " + metric.value).join(" · ")
      : root.resourceReport
  }

    KitGrouper {}
  }
  KitGrouper {}
}
