pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.config
import "../../kit/reply.js" as Reply

// Audio devices, application streams and volumes over Pipewire. The bar module
// and the popup only read these properties and call these functions.
Singleton {
  id: root

  // ---- tuning ----
  readonly property int portPollMs: 30000      // the fallback; changes come by `audio.sh --listen`
  readonly property int listenRestartMs: 3000
  readonly property int maxPercent: 150  // the bar wheel may push the sink this far
  readonly property int scrollStep: 5    // %, a wheel step on the bar
  readonly property string script: Paths.scriptsDir + "/audio.sh"

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var sinks: nodesOf(PwNodeType.AudioSink)
  readonly property var sources: nodesOf(PwNodeType.AudioSource)
  readonly property var streams: nodesOf(PwNodeType.AudioOutStream)   // application playback

  readonly property bool muted: sink?.audio?.muted ?? false
  readonly property int volume: Math.round((sink?.audio?.volume ?? 0) * 100)

  // Ports per device ({port, type, active, list} by node name, see audio.sh):
  // short device names ("Speakers", "Headphones") and the headphones state.
  property var ports: ({})
  property bool portBusy: false
  property string portError: ""
  property string portErrorTarget: ""
  readonly property bool headphones: jackIn || (ports[sink?.name]?.type ?? "").startsWith("Head")

  // Device lists for the popup: one entry per port, so the built-in card shows
  // both "Speakers" and "Headphones". The speakers are hidden while the codec
  // reports them unavailable (headphones in); other unplugged ports are left out.
  // headphones in: the HDMI / DisplayPort sinks are left out too, unless one is in use
  readonly property var outputs: entriesOf(sinks.filter(n => !(jackIn && ports[n.name]?.type === "HDMI" && n.name !== sink?.name)))
  readonly property var inputs: entriesOf(sources)
  readonly property string outputKey: keyOf(sink)
  readonly property string inputKey: keyOf(source)
  // the port in use, when it is not in the list (not detected): a note for the dropdown
  readonly property string outputNote: noteOf(sink, outputs, outputKey)
  readonly property string inputNote: noteOf(source, inputs, inputKey)

  // Whether output or input is still live; the header switch mutes both.
  readonly property bool live: !(sink?.audio?.muted ?? true) || !(source?.audio?.muted ?? true)

  // headphones in the jack: a sink's headphone port is available (its jack
  // detection works, unlike the mic's)
  readonly property bool jackIn: sinks.some(n => (ports[n.name]?.list ?? []).some(p => p.type.startsWith("Head") && p.available))

  function nodesOf(type) {
    return Pipewire.nodes.values.filter(n => n.type === type);
  }

  function nameOf(node) {
    if (!node) return "—";
    return node.properties["application.name"] || ports[node.name]?.port
        || node.description || node.nickname || node.name;
  }

  function keyOf(node) { return node ? node.name + "|" + (ports[node.name]?.active ?? "") : ""; }

  // the port in use is not among the entries: it is not detected (unplugged, or a jack mic
  // the codec can't tell is plugged); the box shows the note instead of an entry
  function noteOf(node, entries, key) {
    if (!node || entries.some(e => e.key === key)) return "";
    const info = ports[node.name];
    const p = (info?.list ?? []).find(x => x.name === info.active);
    return p ? "Not detected: " + p.port : "";
  }

  // The lists depend on what the codec reports, never on which port is in use: a
  // selection does not change their shape. A port reported "not available" is left out.
  // The built-in mic is always listed; a jack mic that can't tell it is plugged (availability
  // unknown) is listed only while headphones are in.
  function entriesOf(nodes) {
    const entries = [];
    for (const node of nodes) {
      const info = ports[node.name];
      const list = (info?.list ?? []).filter(p => p.name.includes("internal")
                                               || (p.available && !(p.unknown && p.type === "Mic" && !root.jackIn)));
      if (list.length === 0)
        entries.push({ key: node.name + "|" + (info?.active ?? ""), node: node, port: "", label: nameOf(node), about: node.description });
      for (const p of list)
        entries.push({ key: node.name + "|" + p.name, node: node, port: p.name, label: p.port, about: node.description });
    }
    // ports with the same name on different devices get the device appended
    return entries.map(e => Object.assign({}, e, {
      label: (entries.filter(o => o.label === e.label).length > 1 ? e.label + " · " + e.about : e.label).toUpperCase()
    }));
  }

  function select(entry) {
    if (!entry || portBusy) return;
    const sink = entry.node.type === PwNodeType.AudioSink;
    if (sink) setSink(entry.node); else setSource(entry.node);
    portError = "";
    portErrorTarget = sink ? "output" : "input";
    if (entry.port !== "") {
      portBusy = true;
      portActionProc.command = ["pactl", sink ? "set-sink-port" : "set-source-port", entry.node.name, entry.port];
      portActionProc.running = true;
    }
  }

  function setSink(node) { Pipewire.preferredDefaultAudioSink = node; }
  function setSource(node) { Pipewire.preferredDefaultAudioSource = node; }

  function toggleMute(node) {
    if (node?.audio) node.audio.muted = !node.audio.muted;
  }

  function setMuted(muted) {
    for (const node of [sink, source])
      if (node?.audio) node.audio.muted = muted;
  }

  // value: 0..1 of 100 %; the bar wheel may push the sink up to root.maxPercent.
  function setVolume(node, value) {
    if (node?.audio) node.audio.volume = Math.max(0, Math.min(root.maxPercent / 100, value));
  }

  function stepVolume(percent) {
    setVolume(sink, (volume + percent) / 100);
  }

  PwObjectTracker {
    objects: [root.sink, root.source].concat(root.streams)
  }

  Process {
    id: portActionProc
    property bool started: false
    onStarted: started = true
    onRunningChanged: {
      if (running) return;
      if (started) { started = false; return; }
      root.portBusy = false;
      root.portError = "could not start changing the audio port";
      portRefresh.restart();
    }
    onExited: exitCode => {
      root.portBusy = false;
      root.portError = exitCode === 0 ? "" : "could not change the audio port";
      portRefresh.restart();
    }
  }

  Process {
    id: portProc
    command: ["bash", root.script]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const ports = Reply.parse(text, "audio.sh", null);
        if (ports) root.ports = ports;
      }
    }
  }

  Timer {
    id: portRefresh
    interval: 300
    onTriggered: portProc.running = true
  }

  Timer {
    interval: root.portPollMs
    running: true
    repeat: true
    onTriggered: portProc.running = true
  }

  // a jack, a profile, the default device, a device come or gone: the ports
  // again, once the burst of events is over (portRefresh)
  Process {
    id: listenProc
    command: ["bash", root.script, "--listen"]
    running: true
    stdout: SplitParser { onRead: portRefresh.restart() }
    onExited: listenRestart.restart()
  }

  Timer {
    id: listenRestart
    interval: root.listenRestartMs
    onTriggered: listenProc.running = true
  }
}
