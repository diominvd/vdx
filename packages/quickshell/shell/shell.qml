import QtQuick
import Quickshell
import Quickshell.Io
import qs.apps.auth
import qs.apps.backup
import qs.apps.capture
import qs.apps.clipboard
import qs.apps.display
import qs.apps.files
import qs.apps.cleaner
import qs.apps.packages
import qs.apps.virustotal
import qs.apps.music
import qs.apps.keybinds
import qs.apps.taskbar
import qs.apps.launcher
import qs.apps.lock
import qs.apps.overview
import qs.apps.shellmanager
import qs.apps.themepicker
import qs.apps.switcher
import qs.apps.taskmanager
import qs.bar
import qs.bar.island
import qs.components
import qs.config
import qs.modules.audio
import qs.apps.companion

// Entry point: a bar on every screen that has one on (BarLayout), recoloured when the dotfiles theme changes.
Scope {
  Variants {
    model: ShellSettings.loaded ? Quickshell.screens.filter(s => BarLayout.barOn(s.name)) : []

    Bar {}
  }

  ShellManagerWindow {}
  TaskManagerWindow {}
  CleanerWindow {}
  VirusTotalWindow {}
  PackagesWindow {}
  ClipboardWindow {}
  FilesWindow {}
  FilePickerWindow {}
  BackupWindow {}
  CaptureWindow {}
  MusicWindow {}
  Keybinds {}
  Taskbar {}
  Launcher {}
  Lock {}
  Overview {}
  WallpaperPreview {}
  LooksIpc {}
  // Kimmy, the pet ball: one window, on the monitor you work on (Shell Manager › Kimmy)
  CompanionHost {}
  // Alt+Tab: the floating mode's window switcher (Switcher.step)
  Switcher {}

  // the polkit agent: password requests slide down from under the bar
  AuthPrompt {}

  Wallpaper {}

  // the theme switch's curtain, on every screen (ThemeService.covering)
  Variants {
    model: Quickshell.screens

    ThemeCurtain {}
  }

  // Modules › Audio: the music pauses while another app plays sound
  AudioPause {}

  PopupCatcher {}

  // mako's island mode follows Bar › Style, Hyprland's and mako's corners
  // Appearance › Corners, from the start
  Component.onCompleted: {
    IslandService.makoMode();
    CornersService.apply();
    AccentService.apply();
  }

  // the very first start: where the options and the keys are
  Connections {
    target: ShellSettings
    function onFirstRunChanged() {
      if (ShellSettings.firstRun)
        Quickshell.execDetached(["notify-send", "-a", "Shell", "Welcome",
          "Super + S  Shell Manager\nSuper + B  every keybind\nAlt + Space  launcher"]);
    }
  }

  // Super+Shift+S: screenshot or recording of a region, window or screen
  CaptureOverlay {}

  CaptureRecording {}

  CaptureCountdown {}

  CaptureSave {}

  // `install.py theme set` (here or from a terminal) writes .theme; reread the
  // theme colours and the shell recolours live — Colors.qml only seeds the start.
  FileView {
    path: ThemeService.dotfiles + "/.theme"
    watchChanges: true
    printErrors: false
    onFileChanged: refreshTimer.restart()
  }

  Timer {
    id: refreshTimer
    interval: 400   // longer than install.py's relink (~220 ms)
    onTriggered: ThemeService.refresh()
  }
}