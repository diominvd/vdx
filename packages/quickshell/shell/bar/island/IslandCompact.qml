import QtQuick
import qs.bar
import qs.components
import qs.config
import qs.kit
import qs.modules.clock
import qs.modules.notifications

// The island at rest: the modules of LEFT, the clock, the modules of RIGHT
// (Shell Manager › Bar, island style) and a dot for unseen notifications.
// Each side takes the room its modules need — an empty one none — so the
// clock is centred only when both sides match.
Item {
  id: root

  property var modules: ({})                   // Bar's module id -> Component
  property string screen: ""
  signal settings(string id)                   // a module's right click: its options
  signal clockClicked()                        // the clock's click, when the hub opens on a click
  ClockTime { id: time }
  // the dot: unseen notices while the centre sits in the hub (Bar › Style › Notifications dot)
  readonly property bool unseen: NotificationsService.unseen > 0 && ShellSettings.barFolderDot && !BarLayout.bellOnPill(screen)
  readonly property bool clockOn: BarLayout.islandClock(screen)
  // the island follows the slot's own glide
  readonly property bool slotMoving: live.moving
  // nothing to show at rest: the island hides (Shell Manager › Bar › Clock)
  readonly property bool empty: !clockOn && !unseen && BarLayout.islandIn("start", screen).length === 0
                                && BarLayout.islandIn("end", screen).length === 0 && live.kind === ""
  // the pointer resting on the clock (not on a module) opens the hub
  readonly property bool clockHovered: clockHover.hovered
  implicitWidth: Math.max(110, line.implicitWidth + 2 * Theme.gapGroup)
  implicitHeight: Theme.islandHeight

  // a custom separator on the island's side: its line, no module behind it
  Component { id: separatorFace; Separator {} }

  // a side with nothing in it is zero wide: the Row skips it and its gap
  Row {
    id: line
    height: Theme.islandHeight
    anchors.centerIn: parent
    spacing: Theme.gapGroup

  Row {
    id: startModules
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.gapWide

    readonly property var ids: BarLayout.islandIn("start", root.screen)
    property bool modelReady: false
    property bool reordering: false
    onIdsChanged: {
      reordering = modelReady;
      BarLayout.syncFaceModel(leftModel, ids);
      if (modelReady) leftReorderDone.restart();
    }
    Component.onCompleted: { BarLayout.syncFaceModel(leftModel, ids); modelReady = true; }
    Timer { id: leftReorderDone; interval: Motion.normal; onTriggered: startModules.reordering = false }
    ListModel { id: leftModel }
    Repeater {
      model: leftModel
      Loader {
        id: leftFace
        // Animate a visual offset; the positioner always owns the final geometry.
        property real displayedX: x
        Behavior on displayedX { enabled: Motion.bar && startModules.reordering && leftFace.visible; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
        transform: Translate { x: leftFace.displayedX - leftFace.x }

        required property string moduleId
        readonly property string modelData: moduleId
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: BarLayout.isSeparator(modelData) ? separatorFace : (root.modules[modelData] ?? null)

        // a right click takes its options; without this it falls through to the island
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.RightButton
          enabled: !BarLayout.isSeparator(modelData)
          onClicked: if (ShellSettings.barRightSettings) root.settings(modelData)
        }
      }
    }
  }

  Item {
    anchors.verticalCenter: parent.verticalCenter
    visible: root.clockOn
    width: clock.implicitWidth
    height: Theme.islandHeight

    KitText {
      id: clock
      anchors.centerIn: parent
      text: Qt.formatDateTime(time.now, time.format)
      font.weight: Font.Bold
    }

    HoverHandler { id: clockHover }

    // the hub opens on a click here instead of a hover (Bar › Behaviour › Open the hub)
    MouseArea {
      anchors.fill: parent
      enabled: ShellSettings.clockOpens === "click"
      cursorShape: Qt.PointingHandCursor
      onClicked: root.clockClicked()
    }
  }

  IslandLive {
    id: live
    screen: root.screen
    anchors.verticalCenter: parent.verticalCenter
  }

  Row {
    id: endModules
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.gapWide

    readonly property var ids: BarLayout.islandIn("end", root.screen)
    property bool modelReady: false
    property bool reordering: false
    onIdsChanged: {
      reordering = modelReady;
      BarLayout.syncFaceModel(rightModel, ids);
      if (modelReady) rightReorderDone.restart();
    }
    Component.onCompleted: { BarLayout.syncFaceModel(rightModel, ids); modelReady = true; }
    Timer { id: rightReorderDone; interval: Motion.normal; onTriggered: endModules.reordering = false }
    ListModel { id: rightModel }
    Repeater {
      model: rightModel
      Loader {
        id: rightFace
        // Animate a visual offset; the positioner always owns the final geometry.
        property real displayedX: x
        Behavior on displayedX { enabled: Motion.bar && endModules.reordering && rightFace.visible; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
        transform: Translate { x: rightFace.displayedX - rightFace.x }

        required property string moduleId
        readonly property string modelData: moduleId
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: BarLayout.isSeparator(modelData) ? separatorFace : (root.modules[modelData] ?? null)

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.RightButton
          enabled: !BarLayout.isSeparator(modelData)
          onClicked: if (ShellSettings.barRightSettings) root.settings(modelData)
        }
      }
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.unseen
      width: 6
      height: 6
      radius: Theme.pill(height)
      color: Theme.notifyDot(ShellSettings.barDotColor)
    }
  }
  }

}
