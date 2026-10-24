import QtQuick
import Quickshell.Hyprland
import qs.config
import qs.kit

// Hyprland workspaces across all outputs; special workspaces are hidden.
// Drawn as digits, squares, dots or dashes (Modules › Workspaces). Focused
// and visible workspaces are highlighted; a click activates. Colours fade
// and a new workspace opens up (Motion.bar).
Row {
  id: root

  readonly property string style: ModuleSettings.get("workspaces", "style", "numbers")
  // the shape styles draw no text: a square, a dot or a dash each
  readonly property bool shape: style === "squares" || style === "dots" || style === "dashes"

  spacing: shape ? 4 : 0

  // desk 10 is key 0, so it sorts first: 0 1 2 … 9
  function order(ws) { return ws.id === 10 ? 0 : ws.id }
  readonly property var ordered: Hyprland.workspaces.values.slice().sort((a, b) => order(a) - order(b))
  readonly property var visibleWorkspaces: ordered.filter(ws => !ws.name.startsWith("special"))

  function focusWorkspace(index) {
    const target = workspaceRepeater.itemAt(index);
    if (target) target.forceActiveFocus();
  }

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
    id: workspaceRepeater
    model: root.visibleWorkspaces

    Item {
      id: workspace

      required property var modelData

      readonly property bool highlighted: modelData.focused || modelData.active

      activeFocusOnTab: highlighted || (index === 0 && !root.visibleWorkspaces.some(ws => ws.focused || ws.active))
      Accessible.role: Accessible.Button
      Accessible.name: "Workspace " + modelData.id
      Accessible.description: highlighted ? "Current or active workspace" : "Switch to workspace " + modelData.id

      Keys.onPressed: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
        if (!event.isAutoRepeat) { modelData.activate(); }
        event.accepted = true;
      }
      Keys.onLeftPressed: event => {
        const next = Math.max(0, index - 1);
        if (next !== index) { root.visibleWorkspaces[next].activate(); Qt.callLater(() => root.focusWorkspace(next)); }
        event.accepted = true;
      }
      Keys.onRightPressed: event => {
        const next = Math.min(root.visibleWorkspaces.length - 1, index + 1);
        if (next !== index) { root.visibleWorkspaces[next].activate(); Qt.callLater(() => root.focusWorkspace(next)); }
        event.accepted = true;
      }
      Keys.onHomePressed: event => {
        if (root.visibleWorkspaces.length > 0) { root.visibleWorkspaces[0].activate(); Qt.callLater(() => root.focusWorkspace(0)); }
        event.accepted = true;
      }
      Keys.onEndPressed: event => {
        const last = root.visibleWorkspaces.length - 1;
        if (last >= 0) { root.visibleWorkspaces[last].activate(); Qt.callLater(() => root.focusWorkspace(last)); }
        event.accepted = true;
      }
      readonly property color tone: area.containsMouse
        ? (highlighted ? Theme.accentFor("modules", Theme.yellow) : Theme.foreground0)
        : (highlighted ? Theme.accentFor("modules", Theme.foreground1) : Theme.gray)

      implicitWidth: (root.shape ? (root.style === "dashes" ? 14 : 10) : Math.max(label.implicitWidth, Theme.workspaceMinWidth) + 4) * grow
      implicitHeight: label.implicitHeight

      // a new workspace opens up from nothing and fades in (Motion.bar)
      property real grow: 1
      opacity: grow
      Component.onCompleted: if (root.isNew(modelData.id) && Motion.bar) growIn.start()
      NumberAnimation { id: growIn; target: workspace; property: "grow"; from: 0; to: 1; duration: Motion.normal; easing.type: Motion.easing }

      // the shapes: a filled one for the focused / visible, an outline for the
      // rest (dots are round); dashes are always filled, in the tone
      Rectangle {
        anchors.centerIn: parent
        visible: root.shape
        width: root.style === "dashes" ? 12 : 8
        height: root.style === "dashes" ? 2 : 8
        radius: root.style === "dots" ? 4 : 0
        color: root.style === "dashes" || workspace.highlighted ? workspace.tone : Qt.rgba(workspace.tone.r, workspace.tone.g, workspace.tone.b, 0)
        border.width: root.style === "dashes" || workspace.highlighted ? 0 : Theme.hairline
        border.color: workspace.tone

        Behavior on color { enabled: Motion.bar; ColorAnimation { duration: Motion.slow; easing.type: Motion.tint } }
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

      Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: workspace.activeFocus ? 2 : 0
        border.color: Theme.foreground0
        radius: Theme.radiusControl
        z: 1
      }

      MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { workspace.forceActiveFocus(); workspace.modelData.activate(); }
      }
    }
  }
}
