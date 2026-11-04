import QtQuick
import qs.bar
import qs.config
import qs.kit

// Notifications options in the Shell Manager, the most used first: how a new one
// arrives (NEW NOTIFICATIONS: how long a card stays; a live line instead of a card is
// the Messages activity of Live activities, linked here), the history popup (POPUP:
// the centre), the mark for the unseen (UNSEEN: on the bell, or the dot on the
// island's pill or the Folder while the bell is off the bar) and, last, the rules for
// an app's avatar colour (APP COLOURS).
KitColumn {
  spacing: Theme.sectionGap

  KitLabel { text: "NEW NOTIFICATIONS"; about: "How a new one reaches you" }

  // a card (and a toast) stays this long; a live line has its own time in Live activities.
  // Cards are what arrives in the strip, in card mode and with the live activities off
  KitOptionRow {
    needs: !Theme.island || ModuleSettings.get("notifications", "appear", "card") === "card" || !ShellSettings.liveEnabled
           ? "" : "Set by Live activities › Messages"
    module: "notifications"; key: "toastSeconds"; fallback: 5
    label: "Card stays for"; hint: "Stay: until closed; urgent ones always stay"
    model: [{ label: "3 s", value: 3 }, { label: "5 s", value: 5 }, { label: "10 s", value: 10 }, { label: "Stay", value: 0 }]
  }

  // a card, or (Island style) a line in the live slot: that choice is the Messages activity's
  // switch, kept in Live activities › Asks with its own options; a link here
  KitLinkRow {
    visible: Theme.island
    label: "Arrive as a live line"
    hint: "In Live activities › Asks"
    target: "live:notice"
  }

  KitLine {}

  KitLabel { text: "POPUP"; about: "The centre: the history you open from the bell" }

  KitOptionRow {
    module: "notifications"; key: "rows"; fallback: 6
    label: "Notifications shown"; hint: "Before the list scrolls"
    model: [{ label: "4", value: 4 }, { label: "6", value: 6 }, { label: "10", value: 10 }]
  }

  KitToggleRow { module: "notifications"; key: "closeOnClear"; fallback: false; label: "Close after Clear all"; hint: "Off: the centre stays open" }

  KitToggleRow { module: "notifications"; key: "removeOnClick"; fallback: false; label: "Remove on click"; hint: "A click takes it out of the centre" }

  KitLine {}

  KitLabel { text: "UNSEEN"; about: "The mark for what you have not looked at yet" }

  KitOptionRow {
    module: "notifications"; key: "badge"; fallback: "off"
    label: "Mark on the bell"; hint: "Off: the bell only lights"
    model: [{ label: "Off", value: "off" }, { label: "Dot", value: "dot" }, { label: "Count", value: "count" }]
  }

  KitRow {
    label: "Dot while tucked away"
    hint: "On the Folder or the pill, bell off the bar"

    KitSwitch {
      checked: ShellSettings.barFolderDot
      onToggled: ShellSettings.set("barFolderDot", !checked)
    }
  }

  KitColourRow {
    label: "Dot colour"
    hint: "Theme: the text colour"
    enabled: ShellSettings.barFolderDot; dimmed: !enabled
    names: Theme.colourSet
    picked: ShellSettings.barDotColor === "light" ? "theme" : ShellSettings.barDotColor
    colours: name => Theme.notifyDot(name)
    onChosen: value => ShellSettings.set("barDotColor", value)
  }

  KitLine {}

  NotificationsColours { width: parent.width }

  KitGrouper {}
}
