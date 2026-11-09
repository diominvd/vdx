import QtQuick
import qs.config
import qs.modules.notifications
import qs.kit
import "../../kit/markup.js" as Markup

// A new notification: the app's initial in its own colour, app name with "now", summary and body.
// Click focuses its app's window, else opens the notifications popup; the cross dismisses. The island stacks
// one per row (Island › notice).
Item {
  id: root

  required property var n
  readonly property bool critical: n?.urgency === "critical"

  signal dismissed()

  Rectangle {
    id: badge
    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
    width: 40
    height: 40
    radius: Theme.radiusCard
    readonly property color tone: NotificationsService.toneOf(root.n)
    color: Theme.mix(Theme.background0, tone, 0.22)

    KitText {
      anchors.centerIn: parent
      text: (root.n?.app || "?").slice(0, 1).toUpperCase()
      color: badge.tone
      font.pixelSize: Theme.fontSize + 3
      font.weight: Font.Medium
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

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: { root.dismissed(); IslandService.activate(root.n); }
  }

  IslandButton {
    id: close
    anchors { right: parent.right; rightMargin: Theme.gapMedium; verticalCenter: parent.verticalCenter }
    icon: "x"
    iconSize: 14
    onClicked: root.dismissed()
  }
}
