import QtQuick
import qs.bar
import qs.config
import qs.kit

// Notifications options in the Shell Manager, by what they decide: how a new one
// arrives (NEW NOTIFICATIONS: a card or a live line, how long), its avatar's colour
// (APP COLOURS), the history popup (CENTRE), the mark for the unseen (UNSEEN: the dot
// on the island's pill or the Folder) and the Notifications bar module (BELL: its
// unseen mark).
KitColumn {
  spacing: Theme.sectionGap

  KitLabel { text: "NEW NOTIFICATIONS"; about: "How a new one reaches you: a card, or a line in the live slot" }

  KitOptionRow {
    needs: Theme.island ? "" : "A live line needs the Island style"
    needsAction: "Use Island"
    onNeedsActed: ShellSettings.set("barStyle", "island")
    module: "notifications"; key: "appear"; fallback: "card"
    label: "New ones arrive as"; hint: ShellSettings.liveEnabled ? "A card, or a line in the live slot" : "Live activities are off: cards only"
    model: [{ label: "Card", value: "card" }, { label: "Live activity", value: "live" }]
  }

  // a card (and a toast) stays this long; a live line has its own time in Bar › Live. Cards are what
  // arrives in the strip, in card mode and with the live activities off
  KitOptionRow {
    needs: !Theme.island || ModuleSettings.get("notifications", "appear", "card") === "card" || !ShellSettings.liveEnabled
           ? "" : "Cards only: a live line has its own time in Bar › Live"
    module: "notifications"; key: "toastSeconds"; fallback: 5
    label: "Card stays for"; hint: "Stay: until closed; urgent ones always stay"
    model: [{ label: "3 s", value: 3 }, { label: "5 s", value: 5 }, { label: "10 s", value: 10 }, { label: "Stay", value: 0 }]
  }

  KitLine {}

  NotificationsColours { width: parent.width }

  KitLine {}

  KitLabel { text: "CENTRE"; about: "The history you open from the bell" }

  KitOptionRow {
    module: "notifications"; key: "rows"; fallback: 6
    label: "Notifications shown"; hint: "Before the list scrolls"
    model: [{ label: "4", value: 4 }, { label: "6", value: 6 }, { label: "10", value: 10 }]
  }

  KitToggleRow { module: "notifications"; key: "closeOnClear"; fallback: false; label: "Close after Clear all"; hint: "Off: the centre stays open" }

  KitToggleRow { module: "notifications"; key: "removeOnClick"; fallback: false; label: "Remove on click"; hint: "A click takes it out of the centre" }

  KitLine {}

  KitLabel { text: "UNSEEN"; about: "The mark for what you have not looked at yet" }

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

  KitLabel { text: "BELL"; about: "The Notifications module on the bar" }

  KitOptionRow {
    module: "notifications"; key: "badge"; fallback: "off"
    label: "Unseen mark"; hint: "A mark on the bell; off: it only lights"
    model: [{ label: "Off", value: "off" }, { label: "Dot", value: "dot" }, { label: "Count", value: "count" }]
  }

  KitLine {}

  KitGrouper {}
}
