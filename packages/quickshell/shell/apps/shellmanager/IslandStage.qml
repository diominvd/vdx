import QtQuick
import qs.bar
import qs.config
import qs.kit

// Bar › Layout, Island style: the resting pill at 1:1 on a well, drawn as the island
// draws it (Bezel: a module with a whole is its ring, bar/Complications.qml; the rest
// its icon and name). A click on a module selects it for the options under the rows; a
// drag moves it along the pill (left of the clock: START, right: END), down off the
// pill takes it out.
Rectangle {
  id: root

  property bool kitUnboxed: true
  property var start: []                        // ids, LEFT of the clock
  property var end: []                          // ids, RIGHT of it
  property bool clock: true
  property string selectedId: ""
  signal selected(string id)
  signal moved(string id, string zone, int index)   // index in the zone as it is now (BarPage.drop)
  signal removed(string id)

  // where a drag let go: the zone by the clock's centre, the index by the neighbours' centres
  function dropAt(id, x, y) {
    if (Math.abs(y) > Theme.islandHeight) { removed(id); return; }
    const centre = it => it.mapToItem(line, it.width / 2, 0).x;
    const clockX = clockText.visible ? centre(clockText)
                 : (startRep.count > 0 && endRep.count > 0) ? (centre(startRep.itemAt(startRep.count - 1)) + centre(endRep.itemAt(0))) / 2
                 : line.width / 2;
    const zone = x < clockX ? "start" : "end";
    const rep = zone === "start" ? startRep : endRep;
    const ids = zone === "start" ? start : end;
    let before = 0;
    for (let i = 0; i < rep.count; i++) {
      const it = rep.itemAt(i);
      if (it && ids[i] !== id && centre(it) < x) before++;
    }
    const current = ids.indexOf(id);
    // BarPage.drop counts the dragged one still in its place
    moved(id, zone, before + (current >= 0 && current <= before ? 1 : 0));
  }

  implicitHeight: Theme.islandHeight + 2 * Theme.gapGroup + caption.implicitHeight + Theme.gapSmall
  radius: Theme.radiusCard
  color: Theme.background0   // a well
  border.width: Theme.hairline
  border.color: Theme.controlLineRest

  property date now: new Date()
  Timer { interval: 30000; running: root.visible; repeat: true; triggeredOnStart: true; onTriggered: root.now = new Date() }

  Rectangle {
    id: pill
    anchors.horizontalCenter: parent.horizontalCenter
    y: Theme.gapGroup
    width: Math.min(parent.width - 2 * Theme.gapWide, line.implicitWidth + 2 * Theme.gapGroup)
    height: Theme.islandHeight
    radius: Math.min(Theme.barRadiusFor(height), Theme.islandRadius)
    color: Theme.background0
    border.width: Theme.islandFrameWidth
    border.color: Theme.background2
    // no clip: a module dragged off the pill stays in sight

    Row {
      id: line
      anchors.centerIn: parent
      spacing: Theme.gapWide

      Repeater { id: startRep; model: root.start; delegate: entry }
      KitText {
        id: clockText
        anchors.verticalCenter: parent.verticalCenter
        visible: root.clock
        text: Qt.formatDateTime(root.now, ModuleSettings.get("clock", "twelveHour", false) ? "h:mm" : "HH:mm")
        font.weight: Font.Bold
      }
      Repeater { id: endRep; model: root.end; delegate: entry }
    }
  }

  KitText {
    id: caption
    anchors { horizontalCenter: parent.horizontalCenter; top: pill.bottom; topMargin: Theme.gapSmall }
    text: root.start.length + root.end.length === 0 ? "Nothing beside the clock: drag a module into START or END"
                                                    : "Stage · 1:1 · click to select · drag to move · drag down to remove"
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 2
  }

  Component {
    id: entry
    Item {
      id: slot
      required property string modelData
      readonly property bool separator: BarLayout.isSeparator(modelData)
      readonly property var rings: !separator && ShellSettings.pillRings ? Complications.of(modelData) : []
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      implicitWidth: separator ? 1 : rings.length > 0 ? ringRow.implicitWidth : face.implicitWidth
      implicitHeight: Theme.islandHeight - 6

      // picked: a ring around it, as a picked card
      Rectangle {
        anchors { fill: parent; margins: -Theme.gapHair }
        visible: root.selectedId === slot.modelData
        radius: Theme.radiusFor(height)
        color: Theme.clear
        border.width: Theme.ring
        border.color: Theme.focusRing
      }

      Rectangle {
        anchors.centerIn: parent
        visible: slot.separator
        width: Theme.dividerThickness
        height: Theme.fontSize
        color: Theme.dividerColor
      }

      Row {
        id: ringRow
        anchors.verticalCenter: parent.verticalCenter
        visible: slot.rings.length > 0
        spacing: Theme.gapSmall
        Repeater {
          model: slot.rings.length
          KitRing {
            required property int index
            readonly property var spec: slot.rings[index] ?? ({})
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.ringPill
            kind: spec.kind ?? "fill"
            value: spec.value ?? 0
            text: spec.text ?? ""
            icon: spec.icon ?? ""
            tint: spec.tint ?? Theme.foreground1
            on: spec.on ?? true
            quiet: spec.quiet ?? false
            steps: spec.steps ?? 5
          }
        }
      }

      // no whole: what the strip shows, its icon and name
      Row {
        id: face
        anchors.verticalCenter: parent.verticalCenter
        visible: !slot.separator && slot.rings.length === 0
        spacing: Theme.gapSmall
        KitIcon { anchors.verticalCenter: parent.verticalCenter; name: BarLayout.icon(slot.modelData); size: Theme.fontSize + 2; tint: Theme.foreground0 }
        KitText { anchors.verticalCenter: parent.verticalCenter; text: BarLayout.label(slot.modelData); font.pixelSize: Theme.fontSize - 1 }
      }

      // dragged, it follows the pointer (over the others) and fades as it leaves the pill
      z: drag.active ? 2 : 0
      transform: Translate { x: drag.active ? drag.translation.x : 0; y: drag.active ? drag.translation.y : 0 }
      opacity: drag.active && Math.abs(drag.translation.y) > Theme.islandHeight ? 0.4 : 1

      TapHandler {
        cursorShape: Qt.PointingHandCursor
        onTapped: root.selected(slot.modelData)
      }
      DragHandler {
        id: drag
        target: null
        cursorShape: Qt.ClosedHandCursor
        // the last move, kept: the translation is not to be trusted once the gesture ends
        property point last: Qt.point(0, 0)
        onTranslationChanged: if (active) last = translation
        onActiveChanged: {
          if (active) { last = Qt.point(0, 0); return; }
          // the slot is a child of the line: its place there, untransformed, plus the move
          root.dropAt(slot.modelData, slot.x + slot.width / 2 + last.x, last.y);
        }
      }
    }
  }
}
