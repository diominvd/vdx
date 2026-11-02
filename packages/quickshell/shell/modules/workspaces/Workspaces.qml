import QtQuick
import Quickshell.Hyprland
import qs.config
import qs.kit

// Hyprland workspaces across all outputs; special workspaces are hidden.
// Drawn as digits, squares, dots, dashes or pills (Modules › Workspaces). Focused
// and visible workspaces are highlighted; a click activates. Colours fade
// and a new workspace opens up (Motion.bar).
Row {
  id: root

  readonly property string style: ModuleSettings.get("workspaces", "style", "numbers")
  // the shape styles draw no text: a square, a dot, a dash or a pill each
  readonly property bool shape: style === "squares" || style === "dots" || style === "dashes" || style === "pills"

  spacing: shape ? 4 : 0

  // desk 10 is key 0, so it sorts first: 0 1 2 … 9
  function order(ws) { return ws.id === 10 ? 0 : ws.id }
  readonly property var ordered: Hyprland.workspaces.values.slice().sort((a, b) => order(a) - order(b))

  // the Repeater remakes every item when the list changes: only a workspace
  // not seen before opens up; the ones there at start do not
  property var seen: ({})
  property bool started: false
  function isNew(id) {
    const fresh = started && !seen[id];
    seen[id] = true;
    return fresh;
  }
  // a timer, not Qt.callLater: it goes with the Row when a zone remakes it
  Timer { interval: 0; running: true; onTriggered: root.started = true }
  // a workspace closed and opened again is new again
  onOrderedChanged: {
    const ids = ordered.map(w => String(w.id));
    for (const id of Object.keys(seen)) if (!ids.includes(id)) delete seen[id];
  }

  Repeater {
    model: root.ordered

    Item {
      id: workspace

      required property var modelData

      readonly property bool highlighted: modelData.focused || modelData.active

      visible: !modelData.name.startsWith("special")
      readonly property color tone: area.containsMouse ? Theme.foreground0 : highlighted ? Theme.foreground1 : Theme.gray

      // pills: the focused / visible one stretches into a bar, the rest are dots
      readonly property real shapeWidth: root.style === "dashes" ? 12 : root.style === "pills" ? (highlighted ? 16 : 6) : 8

      implicitWidth: (root.shape ? shapeWidth + 2 : Math.max(label.implicitWidth, Theme.workspaceMinWidth) + 4) * grow
      implicitHeight: label.implicitHeight

      // a new workspace opens up from nothing and fades in (Motion.bar)
      property real grow: 1
      opacity: grow
      Component.onCompleted: if (root.isNew(modelData.id) && Motion.bar) growIn.start()
      NumberAnimation { id: growIn; target: workspace; property: "grow"; from: 0; to: 1; duration: Motion.normal; easing.type: Motion.easing }

      // the shapes: a filled one for the focused / visible, an outline for the
      // rest (dots are round); dashes and pills are always filled, in the tone
      KitGlow {
        z: -1
        anchors.centerIn: parent
        width: workspace.shapeWidth
        height: root.style === "dashes" ? 2 : root.style === "pills" ? 6 : 8
        target: "workspaces"
        lit: root.shape && workspace.highlighted
        tint: Theme.foreground0
        radius: root.style === "dots" ? 4 : root.style === "pills" ? 3 : 0
      }

      Rectangle {
        anchors.centerIn: parent
        visible: root.shape
        width: workspace.shapeWidth
        height: root.style === "dashes" ? 2 : root.style === "pills" ? 6 : 8
        radius: root.style === "dots" ? 4 : root.style === "pills" ? 3 : 0
        color: root.style === "dashes" || root.style === "pills" || workspace.highlighted ? workspace.tone : Qt.rgba(workspace.tone.r, workspace.tone.g, workspace.tone.b, 0)
        border.width: root.style === "dashes" || root.style === "pills" || workspace.highlighted ? 0 : Theme.hairline
        border.color: workspace.tone

        Behavior on color { enabled: Motion.bar; ColorAnimation { duration: Motion.slow; easing.type: Motion.tint } }
        Behavior on width { enabled: Motion.bar; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
      }

      KitText {
        id: label
        anchors.centerIn: parent
        visible: !root.shape
        // desk 10 is the key 0 (SUPER+0)
        text: workspace.modelData.id === 10 ? "0" : workspace.modelData.name.replace(/^name:/, "")
        color: workspace.tone

        Behavior on color { enabled: Motion.bar; ColorAnimation { duration: Motion.slow; easing.type: Motion.tint } }
      }

      MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: workspace.modelData.activate()
      }
    }
  }
}
