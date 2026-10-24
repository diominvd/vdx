import QtQuick
import qs.config
import qs.kit
import qs.modules.windows

// Windows: how windows behave (hypr/components/windowmode.lua). LAYOUT: the
// mode (tiling, floating, scrolling) and the options of the current one (the
// floating mode's switcher and taskbar too); LOOK: gaps, frames, shadows.
// Applied at once: Hyprland reloads.
KitColumn {
  id: root

  readonly property var ws: WindowsService
  readonly property var o: WindowsService.opts
  readonly property var mode: ws.current
  readonly property bool floating: ws.mode === "floating"

  // the window's fixed header shows these; the page under it scrolls
  readonly property string icon: "app-window"
  readonly property string title: "Windows"
  readonly property string subtitle: mode.label.toUpperCase()

  // groups for the Shell Manager's sidebar: a click scrolls to `y`
  readonly property var jumps: [
    { key: "layout", label: "Layout", y: layoutGroup.y },
    { key: "look",   label: "Look",   y: lookGroup.y }
  ]

  function pct(v) { return Math.round(v * 100) + "%"; }

  // ---- layout: the mode, then its own options ----
  KitLabel { id: layoutGroup; text: "LAYOUT" }

  KitRow {
    wide: true
    label: "Mode"
    hint: root.mode.about

    KitSegments {
      model: root.ws.choices
      current: root.ws.mode
      onPicked: value => root.ws.setMode(value)
    }
  }

  // 0.30–0.80 in steps of 0.05; setOption reloads Hyprland, so it runs on release
  KitSliderRow {
    id: master
    visible: root.ws.mode === "tiling"
    label: "Master size"
    snaps: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(i => i / 10)
    value: (root.o.mfact - 0.3) / 0.5
    text: root.pct(0.3 + (master.pressed ? master.dragValue : master.value) * 0.5)
    onReleased: value => root.ws.setOption("mfact", Math.round((0.3 + value * 0.5) * 20) / 20)
  }

  KitRow {
    wide: true
    visible: root.ws.mode === "tiling"
    label: "New window"
    hint: "Where it opens"

    KitSegments {
      model: [{ label: "Master", value: "master" }, { label: "Stack", value: "slave" }]
      current: root.o.newStatus
      onPicked: value => root.ws.setOption("newStatus", value)
    }
  }

  KitRow {
    wide: true
    visible: root.ws.mode === "scrolling"
    label: "New column width"
    hint: ""

    KitSegments {
      model: [{ label: "1/3", value: 0.333 }, { label: "1/2", value: 0.5 }, { label: "2/3", value: 0.667 }, { label: "Full", value: 1 }]
      current: root.o.columnWidth
      onPicked: value => root.ws.setOption("columnWidth", value)
    }
  }

  // floating only: the switcher and the taskbar
  KitRow {
    wide: true
    visible: root.floating
    label: "Arrange"
    hint: "On switching to floating"

    KitSegments {
      model: [{ label: "Cascade", value: "cascade" }, { label: "Grid", value: "grid" }, { label: "Centre", value: "center" }]
      current: root.o.arrange
      onPicked: value => root.ws.setOption("arrange", value)
    }
  }

  KitRow {
    visible: root.floating
    label: "Switcher"
    hint: "Super + Tab: this workspace's windows"

    KitSwitch {
      accessibleName: "Switcher"
      checked: root.o.switcher
      onToggled: root.o.switcher = !root.o.switcher
    }
  }

  KitRow {
    visible: root.floating
    label: "Taskbar"
    hint: "This workspace's windows, in a bar"

    KitSwitch {
      accessibleName: "Taskbar"
      checked: root.o.taskbar
      onToggled: root.o.taskbar = !root.o.taskbar
    }
  }

  KitRow {
    visible: root.floating && root.o.taskbar
    wide: true
    label: "Taskbar shape"
    hint: root.o.taskbarShape === "island" ? "A pill over the windows" : "A strip along the bottom"

    KitSegments {
      model: [{ label: "Strip", value: "strip" }, { label: "Island", value: "island" }]
      current: root.o.taskbarShape
      onPicked: value => root.o.taskbarShape = value
    }
  }

  KitRow {
    wide: true
    label: "Scroll with"
    hint: "The modes' wheel binds"

    KitSegments {
      model: [{ label: "Wheel", value: "wheel" }, { label: "Arrows", value: "arrows" }, { label: "Both", value: "both" }]
      current: root.o.scrollKeys
      onPicked: value => root.ws.setOption("scrollKeys", value)
    }
  }

  // ---- look ----
  KitLine {}

  KitLabel { id: lookGroup; text: "LOOK" }

  // inner 0–20 px in steps of 1, outer 0–40 px in steps of 2; released, as above
  KitSliderRow {
    id: innerGap
    label: "Inner gap"
    snaps: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20].map(i => i / 20)
    value: root.o.gapsIn / 20
    text: Math.round((innerGap.pressed ? innerGap.dragValue : innerGap.value) * 20) + " px"
    onReleased: value => root.ws.setOption("gapsIn", Math.round(value * 20))
  }

  KitSliderRow {
    id: outerGap
    label: "Outer gap"
    snaps: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20].map(i => i / 20)
    value: root.o.gapsOut / 40
    text: Math.round((outerGap.pressed ? outerGap.dragValue : outerGap.value) * 20) * 2 + " px"
    onReleased: value => root.ws.setOption("gapsOut", Math.round(value * 20) * 2)
  }

  // the windows' frame: none, the theme's colour, or the accent (its place "window")
  KitRow {
    id: frameRow
    readonly property string frame: !root.o.borders ? "off"
      : ShellSettings.accent && ShellSettings.accentWhere.window === true ? "accent" : "theme"
    wide: true
    label: "Frames"
    hint: frame === "off" ? "No frame round windows" : frame === "accent" ? "The focused one in the accent"
        : ShellSettings.accent ? "The focused one in the theme's colour" : "Accent can colour them"

    KitSegments {
      model: [{ label: "Off", value: "off" }, { label: "Theme", value: "theme" }]
        .concat(ShellSettings.accent ? [{ label: "Accent", value: "accent" }] : [])
      current: frameRow.frame
      onPicked: value => {
        if ((value === "off") === root.o.borders) root.ws.setOption("borders", value !== "off");
        if (value !== "off" && ShellSettings.accent)
          ShellSettings.set("accentWhere", Object.assign({}, ShellSettings.accentWhere, { window: value === "accent" }));
      }
    }
  }

  KitRow {
    label: "Shadows"
    hint: ""

    KitSwitch {
      accessibleName: "Shadows"
      checked: root.o.shadows
      onToggled: root.ws.setOption("shadows", !root.o.shadows)
    }
  }

  KitGrouper {}
}
