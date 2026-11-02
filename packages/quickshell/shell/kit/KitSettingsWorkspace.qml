import QtQuick
import QtQuick.Controls as Controls
import qs.config

// A full-width settings viewport. Section buttons live in the window header.
Item {
  id: root
  readonly property alias viewport: controls
  property bool showScrollBar: true
  property var sections: []
  property string current: ""
  property Component settings
  signal picked(string value)
  // a section comes in as a page does (ShellManager's pageIn): a fade
  QtObject { id: sectionIn; property real shown: 1 }
  NumberAnimation { id: sectionAnim; target: sectionIn; property: "shown"; from: 0; to: 1; duration: Motion.ms(240); easing.type: Motion.easing }
  onCurrentChanged: {
    controls.contentY = 0;
    if (Motion.tabs) sectionAnim.restart();
  }

  Flickable {
    id: controls
    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
    width: root.width + Theme.windowPadding
    contentHeight: settingsLoader.height
    bottomMargin: Theme.windowPadding
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight + bottomMargin > height + 1
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Controls.ScrollBar.vertical: KitScrollBar { visible: root.showScrollBar }
    Loader {
      id: settingsLoader
      width: root.width - Theme.gapMedium
      sourceComponent: root.settings
      opacity: sectionIn.shown
      height: item ? item.implicitHeight : 0
    }
  }
}
