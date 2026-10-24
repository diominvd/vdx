import QtQuick
import qs.config
import qs.kit
import "../../kit/markup.js" as Markup

// A new notification: app badge, app name with "now", summary and body.
// Click focuses its app's window, else opens the notifications popup; the cross dismisses. The island stacks
// one per row (Island › notice).
Item {
  id: root

  required property var n
  readonly property bool critical: n?.urgency === "critical"

  signal dismissed()

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusCard
    color: cardArea.pressed || cardArea.keyboardPressed ? Theme.background2 : cardArea.containsMouse ? Theme.background1 : Theme.clear
    Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
  }

  Rectangle {
    id: badge
    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
    width: 40
    height: 40
    radius: Theme.radiusCard
    color: root.critical ? Theme.red : Theme.background2

    KitIcon {
      anchors.centerIn: parent
      name: "bell"
      solid: true
      size: 20
      tint: root.critical ? Theme.background0 : Theme.foreground0
    }
  }

  Column {
    anchors { left: badge.right; leftMargin: Theme.gapWide; right: close.left; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
    spacing: 1

    Item {
      width: parent.width
      height: app.implicitHeight

      KitText {
        id: app
        anchors { left: parent.left; right: when.left; rightMargin: Theme.gapMedium }
        text: Markup.plain(root.n?.summary || root.n?.app || "")
        textFormat: Text.PlainText
        font.weight: Font.Bold
        elide: Text.ElideRight
      }
      KitText {
        id: when
        anchors.right: parent.right
        text: root.n?.app && root.n?.summary ? root.n.app.toLowerCase() + " · now" : "now"
        color: Theme.muted
        font.pixelSize: Theme.fontSize - 2
      }
    }

    KitText {
      width: parent.width
      visible: text !== ""
      text: Markup.plain(root.n?.body).replace(/\s+/g, " ")
      textFormat: Text.PlainText
      color: Theme.muted
      font.pixelSize: Theme.fontSize - 1
      elide: Text.ElideRight
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.radiusCard
    color: "transparent"
    border.width: cardArea.activeFocus ? 2 : 0
    border.color: Theme.foreground0
  }

  MouseArea {
    id: cardArea
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    activeFocusOnTab: true
    property bool keyboardPressed: false
    onActiveFocusChanged: if (!activeFocus) keyboardPressed = false
    Accessible.role: Accessible.Button
    Accessible.name: Markup.plain(root.n?.summary || root.n?.app || "Notification")
    Accessible.description: Markup.plain(root.n?.body || "Open the notification's app or notification center")
    onClicked: {
      forceActiveFocus()
      root.dismissed()
      IslandService.activate(root.n)
    }
    Keys.onPressed: event => {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        if (!event.isAutoRepeat) {
          keyboardPressed = true;
          root.dismissed();
          IslandService.activate(root.n);
        }
        event.accepted = true;
      }
    }
    Keys.onReleased: event => {
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
        keyboardPressed = false;
        event.accepted = true;
      }
    }
  }

  IslandButton {
    id: close
    anchors { right: parent.right; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
    icon: "x"
    iconSize: 14
    onClicked: root.dismissed()
  }
}
