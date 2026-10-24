import QtQuick
import qs.config
import qs.kit

// How a shell window opens, as a dialog over the Shell Manager (Shell apps ›
// an app › Window › Set up): the page dims, in the middle WindowOptions for
// the app. Done, Escape or a click on the dimmed page closes it; every choice
// is already applied.
Item {
  id: root

  property string appId: ""                 // shellapps.py id; "" closed
  readonly property var app: ShellAppsService.windows.find(a => a.id === appId) ?? null

  function close() { appId = ""; }

  visible: app !== null

  Rectangle {
    anchors.fill: parent
    color: Theme.scrim

    MouseArea { anchors.fill: parent; onClicked: root.close() }
  }

  // clicks on the dialog don't reach the dimmed page
  MouseArea { anchors.fill: dialog }

  KitFrame {
    id: dialog
    anchors.centerIn: parent
    width: Math.max(0, Math.min(parent.width - 48, 560))

    KitHeader {
      icon: "app-window"
      title: root.app?.title ?? ""
      subtitle: "WINDOW · APPLIED THE NEXT TIME IT OPENS"

      KitButton {
        text: "Done"
        onClicked: root.close()
      }
    }

    KitLine {}

    Loader {
      width: parent.width
      active: root.app !== null
      sourceComponent: WindowOptions { app: root.app; ipc: root.app.ipc; labelled: false }
    }
  }

  Shortcut {
    sequences: [StandardKey.Cancel]
    enabled: root.visible
    onActivated: root.close()
  }
}
