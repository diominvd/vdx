import QtQuick
import qs.bar
import qs.config
import qs.kit
import qs.modules.mpd

// Sound: what the shell does with sound. For now the music that pauses while another app
// plays sound (it was Bar modules › Audio › AUTO-PAUSE, same keys); the volume itself
// is the Audio bar module's popup.
Column {
  id: root
  readonly property Item previewItem: null

  readonly property string icon: "volume"
  readonly property string title: "Sound"
  readonly property string description: "What the shell does with sound."
  readonly property var jumps: []

  readonly property var resetKeys: ["pauseMusic", "resumeMusic", "exclusiveSound"]
  readonly property bool changed: ShellSettings.changed(resetKeys)
  function reset() { ShellSettings.reset(resetKeys); }

  KitLabel { text: "MUSIC"; about: "Any player that reports playing over MPRIS counts: browsers, mpv, Spotify" }

  KitRow {
    visible: BarLayout.installed("files")
    label: "Music service"
    hint: "MPD and Yandex Music, off stops them"

    KitSwitch {
      checked: MpdService.service
      onToggled: MpdService.setOn(!checked)
    }
  }

  KitRow {
    label: "One source at a time"
    hint: "Starting one source pauses the rest"

    KitSwitch {
      checked: ShellSettings.exclusiveSound
      onToggled: ShellSettings.set("exclusiveSound", !checked)
    }
  }

  KitRow {
    label: "Pause on other sound"
    hint: "Pauses MPD while another app plays"

    KitSwitch {
      checked: ShellSettings.pauseMusic
      onToggled: ShellSettings.set("pauseMusic", !checked)
    }
  }

  KitRow {
    visible: ShellSettings.pauseMusic
    label: "Resume when it stops"
    hint: "Only music the shell paused"

    KitSwitch {
      checked: ShellSettings.resumeMusic
      onToggled: ShellSettings.set("resumeMusic", !checked)
    }
  }

  KitGrouper {}
}
