import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.config
import qs.kit
import qs.modules.windows

// The floating mode's overview, like Windows' Task View: the workspaces as a strip
// of small previews, and under it the windows of the chosen one in an even grid
// (floating windows overlap, so their places would hide each other). A click on
// a preview chooses the workspace, a double click goes there; a click on a window
// brings it up, its cross closes it. Minimized windows show dim, as in the switcher.
Item {
  id: tv

  required property var overview

  property int deskIndex: 0
  property int winIndex: 0
  readonly property int deskId: overview.rowIds[deskIndex] ?? overview.activeId
  // the chosen workspace's windows; replaced only when the set (or its order) changes, so
  // a change of a title or a place does not remake every card and its picture
  property var wins: []
  readonly property string winKey: windowsOf(deskId).map(t => t.address).join(",")
  onWinKeyChanged: wins = windowsOf(deskId)
  readonly property int cols: Math.max(1, Math.min(3, wins.length))

  // the workspace's windows, the most recently used first (minimized ones too)
  function windowsOf(id) {
    return Hyprland.toplevels.values
      .filter(t => t.workspace?.id === id || (Hypr.minimized(t) && Hypr.tagsOf(t).includes("min" + id)))
      .sort((a, b) => (a.lastIpcObject?.focusHistoryID ?? 1000) - (b.lastIpcObject?.focusHistoryID ?? 1000));
  }

  // 0 -> 1 as it opens: the previews, then the windows, come in one after another
  property real intro: 1
  NumberAnimation { id: introAnim; target: tv; property: "intro"; from: 0; to: 1; duration: Motion.slow * 1.3; easing.type: Motion.easing }

  // on opening: the workspace in use, its window in use
  function reset() {
    intro = Motion.panels ? 0 : 1;
    if (Motion.panels) introAnim.restart();
    deskIndex = Math.max(0, overview.rowIds.indexOf(overview.activeId));
    winIndex = 0;
    wins = windowsOf(deskId);
  }

  function moveDesk(d) {
    deskIndex = Math.max(0, Math.min(overview.rowCount - 1, deskIndex + d));
    winIndex = 0;
  }

  function moveWin(dx, dy) {
    if (wins.length > 0) winIndex = Math.max(0, Math.min(wins.length - 1, winIndex + dx + dy * cols));
  }

  function pick() {
    const t = wins[winIndex];
    if (!t) { overview.goTo(deskId); return; }
    if (Hypr.minimized(t)) { overview.open = false; WindowsService.restore(Hypr.addr(t)); }
    else overview.focus(t);
  }

  // ---- the strip of workspaces ----
  readonly property real gapDesk: Theme.gapWide * 2
  readonly property int deskCount: overview.rowCount
  readonly property real deskW: Math.min(260, (width * 0.8 - (deskCount - 1) * gapDesk) / Math.max(1, deskCount))
  readonly property real deskH: deskW * overview.mh / overview.mw
  readonly property real stripTop: height * 0.08

  Row {
    id: strip
    y: tv.stripTop
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: tv.gapDesk

    Repeater {
      model: tv.deskCount

      Column {
        id: desk
        required property int index
        readonly property int wsId: overview.rowIds[index]
        readonly property bool chosen: index === tv.deskIndex
        readonly property var members: tv.windowsOf(wsId)
        readonly property real appear: Math.max(0, Math.min(1, tv.intro * 2 - index * 0.12))
        spacing: Theme.gapMedium
        opacity: appear
        y: (1 - appear) * -16

        Rectangle {
          width: tv.deskW
          height: tv.deskH
          radius: Theme.radiusCard
          color: Theme.background1
          clip: true
          opacity: desk.chosen ? 1 : 0.6
          Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
          border.width: desk.chosen ? Theme.ring : Theme.hairline
          border.color: desk.chosen ? Theme.foreground0 : Theme.gray

          // the windows where they are, to scale
          Repeater {
            model: desk.members.filter(t => !Hypr.minimized(t))

            Rectangle {
              required property var modelData
              readonly property var ipc: modelData.lastIpcObject ?? {}
              readonly property real s: tv.deskW / overview.mw
              x: ((ipc.at?.[0] ?? 0) - (overview.monitor?.x ?? 0)) * s
              y: ((ipc.at?.[1] ?? 0) - (overview.monitor?.y ?? 0)) * s
              width: (ipc.size?.[0] ?? 0) * s
              height: (ipc.size?.[1] ?? 0) * s
              radius: Math.min(width, height) * 0.06
              color: Theme.background3
              border.width: Theme.hairline
              border.color: Theme.gray
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { tv.deskIndex = desk.index; tv.winIndex = 0; }
            onDoubleClicked: overview.goTo(desk.wsId)
          }
        }

        KitText {
          text: desk.wsId + "  ·  " + (desk.members.length === 0 ? "Empty" : desk.members.length + (desk.members.length === 1 ? " window" : " windows"))
          color: desk.chosen ? Theme.foreground0 : Theme.muted
          font.pixelSize: Theme.fontSize - 2
          font.letterSpacing: 1
        }
      }
    }
  }

  // ---- the windows of the chosen workspace ----
  readonly property real gridGap: Theme.gapWide * 2
  readonly property real cellW: Math.min(520, (width * 0.84 - (cols - 1) * gridGap) / cols)
  readonly property real barH: 34
  readonly property real cellH: cellW * 0.58 + barH
  readonly property real gridTop: stripTop + deskH + 90
  readonly property real gridW: cols * cellW + (cols - 1) * gridGap

  KitText {
    visible: tv.wins.length === 0
    anchors.horizontalCenter: parent.horizontalCenter
    y: tv.gridTop + 40
    text: "No windows here"
    color: Theme.muted
  }

  Flickable {
    id: scroller
    visible: tv.wins.length > 0
    x: (tv.width - tv.gridW) / 2
    y: tv.gridTop
    width: tv.gridW
    height: tv.height - tv.gridTop - 90
    contentWidth: grid.width
    contentHeight: grid.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Behavior on contentY { enabled: Motion.controls && !scroller.moving; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }

    // the picked window stays in view
    function reveal(i) {
      const row = Math.floor(i / tv.cols);
      const top = row * (tv.cellH + tv.gridGap);
      if (top < contentY) contentY = top;
      else if (top + tv.cellH > contentY + height) contentY = top + tv.cellH - height;
    }
    Connections { target: tv; function onWinIndexChanged() { scroller.reveal(tv.winIndex); } }

    Grid {
      id: grid
      columns: tv.cols
      spacing: tv.gridGap

      Repeater {
        model: tv.wins

        Rectangle {
          id: card
          required property var modelData
          required property int index
          readonly property bool current: index === tv.winIndex
          readonly property bool down: Hypr.minimized(modelData)
          readonly property var size: modelData.lastIpcObject?.size ?? [16, 9]
          readonly property real areaW: tv.cellW - 2 * Theme.gapMedium
          readonly property real areaH: tv.cellH - tv.barH - Theme.gapMedium
          readonly property real fit: Math.min(areaW / Math.max(1, size[0]), areaH / Math.max(1, size[1]))

          // comes in after the previews, one after another; the picked one stands out a little
          readonly property real appear: Math.max(0, Math.min(1, tv.intro * 2 - 0.4 - index * 0.14))
          property real lift: current ? 1 : 0
          Behavior on lift { enabled: Motion.controls; NumberAnimation { duration: Motion.quick; easing.type: Motion.easing } }
          opacity: appear
          scale: (0.94 + 0.06 * appear) * (1 + 0.02 * lift)

          width: tv.cellW
          height: tv.cellH
          radius: Theme.radiusCard
          color: Theme.background1
          border.width: current ? Theme.ring : Theme.hairline
          border.color: current ? Theme.foreground0 : Theme.gray
          Behavior on border.color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

          // the title: its app's icon, its name, the cross
          IconImage {
            id: appIcon
            x: Theme.gapMedium
            y: (tv.barH - height) / 2
            implicitSize: 18
            source: Hypr.iconOf(card.modelData)
            visible: source != ""
            opacity: card.down ? 0.5 : 1
          }
          KitText {
            x: appIcon.visible ? Theme.gapMedium * 2 + 18 : Theme.gapMedium
            width: parent.width - x - 40
            height: tv.barH
            elide: Text.ElideRight
            text: card.modelData.title || Hypr.classOf(card.modelData)
            color: card.down ? Theme.muted : card.current ? Theme.foreground0 : Theme.muted
            font.pixelSize: Theme.fontSize - 1
          }
          KitText {
            id: cross
            anchors.right: parent.right
            anchors.rightMargin: Theme.gapMedium
            y: 0
            width: 28
            height: tv.barH
            horizontalAlignment: Text.AlignHCenter
            text: "×"
            font.pixelSize: Theme.fontSize + 6
            color: crossArea.containsMouse ? Theme.foreground0 : Theme.muted
            visible: hover.containsMouse || card.current

            MouseArea {
              id: crossArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: WindowsService.close(Hypr.addr(card.modelData))
            }
          }

          // the picture, in the window's own proportions
          Item {
            x: Theme.gapMedium
            y: tv.barH
            width: card.areaW
            height: card.areaH
            // A floating window's screencopy can include pixels outside the
            // compositor-reported client size (for example its decoration).
            // Keep those pixels inside the preview so they cannot look like a
            // second, overlapping window in the gaps between cards.
            clip: true

            ScreencopyView {
              id: shot
              anchors.centerIn: parent
              width: card.size[0] * card.fit
              height: card.size[1] * card.fit
              visible: !card.down
              // asked for a moment after the card appears, not in the same frame (a picture
              // requested at once, for a window just made, never comes); kept while the screen
              // fades out: the picture would give way to the icon
              property bool armed: false
              Timer { interval: 120; running: true; onTriggered: shot.armed = true }
              captureSource: armed && overview.visible && overview.previews && !card.down ? card.modelData.wayland : null
              live: false
              Connections { target: overview; function onSettled() { if (overview.previews && shot.armed && !card.down) shot.captureFrame(); } }
            }

            // minimized, or no picture to take: its app instead
            IconImage {
              anchors.centerIn: parent
              visible: overview.open && (card.down || !shot.hasContent) && source != ""
              implicitSize: 64
              opacity: 0.5
              source: Hypr.iconOf(card.modelData)
            }
          }

          MouseArea {
            id: hover
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: tv.winIndex = card.index
            onClicked: { tv.winIndex = card.index; tv.pick(); }
          }
        }
      }
    }
  }
}
