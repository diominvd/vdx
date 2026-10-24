import QtQuick
import Quickshell
import qs.config
import qs.kit
import qs.apps.shellmanager
import qs.modules.ai
import qs.modules.audio
import qs.modules.battery
import qs.modules.brightness
import qs.modules.capture
import qs.modules.chat
import qs.modules.cleaner
import qs.modules.backup
import qs.modules.clipboard
import qs.modules.clock
import qs.modules.display
import qs.modules.equalizer
import qs.modules.folder
import qs.modules.language
import qs.modules.mode
import qs.modules.mihomo
import qs.modules.music
import qs.modules.notifications
import qs.modules.packages
import qs.modules.sysmon
import qs.modules.taskmanager
import qs.modules.themes
import qs.modules.tray
import qs.modules.virustotal
import qs.modules.wallpapers
import qs.modules.bluetooth
import qs.modules.wifi
import qs.modules.windows
import qs.modules.workspaces

// Every bar module as a Component, made for one bar window (`bar`): each
// screen's bar makes its own set, its child bars use it too. A new module:
// its Component here and an entry in BarLayout.modules.
Item {
  id: root

  required property PanelWindow bar

  visible: false

  readonly property var map: ({
    workspaces: workspaces, music: music, equalizer: equalizer, themes: themes, mode: mode, tray: tray, wallpapers: wallpapers, clock: clock,
    brightness: brightness, audio: audio, wifi: wifi, bluetooth: bluetooth, mihomo: mihomo,
    battery: battery, language: language, ai: ai, notifications: notifications,
    shell: shell, capture: capture, clipboard: clipboard, sysmon: sysmon, taskmanager: taskmanager, cleaner: cleaner, backup: backup, virustotal: virustotal, packages: packages, display: display, windows: windows, chat: chat, folder: folder
  })

  Component { id: workspaces; Workspaces {} }
  Component { id: music; Music { bar: root.bar } }
  Component { id: clock; Clock {} }
  Component { id: equalizer; Equalizer { bar: root.bar } }
  Component { id: themes; Themes { bar: root.bar } }
  Component { id: wallpapers; Wallpapers { bar: root.bar } }
  Component { id: brightness; Brightness { bar: root.bar } }
  Component { id: audio; Audio { bar: root.bar } }
  Component { id: wifi; Wifi { bar: root.bar } }
  Component { id: bluetooth; Bluetooth { bar: root.bar } }
  Component { id: mihomo; Mihomo { bar: root.bar } }
  Component { id: battery; Battery { bar: root.bar } }
  Component { id: language; Language {} }
  Component { id: mode; Mode {} }
  Component { id: tray; Tray { bar: root.bar } }
  Component { id: ai; Ai { bar: root.bar } }
  Component { id: notifications; Notifications { bar: root.bar } }
  Component { id: capture; Capture { bar: root.bar } }
  Component { id: clipboard; ClipboardBar { bar: root.bar } }
  Component { id: sysmon; Sysmon { bar: root.bar } }
  Component { id: taskmanager; TaskManagerBar { bar: root.bar } }
  Component { id: cleaner; CleanerBar { bar: root.bar } }
  Component { id: backup; BackupBar { bar: root.bar } }
  Component { id: virustotal; VirusTotalBar { bar: root.bar } }
  Component { id: packages; PackagesBar { bar: root.bar } }
  Component { id: display; DisplayBar { bar: root.bar } }
  Component { id: windows; Windows { bar: root.bar } }
  Component { id: chat; Chat { bar: root.bar } }
  Component { id: folder; Folder { bar: root.bar; modules: root.map } }

  // The Shell Manager's button; a module of its own so it can move between zones.
  Component {
    id: shell

    KitBarItem {
      id: shellButton
      icon: "sliders"
      text: BarLayout.label("shell")
      activeFocusOnTab: true
      Accessible.role: Accessible.Button
      Accessible.name: BarLayout.label("shell")
      Accessible.description: "Toggle Shell Manager"

      Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        color: "transparent"
        border.width: shellButton.activeFocus ? 2 : 0
        border.color: Theme.foreground0
      }

      function toggleManager() { ShellSettings.managerOpen = !ShellSettings.managerOpen; }
      Keys.onPressed: event => {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space) return;
        if (!event.isAutoRepeat) toggleManager();
        event.accepted = true;
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { shellButton.forceActiveFocus(); shellButton.toggleManager(); }
      }
    }
  }
}
