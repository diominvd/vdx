import QtQuick
import qs.config
import qs.kit
import qs.modules.focus
import "../../kit/markup.js" as Markup

// Notification history, newest first, in day groups under filter tabs (all, unread,
// urgent); the header switch is Focus mode (off = on). A card: the app's avatar in its colour rule, summary, app and time, the
// body in an inset block; unread ones carry a red dot, critical summaries are red,
// a hover brings up a cross that dismisses the one. Footer: mark all as read, clear.
KitFrame {
  id: root

  readonly property var items: NotificationsService.items
  // a notification that comes in while it is open eases in
  property KitSeen seen: KitSeen {}
  property string tab: "all"
  readonly property int fresh: items.filter(n => NotificationsService.isFresh(n)).length
  readonly property int urgent: items.filter(n => n.urgency === "critical").length
  readonly property var shown: items.filter(n => tab === "new" ? NotificationsService.isFresh(n)
                                                : tab === "urgent" ? n.urgency === "critical" : true)
  // day groups of the shown rows: [{label, items}]
  readonly property var groups: {
    const out = [];
    const today = new Date().toDateString();
    const yesterday = new Date(Date.now() - 86400000).toDateString();
    for (const n of shown) {
      const day = new Date(n.time).toDateString();
      const label = day === today ? "TODAY" : day === yesterday ? "YESTERDAY" : "EARLIER";
      let g = out[out.length - 1];
      if (!g || g.label !== label) {
        g = { label: label, items: [] };
        out.push(g);
      }
      g.items.push(n);
    }
    return out;
  }

  signal closeRequested()

  function when(time) {
    const d = new Date(time);
    const today = d.toDateString() === new Date().toDateString();
    return Qt.formatDateTime(d, today ? "HH:mm" : "dd.MM HH:mm");
  }

  // ---- header ----
  KitHeader {
    icon: "bell"
    iconColor: root.items.length > 0 ? Theme.foreground0 : Theme.muted
    title: "Notifications"
    subtitle: root.items.length === 0 ? "ALL CAUGHT UP" : root.items.length + " IN HISTORY"

    KitBadge {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.fresh > 0
      text: root.fresh + " NEW"
      tint: Theme.red
    }

    // on: toasts come; off: Focus (do not disturb) is on
    KitSwitch {
      anchors.verticalCenter: parent.verticalCenter
      checked: !FocusService.on
      accessibleName: "Notifications"
      onToggled: FocusService.toggle()
    }
  }

  KitLine {}

  KitSegments {
    width: parent.width
    model: [
      { label: "All " + root.items.length, value: "all" },
      { label: "Unread " + root.fresh, value: "new" },
      { label: "Urgent " + root.urgent, value: "urgent" }
    ]
    current: root.tab
    onPicked: value => root.tab = value
  }

  KitText {
    visible: root.shown.length === 0
    text: root.tab === "new" ? "Nothing unread." : root.tab === "urgent" ? "Nothing urgent." : "Nothing here yet."
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 1
  }

  // the list; its lower edge fades into the surface while more lies below. Material: its
  // cards stand on the surface (no section round them), tonal and rounder
  Item {
    readonly property bool kitUnboxed: true
    width: parent.width
    visible: root.shown.length > 0
    height: Math.min(list.contentHeight, ModuleSettings.get("notifications", "rows", 6) * 82)

  Flickable {
    id: list
    anchors.fill: parent
    contentHeight: rows.implicitHeight
    interactive: contentHeight > height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: rows
      width: parent.width
      spacing: Theme.gapWide

      Repeater {
        model: root.groups

        Column {
          id: group

          required property var modelData

          width: rows.width
          spacing: Theme.gapMedium

          Row {
            spacing: Theme.gapMedium

            KitText {
              anchors.verticalCenter: parent.verticalCenter
              text: group.modelData.label
              color: Theme.muted
              font.pixelSize: Theme.fontSize - 2
              font.letterSpacing: 1
            }

            KitText {
              anchors.verticalCenter: parent.verticalCenter
              text: group.modelData.items.length
              color: Theme.muted
              font.pixelSize: Theme.fontSize - 2
            }
          }

          Repeater {
            model: group.modelData.items

            // a card: the app's avatar in its colour rule (Notifications › App colours), a click
            // brings up the app's window, a hover lights it up and shows the cross
            Item {
              id: item

              required property var modelData

              readonly property bool fresh: NotificationsService.isFresh(modelData)
              readonly property bool critical: modelData.urgency === "critical"
              readonly property color tone: critical ? Theme.red : Theme.appColour(modelData.app)
              readonly property bool hasBody: modelData.body !== ""

              KitAppear { target: item; seen: root.seen; key: item.modelData.key }

              HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
              // the centre closes; Notifications › Remove on click takes it out of the centre too
              TapHandler {
                onTapped: {
                  NotificationsService.focusApp(item.modelData);
                  const key = item.modelData.key;
                  root.closeRequested();
                  // last: removing the row ends this handler's context
                  if (ModuleSettings.get("notifications", "removeOnClick", false)) NotificationsService.remove(key);
                }
              }

              width: group.width
              height: content.implicitHeight + 2 * Theme.gapLoose

              Rectangle {
                anchors.fill: parent
                radius: Theme.material ? Theme.radiusSection : Theme.radiusCard
                color: Theme.material ? (hover.hovered ? Theme.surfaceHigh : Theme.sectionFill)
                     : hover.hovered ? Theme.controlHover : Theme.controlFill
                border.width: Theme.frameWidth
                border.color: hover.hovered ? Theme.controlLineHover : Theme.controlLineRest
                Behavior on border.color { enabled: Motion.controls; ColorAnimation { duration: Motion.normal; easing.type: Motion.easing } }
                Behavior on color { enabled: Motion.controls; ColorAnimation { duration: Motion.quick } }
              }

              Rectangle {
                id: badge
                anchors { left: parent.left; leftMargin: Theme.gapLoose; top: parent.top; topMargin: Theme.gapLoose }
                width: 36
                height: 36
                radius: Theme.pill(height)
                color: Theme.mix(Theme.background0, item.tone, 0.18)
                border.width: Theme.hairline
                border.color: Theme.mix(Theme.background0, item.tone, 0.45)

                KitText {
                  anchors.centerIn: parent
                  text: (item.modelData.app || "?").slice(0, 1).toUpperCase()
                  color: item.tone
                  font.pixelSize: Theme.fontSize + 2
                  font.weight: Font.Medium
                }
              }

              // the unread dot, and in its place the cross while the pointer is on the card
              Item {
                id: aside
                anchors { right: parent.right; rightMargin: Theme.gapLoose; top: parent.top; topMargin: Theme.gapLoose }
                width: 20
                height: 20

                Rectangle {
                  anchors.centerIn: parent
                  visible: item.fresh && !hover.hovered
                  width: 6
                  height: 6
                  radius: Theme.pill(height)
                  color: Theme.red
                }

                KitIcon {
                  anchors.centerIn: parent
                  name: "x"
                  size: Theme.fontSize
                  tint: cross.containsMouse ? Theme.foreground0 : Theme.muted
                  opacity: hover.hovered ? 1 : 0
                  Behavior on opacity { enabled: Motion.controls; NumberAnimation { duration: Motion.quick } }
                }

                MouseArea {
                  id: cross
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: NotificationsService.remove(item.modelData.key)
                }
              }

              Column {
                id: content
                anchors {
                  left: badge.right; leftMargin: Theme.gapWide
                  right: aside.left; rightMargin: Theme.gapMedium
                  top: parent.top; topMargin: Theme.gapLoose
                }
                spacing: Theme.gapHair

                KitText {
                  width: parent.width
                  text: Markup.plain(item.modelData.summary)
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  color: item.critical ? Theme.red : Theme.foreground0
                  font.weight: Font.Bold
                }

                KitText {
                  width: parent.width
                  text: (item.modelData.app || "—") + " · " + root.when(item.modelData.time)
                  textFormat: Text.PlainText
                  elide: Text.ElideRight
                  color: Theme.muted
                  font.pixelSize: Theme.fontSize - 2
                }

                // the body in an inset block, as a message in a thread
                Rectangle {
                  visible: item.hasBody
                  width: parent.width
                  implicitHeight: bodyText.implicitHeight + 2 * Theme.gapMedium
                  height: implicitHeight
                  radius: Theme.radiusControl
                  color: Theme.fillOn(true)

                  KitText {
                    id: bodyText
                    x: Theme.gapMedium
                    y: Theme.gapMedium
                    width: parent.width - 2 * Theme.gapMedium
                    text: Markup.plain(item.modelData.body)
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    color: Theme.foreground2
                    font.pixelSize: Theme.fontSize - 1
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  Rectangle {
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    height: 40
    visible: !list.atYEnd
    gradient: Gradient {
      GradientStop { position: 0; color: Theme.clear }
      GradientStop { position: 1; color: Theme.background0 }
    }
  }
  }

  KitLine {}

  // ---- footer ----
  Item {
    width: parent.width
    height: Theme.controlHeight

    KitButton {
      anchors.left: parent.left
      icon: "check"
      text: "Mark all as read"
      disabled: root.fresh === 0
      onClicked: NotificationsService.markRead()
    }

    KitButton {
      anchors.right: parent.right
      icon: "trash"
      text: "Clear all"
      disabled: root.items.length === 0
      onClicked: {
        NotificationsService.clear();
        if (ModuleSettings.get("notifications", "closeOnClear", false)) root.closeRequested();
      }
    }
  }
}
