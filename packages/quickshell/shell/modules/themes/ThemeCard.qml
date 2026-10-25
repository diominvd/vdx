import QtQuick
import qs.apps.shellmanager
import qs.config
import qs.kit

// One theme in the Themes cards: its background, its palette as dots, its
// name in its own text colour. Active: a check in the corner (a spinner while
// switching); picked (arrows, wheel): a bright frame.
Rectangle {
  id: root

  required property string theme
  required property var page                   // ThemesPopup: colorOf(), dots
  property bool picked: false

  readonly property bool active: theme === ThemeService.current
  readonly property bool busy: ThemeService.applying === theme

  signal clicked()

  radius: Theme.radiusCard
  color: page.colorOf(theme, "background0")
  border.width: area.activeFocus ? Theme.focusRingWidth : picked ? 2 : Theme.frameWidth
  border.color: area.activeFocus ? Theme.focusRing : picked ? Theme.foreground0 : area.containsMouse ? Theme.foreground2 : Theme.background2
  Behavior on border.color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }

  Column {
    anchors.centerIn: parent
    spacing: Theme.gapLoose

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 5

      Repeater {
        model: root.page.dots
        Rectangle {
          required property string modelData
          width: 10
          height: 10
          radius: Theme.pill(height)
          color: root.page.colorOf(root.theme, modelData)
        }
      }
    }

    KitText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.theme
      color: root.page.colorOf(root.theme, "foreground0")
      font.weight: root.picked ? Font.ExtraBold : Theme.fontWeight
      font.pixelSize: Theme.fontSize - 1
    }
  }

  Rectangle {
    anchors { top: parent.top; right: parent.right; margins: Theme.gapSmall }
    visible: root.active || root.busy
    width: 18
    height: 18
    radius: Theme.pill(height)
    color: Theme.foreground0

    KitIcon {
      anchors.centerIn: parent
      visible: !root.busy
      name: "check"
      size: 12
      tint: Theme.background0
    }
    KitSpinner {
      anchors.centerIn: parent
      visible: root.busy
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    activeFocusOnTab: root.picked
    Accessible.role: Accessible.Button
    Accessible.name: root.theme
    Accessible.description: root.active ? "Currently applied theme" : root.picked ? "Selected theme" : "Preview theme"
    cursorShape: Qt.PointingHandCursor
    onClicked: { forceActiveFocus(); root.clicked(); }
    Keys.onPressed: event => {
      if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
      if (!event.isAutoRepeat) root.clicked();
      event.accepted = true;
    }
  }
}
