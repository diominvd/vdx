import QtQuick
import qs.bar
import qs.config
import qs.kit

// Audio options in the Shell Manager: the bar's volume, then the music that
// AudioPause.qml pauses while another app plays sound (the shell's own
// options, kept in ShellSettings).
KitColumn {
  spacing: Theme.gapGroup

  KitLabel { text: "BAR" }
  BarTextRow { module: "audio" }

  KitToggleRow { visible: ModuleSettings.get("audio", "text", "content") === "content"; module: "audio"; key: "percent"; label: "Show volume"; hint: "Off: icon only" }

  KitLine {}

  KitLabel { text: "AUTO-PAUSE" }

  KitText {
    width: parent.width
    wrapMode: Text.WordWrap
    color: Theme.muted
    font.pixelSize: Theme.fontSize - 2
    text: "Any player that reports playing over MPRIS: browsers, mpv, Spotify."
  }

  KitRow {
    label: "Pause on other sound"
    hint: "Pauses MPD while a player plays"

    KitSwitch {
      accessibleName: "Pause on other sound"
      checked: ShellSettings.pauseMusic
      onToggled: ShellSettings.set("pauseMusic", !checked)
    }
  }

  KitRow {
    visible: ShellSettings.pauseMusic
    label: "Resume when it stops"
    hint: "Only music the shell paused"

    KitSwitch {
      accessibleName: "Resume when it stops"
      checked: ShellSettings.resumeMusic
      onToggled: ShellSettings.set("resumeMusic", !checked)
    }
  }

  KitGrouper {}
}
