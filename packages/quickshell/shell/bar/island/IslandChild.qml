import QtQuick
import Quickshell
import qs.bar
import qs.components
import qs.config

// A child bar in the bar's row (Bar › Layout): its modules in a pill. In the
// island style it is a small island of its own: a module's popup opens inside
// it as in the island — the pill grows into the popup and folds back once it
// closes (BarPopup finds it through Bar.popupHost). Solid: a raised group in
// the strip, popups under their modules.
Rectangle {
  id: root

  required property var modelData             // its BarLayout.barsOn entry
  required property PanelWindow bar
  property real band: Theme.islandHeight

  // Bar.popupHost takes the nearest item that has it
  readonly property bool hostsPopups: Theme.island

  // ---- a module's popup ----
  readonly property var popup: host.popup // the BarPopup whose content is in here
  readonly property Item popupContent: host.content // its root item (a KitFrame)
  property bool popupShown: false

  function showPopup(p) {
    restoreTimer.stop();
    host.attach(p);
    popupShown = true;
    popupSlot.forceActiveFocus();
  }

  function hidePopup(p) {
    if (popup !== p) return;
    popupShown = false;
    restoreTimer.restart();
  }

  // the content goes home once the pill has folded
  function restore() { host.release(); }

  Timer {
    id: restoreTimer
    interval: Motion.slow + 60
    onTriggered: if (!root.popupShown) root.restore()
  }

  // ---- shape ----
  readonly property real pad: Theme.island ? Theme.gapGroup : Theme.gapLoose

  width: popupShown ? (popupContent?.fitWidth ? popupContent.implicitWidth : Math.max(Theme.modulePopupWidth, popupContent?.implicitWidth ?? 0)) : kids.width + 2 * pad
  height: popupShown ? (popupContent?.implicitHeight ?? band) : band
  radius: Theme.island ? Math.min(Theme.barRadiusFor(height), Theme.islandRadius) : Theme.radiusControl
  color: Theme.island ? Theme.background0 : Theme.background1
  border.width: Theme.island ? Theme.islandFrameWidth : 0
  border.color: Theme.background2
  clip: true

  Behavior on width { enabled: Motion.island && Theme.island; NumberAnimation { duration: Motion.slow; easing.type: Motion.morph } }
  Behavior on height { enabled: Motion.island && Theme.island; NumberAnimation { duration: Motion.slow; easing.type: Motion.morph } }
  Behavior on radius { enabled: Motion.island && Theme.island; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }

  // the modules: they stay (their popups live in them), faded while one is open
  Row {
    id: kids
    anchors.horizontalCenter: parent.horizontalCenter
    y: (root.band - height) / 2
    spacing: Theme.moduleSpacing
    visible: opacity > 0
    opacity: root.popupShown ? 0 : 1
    Behavior on opacity { enabled: Motion.island && Theme.island; NumberAnimation { duration: Motion.quick } }

    readonly property var ids: BarLayout.barModules(root.bar.modelData.name, root.modelData.id)
    property bool modelReady: false
    property bool reordering: false
    onIdsChanged: {
      reordering = modelReady;
      BarLayout.syncFaceModel(faceModel, ids);
      if (modelReady) kidsReorderDone.restart();
    }
    Component.onCompleted: { BarLayout.syncFaceModel(faceModel, ids); modelReady = true; }
    Timer { id: kidsReorderDone; interval: Motion.normal; onTriggered: kids.reordering = false }
    ListModel { id: faceModel }
    Repeater {
      model: faceModel

      Row {
        id: childFace
        // Animate a visual offset; the positioner always owns the final geometry.
        property real displayedX: x
        Behavior on displayedX { enabled: Motion.bar && kids.reordering && childFace.visible; NumberAnimation { duration: Motion.normal; easing.type: Motion.easing } }
        transform: Translate { x: childFace.displayedX - childFace.x }
        required property string moduleId
        readonly property string modelData: moduleId
        required property int index

        spacing: Theme.moduleSpacing

        Separator {
          anchors.verticalCenter: parent.verticalCenter
          visible: index > 0
          ruled: ShellSettings.barSeparators
        }

        Item {
          anchors.verticalCenter: parent.verticalCenter
          width: slot.width
          height: slot.height

          Loader {
            id: slot
            sourceComponent: root.bar.modules[modelData] ?? null
          }

          TapHandler {
            acceptedButtons: Qt.RightButton
            enabled: ShellSettings.barRightSettings
            onTapped: root.bar.openSettings(modelData)
          }
        }
      }
    }
  }

  // a module's popup content (showPopup); Escape closes it
  Item {
    id: popupSlot
    anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
    width: root.width
    height: root.popupContent?.implicitHeight ?? 0
    visible: opacity > 0
    opacity: root.popupShown ? 1 : 0
    Behavior on opacity { enabled: Motion.island; NumberAnimation { duration: Motion.normal } }
    Keys.onEscapePressed: if (root.popup) root.popup.visible = false

    PopupContentHost {
      id: host
      available: Theme.island
      width: parent.width
      height: parent.height
    }
  }
}
