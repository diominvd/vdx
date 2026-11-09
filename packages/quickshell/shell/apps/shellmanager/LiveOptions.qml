import QtQuick
import qs.config
import qs.kit

// The options of one live activity, shown under its row in Bar › Live when the row is
// unfolded (a KitFoldRow in BarLiveSection). Each kind has the few that concern only it; the rules for all
// of them (flash length, the wheel) stay in BEHAVIOUR.
Column {
  id: root

  property string kind: ""
  property int inset: 0                       // the options start this far in; the hairlines run the full width
  property bool shown: false                  // the row is unfolded: the options are built on the first time

  property bool built: false
  onShownChanged: if (shown) built = true

  // what a kind has to set: the rows below read this to know whether to offer the opening
  readonly property bool any: kind === "notice" || kind === "battery" || kind === "vpn" || kind === "music" || kind === "media" || kind === "radio" || kind === "focus" || kind === "recording"

  width: parent ? parent.width : 0
  height: opts.item ? opts.item.implicitHeight : 0

  // built only once the row unfolds: every row of the list carries these, and most are never opened
  Loader { id: opts; width: parent.width; active: root.built; sourceComponent: rows }

  Component {
    id: rows
    // a plain Item: the Loader sizes its item to its own width, which would undo the Column's inset
    Item {
      width: root.width
      implicitHeight: col.implicitHeight
      height: implicitHeight

    Column {
      id: col
      x: root.inset
      width: parent.width - root.inset - Theme.gapLoose
      spacing: Theme.settingsRowInset          // the box's own row rhythm: a gap each side of a hairline

    KitRow {
      visible: root.kind === "notice"
      label: "Stays for"
      hint: "How long it holds the slot"
      wide: true
      KitSegments {
        model: [{label: "5 s", value: 5000}, {label: "10 s", value: 10000}, {label: "Until read", value: 0}]
        current: ShellSettings.liveNoticeMs
        onPicked: value => ShellSettings.setLook("liveNoticeMs", value, "island")
      }
    }

    Rectangle { visible: root.kind === "notice"; x: -root.inset; width: root.width; height: Theme.dividerThickness; color: Theme.dividerColor }

    KitRow {
      visible: root.kind === "notice"
      label: "Marked by"
      hint: "App icon, first letter, or a coloured dot"
      wide: true
      KitSegments {
        model: [{label: "Icon", value: "avatar"}, {label: "Initial", value: "initial"}, {label: "Dot", value: "dot"}]
        current: ShellSettings.liveNoticeMark
        onPicked: value => ShellSettings.setLook("liveNoticeMark", value, "island")
      }
    }

    KitRow {
      visible: root.kind === "battery"
      label: "Shows below"
      hint: "The charge that takes the pill"
      wide: true
      KitSegments {
        model: [{label: "10%", value: 10}, {label: "15%", value: 15}, {label: "20%", value: 20}, {label: "30%", value: 30}]
        current: ShellSettings.liveBatteryBelow
        onPicked: value => ShellSettings.setLook("liveBatteryBelow", value, "island")
      }
    }

    // a hairline parts the options when a kind has several
    Rectangle { visible: root.kind === "battery"; x: -root.inset; width: root.width; height: Theme.dividerThickness; color: Theme.dividerColor }

    KitRow {
      visible: root.kind === "battery"
      label: "Stays for"
      hint: "Until it charges or plugs in"
      wide: true
      KitSegments {
        model: [{label: "5 s", value: "5s"}, {label: "Until fixed", value: "fixed"}]
        current: ShellSettings.liveBatteryStay
        onPicked: value => ShellSettings.setLook("liveBatteryStay", value, "island")
      }
    }

    KitRow {
      visible: root.kind === "music"
      label: "Always show"
      hint: "Stays in the slot with no player running"
      KitSwitch { checked: ShellSettings.liveMusicAlways; onToggled: ShellSettings.setLook("liveMusicAlways", !checked, "island") }
    }

    Rectangle { visible: root.kind === "music"; x: -root.inset; width: root.width; height: Theme.dividerThickness; color: Theme.dividerColor }

    KitRow {
      visible: root.kind === "music"
      label: "Show on pause"
      hint: "The track stays in the slot while paused"
      KitSwitch { checked: ShellSettings.liveMusicPaused; onToggled: ShellSettings.setLook("liveMusicPaused", !checked, "island") }
    }

    Rectangle { visible: root.kind === "music"; x: -root.inset; width: root.width; height: Theme.dividerThickness; color: Theme.dividerColor }

    KitRow {
      visible: root.kind === "music"
      label: "Show album cover"
      hint: "The cover in the live activity"
      KitSwitch { checked: ShellSettings.liveMusicCover; onToggled: ShellSettings.setLook("liveMusicCover", !checked, "island") }
    }

    KitRow {
      visible: root.kind === "media"
      label: "Show on pause"
      hint: "The app's track stays while paused"
      KitSwitch { checked: ShellSettings.liveMediaPaused; onToggled: ShellSettings.setLook("liveMediaPaused", !checked, "island") }
    }

    Rectangle { visible: root.kind === "media"; x: -root.inset; width: root.width; height: Theme.dividerThickness; color: Theme.dividerColor }

    KitRow {
      visible: root.kind === "media"
      label: "Show cover"
      hint: "The app's artwork in the live activity"
      KitSwitch { checked: ShellSettings.liveMediaCover; onToggled: ShellSettings.setLook("liveMediaCover", !checked, "island") }
    }

    KitRow {
      visible: root.kind === "vpn"
      label: "Show server name"
      hint: "The server's name in the live activity"
      KitSwitch { checked: ShellSettings.liveVpnServer; onToggled: ShellSettings.setLook("liveVpnServer", !checked, "island") }
    }

    Rectangle { visible: root.kind === "vpn"; x: -root.inset; width: root.width; height: Theme.dividerThickness; color: Theme.dividerColor }

    KitRow {
      visible: root.kind === "vpn"
      label: "Show ping"
      hint: "The delay to the server, in ms"
      KitSwitch { checked: ShellSettings.liveVpnPing; onToggled: ShellSettings.setLook("liveVpnPing", !checked, "island") }
    }

    Rectangle { visible: root.kind === "music" || root.kind === "media"; x: -root.inset; width: root.width; height: Theme.dividerThickness; color: Theme.dividerColor }

    KitRow {
      visible: root.kind === "music" || root.kind === "media"
      label: "Show title"
      hint: "The track's name"
      KitSwitch { checked: ShellSettings.liveTrackTitle; onToggled: ShellSettings.setLook("liveTrackTitle", !checked, "island") }
    }

    Rectangle { visible: root.kind === "music" || root.kind === "media"; x: -root.inset; width: root.width; height: Theme.dividerThickness; color: Theme.dividerColor }

    KitRow {
      visible: root.kind === "music" || root.kind === "media"
      label: "Show artist"
      hint: "Who plays it"
      KitSwitch { checked: ShellSettings.liveTrackArtist; onToggled: ShellSettings.setLook("liveTrackArtist", !checked, "island") }
    }

    Rectangle { visible: root.kind === "music" || root.kind === "media"; x: -root.inset; width: root.width; height: Theme.dividerThickness; color: Theme.dividerColor }

    KitRow {
      visible: root.kind === "music" || root.kind === "media"
      label: "Show duration"
      hint: "The track's length"
      KitSwitch { checked: ShellSettings.liveTrackDuration; onToggled: ShellSettings.setLook("liveTrackDuration", !checked, "island") }
    }

    KitRow {
      visible: root.kind === "recording"
      label: "Control buttons"
      hint: "Pause and stop on the activity"
      KitSwitch { checked: ShellSettings.liveRecordingButtons; onToggled: ShellSettings.setLook("liveRecordingButtons", !checked, "island") }
    }

    KitRow {
      visible: root.kind === "focus"
      label: "Turn off on click"
      hint: "A click on the activity ends Focus"
      KitSwitch { checked: ShellSettings.liveFocusClick; onToggled: ShellSettings.setLook("liveFocusClick", !checked, "island") }
    }

    KitRow {
      visible: root.kind === "radio"
      label: "Show on pause"
      hint: "Stays in the slot while paused"
      KitSwitch { checked: ShellSettings.liveRadioPaused; onToggled: ShellSettings.setLook("liveRadioPaused", !checked, "island") }
    }

    Rectangle { visible: root.kind === "radio"; x: -root.inset; width: root.width; height: Theme.dividerThickness; color: Theme.dividerColor }

    KitRow {
      visible: root.kind === "radio"
      label: "Always show"
      hint: "Stays in the slot, click opens it"
      KitSwitch { checked: ShellSettings.liveRadioAlways; onToggled: ShellSettings.setLook("liveRadioAlways", !checked, "island") }
    }

    }
    }
  }
}
