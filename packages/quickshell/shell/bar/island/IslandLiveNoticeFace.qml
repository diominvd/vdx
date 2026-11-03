import QtQuick
import Quickshell.Widgets
import qs.components
import qs.config
import qs.kit

Row {
  id: face

  property string kind: ""
  property int coverSize: 18
  property int badgeRadius: 4
  spacing: Theme.gapMedium
  visible: kind !== ""

  // a notification, as a line: the app's initial, "app: summary"
  Rectangle {
    visible: face.kind === "notice" && ShellSettings.liveNoticeMark === "dot"
    anchors.verticalCenter: parent.verticalCenter
    width: 8; height: 8; radius: Theme.pill(height)
    color: IslandService.noticeItem?.urgency === "critical" ? Theme.red : Theme.appColour(IslandService.noticeItem?.app)
  }
  Rectangle {
    visible: face.kind === "notice" && ShellSettings.liveNoticeMark === "avatar"
    anchors.verticalCenter: parent.verticalCenter
    width: face.coverSize
    height: face.coverSize
    radius: face.badgeRadius
    readonly property string liveEnd: "badge"      // IslandLiveFace.padFor
    readonly property color tone: IslandService.noticeItem?.urgency === "critical" ? Theme.red : Theme.appColour(IslandService.noticeItem?.app)
    color: Theme.mix(Theme.background0, tone, 0.22)
    readonly property string appIcon: Hypr.iconOfApp(IslandService.noticeItem?.desktop, IslandService.noticeItem?.app)
    // the app's own icon; an app with none gets its initial
    IconImage {
      anchors.centerIn: parent
      implicitSize: parent.width - 4
      source: parent.appIcon
      visible: parent.appIcon !== ""
    }
    KitText { anchors.centerIn: parent; visible: parent.appIcon === ""; text: (IslandService.noticeItem?.app ?? "").slice(0, 1).toUpperCase(); color: parent.tone; font.pixelSize: Theme.fontSize - 2; font.weight: Font.Medium }
  }
  KitText {
    visible: face.kind === "notice"
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(implicitWidth, 300)
    elide: Text.ElideRight
    textFormat: Text.PlainText
    text: {
      const n = IslandService.noticeItem;
      if (!n) return "";
      const head = n.summary !== "" ? n.summary : n.app;
      const message = n.body !== "" ? head + ": " + n.body : head;
      return (n.repeats > 1 ? "(" + n.repeats + ") " : "") + message;
    }
    color: IslandService.noticeItem?.urgency === "critical" ? Theme.red : Theme.foreground1
  }
}
