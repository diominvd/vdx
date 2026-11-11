import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import qs.bar
import qs.config
import qs.kit

// Shell Manager: settings laid out like a system settings window — navigation
// on the left, the chosen page on the right under its fixed header, scrolling
// on its own. Navigation can show one section beside an icon rail or every
// page in a single grouped list. A page shared with others (`pageTab`) appears once:
//   APPEARANCE — Interface, Themes, Colours, Fonts, Icons, Cursor, Motion
//   DESKTOP    — Wallpaper, Windows
//   BAR        — Bar, Bar look, Bar monitors, Bar modules, Hub, Live activities
//   SESSION    — Notifications, Lock screen, Profile
//   CONNECTIVITY — Network, Bluetooth, VPN
//   DEVICES  — Sound, Displays, Power
//   SYSTEM   — Apps (each app's options and window), Updates, System
//   SHELL    — Settings, About
// A page may offer `changed` + `reset()`: Reset (two steps) in the header.
Rectangle {
  id: root

  property string tab: "appearance"
  property var navHistory: []
  property bool restoringNavigation: false

  Component.onCompleted: {
    SettingsIndex.load();
    // the pickers' data (two quick scripts) is read before a page asks for it
    Qt.callLater(() => { FontService.refresh(); CursorService.refresh(); });
    if (ShellSettings.managerOpen && ShellSettings.managerStart === "last")
      tab = resolve(ShellSettings.managerTab).tab;
  }

  // opening: the main page, or the page it was left on (Shell apps › Shell Manager).
  // A page named by `shell open <page>` is set after this, so it wins.
  Connections {
    target: ShellSettings
    function onManagerOpenChanged() {
      if (ShellSettings.managerOpen) {
        root.navHistory = [];
        root.tab = ShellSettings.managerStart === "last" ? root.resolve(ShellSettings.managerTab).tab : "appearance";
      }
    }
  }

  // `caption` names a page group; the rail opens that group's pages
  // `island`: only while the island is the bar style
// `page` + `pageTab`: a section that is one tab of another page (Bar look is the Bar page's Look tab):
// the page opens on that tab, its tab strip stays hidden, `label` and `description` head it
  readonly property var allSections: [
    { value: "appearance", label: "Interface",  icon: "sliders",    caption: "APPEARANCE",
      page: "appearance", pageTab: "interface", description: "Style, fields and corners." },
    { value: "themes",     label: "Themes",     icon: "brush" },
    { value: "colours",    label: "Colours",    icon: "paint-bucket",
      page: "appearance", pageTab: "accent", description: "The accent colour and where it shows." },
    { value: "fonts",      label: "Fonts",      icon: "text" },
    { value: "icons",      label: "Icons",      icon: "icons" },
    { value: "cursor",     label: "Cursor",     icon: "cursor" },
    { value: "animations", label: "Motion",     icon: "curve" },
    { value: "wallpaper",  label: "Wallpaper",  icon: "image",      caption: "DESKTOP" },
    { value: "windows",    label: "Windows",    icon: "tiling" },
    { value: "bar",        label: "Bar",        icon: "columns",     caption: "BAR",
      page: "bar", pageTab: "layout", description: "Where each module sits on the bar." },
    { value: "barlook",    label: "Bar look",   icon: "layout",
      page: "bar", pageTab: "appearance", description: "The bar's style, size and spacing." },
    { value: "barmonitor", label: "Bar monitors", icon: "laptop",
      page: "bar", pageTab: "monitor", description: "Which monitors have a bar, and which one is the main." },
    { value: "modules",    label: "Bar modules", icon: "assembly" },
    { value: "hub",        label: "Hub",        icon: "home",    island: true },
    { value: "live",       label: "Live activities", icon: "activity", island: true },
    { value: "notifications", label: "Notifications", icon: "bell", caption: "SESSION" },
    { value: "lockscreen", label: "Lock screen", icon: "lock" },
    { value: "profile",    label: "Profile",    icon: "user" },
    { value: "network",    label: "Network",    icon: "public",       caption: "CONNECTIVITY" },
    { value: "bluetooth",  label: "Bluetooth",  icon: "bluetooth" },
    { value: "vpn",        label: "VPN",        icon: "vpn", module: "mihomo" },
    { value: "sound",      label: "Sound",      icon: "volume",     caption: "DEVICES" },
    { value: "displays",   label: "Displays",   icon: "monitor" },
    { value: "power",      label: "Power",      icon: "zap" },
    { value: "apps",       label: "Apps",       icon: "grid",       caption: "SYSTEM" },
    { value: "updates",    label: "Updates",    icon: "download" },
    { value: "system",     label: "System",     icon: "gauge",
      page: "about", pageTab: "system", description: "The machine, the shell's health and its resources." },
    { value: "settings",   label: "Settings",   icon: "settings",   caption: "SHELL",
      page: "about", pageTab: "settings", description: "Export, import and reset every option; restart the shell." },
    { value: "about",      label: "About",      icon: "info",
      page: "about", pageTab: "about", description: "What this shell believes, how it is put together and who made it." }
  ]
  readonly property var sections: allSections.filter(s => (!s.island || Theme.island) && (!s.module || BarLayout.usable(s.module)))

  readonly property var groups: navItems.filter(item => item.kind === "heading").map(item => ({ name: item.label, icon: item.icon }))
  // All pages stay direct links. The selected view decides whether the sidebar
  // shows one section or the complete, grouped list.
  readonly property var navItems: {
    const result = [];
    const groupIcons = {
      APPEARANCE: "palette", DESKTOP: "app-window", BAR: "menu", SESSION: "clock",
      CONNECTIVITY: "wifi", DEVICES: "usb", SYSTEM: "cpu", SHELL: "settings"
    };
    for (const section of sections) {
      if (section.caption) result.push({ kind: "heading", label: section.caption, icon: groupIcons[section.caption] ?? "grid" });
      result.push({ kind: "page", entry: section });
    }
    return result;
  }
  readonly property var visibleNavItems: {
    if (ShellSettings.managerNavigation === "all") return navItems;
    const pages = sections.filter(section => groupOf(section.value) === openGroup)
      .map(entry => ({ kind: "page", entry }));
    return [{ kind: "heading", label: openGroup }].concat(pages);
  }
  property string openGroup: "APPEARANCE"

  onSectionsChanged: {
    if (!groups.some(group => group.name === openGroup))
      openGroup = groups.length ? groups[0].name : "";
  }

  function openGroupOf(name) {
    const first = sections.find(section => groupOf(section.value) === name);
    if (!first) return;
    openGroup = name;
    select(first.value);
  }

  function select(value) {
    if (value === tab) return;
    navHistory = navHistory.concat([{ tab: tab, target: "" }]).slice(-32);
    tab = value;
  }

  // the sidebar group a page sits in (APPEARANCE, BAR, ...): the crumb over its title
  function sectionOf(value) { return allSections.find(s => s.value === value) ?? null; }

  function groupOf(tab) {
    const page = sectionOf(tab);
    if (!page) return "";
    let group = "";
    for (const s of allSections) {
      if (s.caption) group = s.caption;
      if (s.value === tab) return group;
    }
    return "";
  }

  function revealNav(value) {
    const index = visibleNavItems.findIndex(item => item.kind === "page" && item.entry.value === value);
    if (index >= 0) Qt.callLater(() => nav.positionViewAtIndex(index, ListView.Contain));
  }

  // the pages that moved: Launcher and Keybinds are apps (Apps), Media is the
  // audio's (Bar modules), the lock and the notifications have pages of their
  // own (05). Their old names still open them: `shell open lock`,
  // `apps:lock`, `modules:notifications`, a saved last page.
  function resolve(value, target) {
    if (["launcher", "keybinds"].includes(value)) return { tab: "apps", target: value };
    if (value === "lock" || (value === "apps" && target === "lock")) return { tab: "lockscreen", target: "" };
    if (value === "modules" && target === "notifications") return { tab: "notifications", target: "" };
    if (value === "media") return { tab: "modules", target: "audio" };
    if (value === "display" || (value === "apps" && target === "display")) return { tab: "displays", target: "" };
    // the wallpaper and the icons left Appearance too
    if (value === "appearance" && target === "wallpaper") return { tab: "wallpaper", target: "" };
    if (value === "wallpaper") return { tab: "wallpaper", target: "" };
    // the hotspot is a tab of Network
    if (value === "hotspot" || (value === "network" && target === "hotspot")) return { tab: "network", target: "hotspot" };
    // the Appearance page's tabs became pages: Interface, Colours
    if (value === "appearance" && target === "accent") return { tab: "colours", target: "" };
    // the Bar page's tabs became pages: Layout, Look, Monitors
    if (value === "bar" && ["look", "behaviour", "appearance"].includes(target)) return { tab: "barlook", target: "" };
    if (value === "bar" && target === "monitor") return { tab: "barmonitor", target: "" };
    // the About page's System and Settings tabs became pages
    if (value === "about" && ["system", "settings"].includes(target)) return { tab: target, target: "" };
    // the Bar page's Hub and Live tabs became pages of their own
    if (value === "bar" && ["hub", "profile", "sliders"].includes(target)) return { tab: "hub", target: "" };
    if (value === "bar" && target === "live") return { tab: "live", target: "" };
    if (value === "modules" && target === "audio") return { tab: "modules", target: "audio" };
    // the theme, the font and the cursor left Appearance for pages of their own
    if (value === "appearance" && ["themes", "font", "cursor"].includes(target))
      return { tab: target === "font" ? "fonts" : target, target: "" };
    // a page that is gone (a saved last page, an old `shell open`): the main page, not a blank one
    if (sectionOf(value) === null) return { tab: "appearance", target: "" };
    return { tab: value, target: target ?? "" };
  }

  // ---- search ----
  // the sidebar's search (the field over the sections): every page's rows
  // (SettingsIndex); a pick opens its place
  readonly property bool searching: searchField.text.trim() !== ""
  readonly property bool sectionMode: ShellSettings.managerNavigation === "grouped"
  property int picked: 0
  readonly property var results: SettingsIndex.search(searchField.text)
  onResultsChanged: picked = 0

  function search(words) {
    if (sectionMode) return;
    searchField.text = words;
    searchField.input.forceActiveFocus();
  }

  Connections {
    target: ShellSettings
    function onManagerNavigationChanged() {
      if (root.sectionMode) searchField.text = "";
    }
  }

  function openResult(e) {
    if (!e) return;
    const [tab, target] = e.target.split(":");
    navigate(tab, target ?? "");
  }

  function back() {
    if (!navHistory.length) return;
    const next = navHistory[navHistory.length - 1];
    navHistory = navHistory.slice(0, -1);
    restoringNavigation = true;
    navigate(next.tab, next.target);
    restoringNavigation = false;
  }

  Shortcut {
    sequences: ["Ctrl+K"]
    enabled: ShellSettings.managerOpen && !root.dialogOpen && !root.sectionMode
    onActivated: searchField.input.forceActiveFocus()
  }
  Shortcut {
    sequences: ["Alt+Left"]
    enabled: ShellSettings.managerOpen && !root.dialogOpen && root.navHistory.length > 0 && !root.searching
    onActivated: root.back()
  }

  Shortcut {
    sequences: [StandardKey.Cancel]
    enabled: root.searching
    onActivated: searchField.text = ""
  }

  readonly property bool dialogOpen: currentPage?.setupOpen ?? false

  // another page, at one of its groups or (Shell apps) at one app: the
  // pages' links between each other (an app's bar module and back)
  function navigate(value, target) {
    const r = resolve(value, target);
    searchField.text = "";
    if (restoringNavigation) tab = r.tab;
    else select(r.tab);
    const p = pageContent.item;
    if (!p) return;
    revealNav(r.tab);
    const j = p.jumps.find(x => x.key === r.target);
    if (j) Qt.callLater(() => root.jumpTo(j));
    else if (r.target && typeof p.jump === "function") {
      p.jump(r.target);
      // an option that unfolds out of view: scroll to it once it has opened
      if (typeof p.rowOf === "function") { revealKey = r.target; reveal.restart(); }
    }
  }

  property string revealKey: ""
  Timer {
    id: reveal
    interval: Motion.normal + 60
    onTriggered: {
      const row = root.currentPage?.rowOf?.(root.revealKey);
      if (!row) return;
      const y = row.mapToItem(page.contentItem, 0, 0).y - Theme.gapWide;
      scroll.to = Math.min(Math.max(0, page.contentHeight - page.height), Math.max(0, y));
      scroll.restart();
    }
  }

  readonly property Item currentPage: pageContent.item

  // the tab a section opens its page on ("" for a page of its own); set again when the section
  // changes, as a page shared by sections (Bar) stays loaded
  function pageTabOf(value) { return sectionOf(value)?.pageTab ?? ""; }
  function syncPageTab() {
    const want = pageTabOf(tab);
    if (want && currentPage && currentPage.tab !== undefined && currentPage.tab !== want) currentPage.tab = want;
  }

  // the group being read: the last one whose title is within 40px of the
  // view's top (under the fixed header), the last group once the page is
  // scrolled to the end. A clicked one stays marked until the next scroll by
  // hand.
  property string pinnedJump: ""
  readonly property string currentJump: {
    if (pinnedJump !== "") return pinnedJump;
    const list = currentPage?.jumps ?? [];
    if (list.length === 0) return "";
    if (page.contentY >= page.contentHeight - page.height - 1 && page.interactive)
      return list[list.length - 1].key;
    let key = list[0].key;
    for (const j of list) if (j.y + pages.y <= page.contentY + 40) key = j.key;
    return key;
  }

  function jumpTo(j) {
    if (typeof currentPage?.jump === "function") currentPage.jump(j.key);   // e.g. unfold it
    const max = Math.max(0, page.contentHeight - page.height);
    scroll.to = Math.min(max, Math.max(0, j.y));
    scroll.restart();
    pinnedJump = j.key;
    lastJump = j;
    rejump.restart();
  }

  // a page laid out as it shows (Settings boxes, wrapped hints) moves its groups:
  // aim again once it has settled, unless someone scrolled meanwhile
  property var lastJump: null
  Timer {
    id: rejump
    interval: Motion.normal + 120
    onTriggered: {
      const j = (root.currentPage?.jumps ?? []).find(x => x.key === root.lastJump?.key);
      if (j && root.pinnedJump === j.key && Math.abs(page.contentY - j.y) > 2) {
        scroll.to = Math.min(Math.max(0, page.contentHeight - page.height), Math.max(0, j.y));
        scroll.restart();
      }
    }
  }

  color: Theme.background0

  // the gap under the header line, the sidebar's and the page's alike
  readonly property int contentGap: Theme.settingsGap

  // ---- navigation ----
  Rectangle {
    id: sidebar
    readonly property int railWidth: root.sectionMode ? 52 : 0
    width: Theme.sideWidth + Theme.windowPadding + railWidth
    height: parent.height
    color: Theme.sideFill
    Behavior on width { enabled: Motion.pages; NumberAnimation { duration: Motion.ms(220); easing.type: Motion.easing } }

    readonly property int listX: railWidth + Theme.windowPadding

    Loader {
      id: railLoader
      active: root.sectionMode
      visible: active
      width: sidebar.railWidth
      height: sidebar.height
      sourceComponent: Component {
        Item {
          width: railLoader.width
          height: railLoader.height

          KitLine { vertical: true; anchors { right: parent.right; top: parent.top; bottom: parent.bottom } }

          Column {
            x: (parent.width - width) / 2
            y: Theme.windowPadding
            spacing: Theme.gapHair
            Repeater {
              model: root.groups
              RailButton {
                required property var modelData
                icon: modelData.icon
                label: modelData.name
                active: !root.searching && root.groupOf(root.tab) === modelData.name
                onClicked: root.openGroupOf(modelData.name)
              }
            }
          }

        }
      }
    }

    // the window's header, centred between the window's top and its line, which is level with the page's
    KitLine {
      id: brandLine
      x: sidebar.listX
      y: header.y + pageLine.y
      width: parent.width - sidebar.listX
    }

    KitHeader {
      x: sidebar.listX
      y: (brandLine.y - height) / 2
      width: brandLine.width
      icon: "settings"
      title: "Shell Manager"
      subtitle: "SUPER + S"
    }

    // the search, first in the list: typing swaps the sections for results
    KitInput {
      id: searchField
      x: sidebar.listX
      y: brandLine.y + brandLine.height + root.contentGap
      width: nav.width
      icon: "search"
      placeholder: "Search settings"
      visible: !root.sectionMode
      passKeys: [Qt.Key_Up, Qt.Key_Down]
      onAccepted: root.openResult(root.results[root.picked])
      onKeyPassed: key => root.picked = Math.max(0, Math.min(root.results.length - 1, root.picked + (key === Qt.Key_Down ? 1 : -1)))
    }

    // Virtualized sidebar: one selected section, or all pages with headings.
    ListView {
      id: nav
      Controls.ScrollBar.vertical: KitScrollBar {}
      x: sidebar.listX
      y: root.sectionMode ? brandLine.y + brandLine.height + root.contentGap : searchField.y + searchField.height + root.contentGap
      width: parent.width - sidebar.listX - Theme.windowPadding
      height: parent.height - y - Theme.windowPadding
      visible: !root.searching
      clip: true
      interactive: contentHeight > height
      boundsBehavior: Flickable.StopAtBounds
      spacing: Theme.gapHair
      model: root.visibleNavItems
      Behavior on x { enabled: Motion.pages; NumberAnimation { duration: Motion.ms(220); easing.type: Motion.easing } }
      Behavior on y { enabled: Motion.pages; NumberAnimation { duration: Motion.ms(220); easing.type: Motion.easing } }
      Behavior on width { enabled: Motion.pages; NumberAnimation { duration: Motion.ms(220); easing.type: Motion.easing } }
      Behavior on height { enabled: Motion.pages; NumberAnimation { duration: Motion.ms(220); easing.type: Motion.easing } }
      add: Transition {
        enabled: Motion.pages
        ParallelAnimation {
          NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.ms(180); easing.type: Motion.easing }
          NumberAnimation { property: "x"; from: 10; to: 0; duration: Motion.ms(180); easing.type: Motion.easing }
        }
      }
      remove: Transition {
        enabled: Motion.pages
        NumberAnimation { property: "opacity"; to: 0; duration: Motion.ms(100); easing.type: Motion.easing }
      }
      delegate: Item {
        id: navItem
        required property var modelData
        width: nav.width - Theme.gapMedium
        height: modelData.kind === "heading" ? Theme.fontSize + Theme.gapWide
              : modelData.kind === "separator" ? Theme.gapWide : Theme.navigationHeight

        KitText {
          visible: navItem.modelData.kind === "heading"
          x: Theme.gapLoose
          anchors.verticalCenter: parent.verticalCenter
          text: navItem.modelData.label
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 2
          font.weight: Font.DemiBold
        }

        NavRow {
          visible: navItem.modelData.kind === "page"
          entry: navItem.modelData.entry
          current: root.tab
          width: navItem.width
          onPicked: root.select(entry.value)
        }

        KitLine {
          visible: navItem.modelData.kind === "separator"
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
        }
      }
    }

  }

  // the search's results where the sections are: label, and the page › group it is on
  ListView {
    id: found
      Controls.ScrollBar.vertical: KitScrollBar {}
    visible: root.searching
    x: nav.x
    y: nav.y
    width: nav.width
    height: nav.height
    clip: true
    spacing: Theme.gapHair
    boundsBehavior: Flickable.StopAtBounds
    model: root.results
    currentIndex: root.picked
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

    delegate: Rectangle {
      id: hit
      required property var modelData
      required property int index

      width: found.width
      height: hitText.implicitHeight + 2 * Theme.gapTight
      radius: Theme.radiusControl
      color: index === root.picked ? Theme.pickFill : hitArea.containsMouse ? Theme.background1 : Theme.clear

      Column {
        id: hitText
        anchors { left: parent.left; leftMargin: Theme.gapLoose; right: parent.right; rightMargin: Theme.gapLoose; verticalCenter: parent.verticalCenter }

        KitText {
          width: parent.width
          elide: Text.ElideRight
          text: hit.modelData.label
          font.weight: Font.DemiBold
        }

        KitText {
          width: parent.width
          elide: Text.ElideRight
          text: hit.modelData.where.toUpperCase()
          color: Theme.muted
          font.pixelSize: Theme.fontSize - 2
        }
      }

      MouseArea {
        id: hitArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openResult(hit.modelData)
      }
    }

    KitText {
      visible: root.results.length === 0
      x: Theme.gapLoose
      text: "Nothing matches"
      color: Theme.muted
    }
  }

  // hairline between navigation and page
  KitLine {
    anchors { left: sidebar.right; top: parent.top; bottom: parent.bottom }
    vertical: true
  }

  // ---- page ----
  // the open page's header stays put; only what is under it scrolls
  Column {
    id: header
    anchors { left: sidebar.right; leftMargin: Theme.windowPadding; right: parent.right; rightMargin: Theme.windowPadding; top: parent.top; topMargin: Theme.windowPadding - Theme.headerInset }
    spacing: Theme.sectionGap

    KitHeader {
      id: pageHead
      page: true
      icon: root.pageTabOf(root.tab) ? root.sectionOf(root.tab).icon : (root.currentPage?.icon ?? "sliders")
      title: root.pageTabOf(root.tab) ? root.sectionOf(root.tab).label : (root.currentPage?.title ?? "Appearance")
      crumb: root.groupOf(root.tab)
      description: root.pageTabOf(root.tab) ? root.sectionOf(root.tab).description : (root.currentPage?.description ?? "")

      // a page with a level under it (Apps, Bar modules), one open: `backLabel` ("" at
      // the top), `here` (what is open), `back()` — "‹ All apps / Backups"
      Row {
        visible: (root.currentPage?.backLabel ?? "") !== "" && !root.pageTabOf(root.tab)
        spacing: Theme.gapMedium

        KitButton {
          anchors.verticalCenter: parent.verticalCenter
          compact: true
          icon: "chevron-left"
          iconWithText: true
          text: root.currentPage?.backLabel ?? ""
          onClicked: root.currentPage.back()
        }

        KitText {
          anchors.verticalCenter: parent.verticalCenter
          text: "/"
          color: Theme.muted
        }

        KitText {
          anchors.verticalCenter: parent.verticalCenter
          text: root.currentPage?.here ?? ""
          font.weight: Font.DemiBold
        }
      }

      // a page with tabs (Network) lists them: `tabs` [{label, value}], `tab`
      KitChoices {
        visible: (root.currentPage?.tabs ?? []).length > 0 && !root.pageTabOf(root.tab)
        model: root.currentPage?.tabs ?? []
        current: root.currentPage?.tab ?? ""
        onPicked: value => { if (root.currentPage) root.currentPage.tab = value; }
      }

      // a page that can go back to its defaults: `changed`, `reset()`
      KitResetButton {
        visible: typeof root.currentPage?.reset === "function"
        changed: root.currentPage?.changed ?? false
        onReset: if (root.currentPage && typeof root.currentPage.reset === "function") root.currentPage.reset()
      }
    }

    KitLine { id: pageLine }
  }

  // The controls scroll independently of the specimen on the right.
  Item {
    id: previewDock
    readonly property Item specimen: root.currentPage?.previewItem ?? null
    readonly property real availableWidth: root.width - sidebar.width
    width: specimen ? Math.max(240, Math.min(420, availableWidth * 0.42)) : 0
    anchors { right: parent.right; rightMargin: Theme.windowPadding; top: header.bottom; topMargin: root.contentGap; bottom: parent.bottom; bottomMargin: Theme.windowPadding }
    visible: specimen !== null
    KitLabel { id: previewCaption; text: "PREVIEW"; width: parent.width }
    Item {
      id: specimenHost
      anchors { left: parent.left; right: parent.right; top: previewCaption.bottom; topMargin: Theme.gapWide; bottom: parent.bottom }
      clip: true
    }
    Binding {
      target: previewDock.specimen
      property: "parent"
      value: specimenHost
      when: previewDock.specimen !== null
      restoreMode: Binding.RestoreBindingOrValue
    }
  }

  KitLine {
    visible: previewDock.visible
    x: previewDock.x - Theme.gapWide
    y: header.y + header.height + root.contentGap
    vertical: true
    height: previewDock.height

  }

  Flickable {
    id: page
      Controls.ScrollBar.vertical: KitScrollBar {}
    anchors { left: sidebar.right; leftMargin: 1; right: parent.right; rightMargin: previewDock.visible ? previewDock.width + Theme.windowPadding + Theme.gapWide : 0; top: header.bottom; bottom: parent.bottom }
    // to the window's edge: the rows scroll out of it, not out of a line above it
    // Apps, Bar modules and Themes fill the window and scroll their panes themselves: the page stays
    contentHeight: (root.currentPage?.fillsViewport ?? false) || ["apps", "modules", "themes", "fonts", "cursor", "icons"].includes(root.tab) ? height : pages.implicitHeight + pages.y + Theme.windowPadding
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    // a page with tabs (Network) shows a tab from its top
    Connections {
      target: root.currentPage
      ignoreUnknownSignals: true
      function onTabChanged() { page.contentY = 0; }
    }

    // a scroll by hand lets the marker follow the page again
    onContentYChanged: if (!scroll.running) root.pinnedJump = ""

    NumberAnimation on contentY {
      id: scroll
      running: false
      duration: Motion.normal
      easing.type: Motion.easing
    }

    // a new page comes in: a fade and a short move from the right
    Item {
      id: pages
      readonly property real availableWidth: Math.max(0, page.width - 2 * Theme.windowPadding)
      x: Theme.windowPadding + (availableWidth - width) / 2
      // a hair above 0 while the page waits for its first frames: a fully transparent subtree is
      // skipped by the renderer, and its glyphs and layers would be made in the first frame of the move
      opacity: Math.max(pageIn.shown, root.pageWait > 0 ? 0.002 : 0)
      transform: Translate { x: (1 - pageIn.shown) * 18 }     // a short move in from the right
      y: root.contentGap
      // Picker and preview pages use the full area; settings forms stay bounded.
      width: ["themes", "fonts", "cursor", "icons"].includes(root.tab) ? availableWidth : Math.min(availableWidth, Theme.settingsMaxWidth)
      height: Math.max(implicitHeight, page.height - y)
      implicitHeight: pageContent.item?.implicitHeight ?? 0

      Loader {
        id: pageContent
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
        asynchronous: false
        sourceComponent: pages.pageComponent(root.sectionOf(root.tab)?.page ?? root.tab)
        onLoaded: root.syncPageTab()
      }

      Connections {
        target: pageContent.item
        ignoreUnknownSignals: true
        function onNavigate(t, k) { root.navigate(t, k); }
      }

      function pageComponent(value) {
        return ({ themes: themesComponent, fonts: fontsComponent, icons: iconsComponent, wallpaper: wallpaperComponent,
                  cursor: cursorComponent, bar: barComponent, animations: animationsComponent, windows: windowsComponent,
                  network: networkComponent, sound: soundComponent, power: powerComponent, updates: updatesComponent,
                  hub: hubComponent, live: liveComponent, profile: profileComponent, bluetooth: bluetoothComponent,
                  vpn: vpnComponent, displays: displaysComponent, modules: modulesComponent, apps: appsComponent,
                  about: aboutComponent, lockscreen: lockscreenComponent, notifications: notificationsComponent })[value] ?? appearanceComponent;
      }

      Component { id: appearanceComponent; AppearancePage { width: pages.width; height: page.height - pages.y - Theme.windowPadding } }
      Component { id: barComponent; BarPage { width: pages.width; height: page.height - pages.y - Theme.windowPadding } }
      Component { id: themesComponent; ThemesPage { width: pages.width; height: page.height - pages.y } }
      Component { id: fontsComponent; FontsPage { width: pages.width; height: page.height - pages.y } }
      Component { id: iconsComponent; IconsPage { width: pages.width; height: page.height - pages.y } }
      Component { id: wallpaperComponent; WallpaperPage { width: pages.width } }
      Component { id: cursorComponent; CursorPage { width: pages.width; height: page.height - pages.y } }
      Component { id: animationsComponent; AnimationsPage { width: pages.width } }
      Component { id: appsComponent; ShellAppsPage { width: pages.width; height: page.height - pages.y; viewportRightInset: page.width - pages.x - pages.width } }
      Component { id: windowsComponent; WindowsPage { width: pages.width } }
      Component { id: networkComponent; NetworkPage { width: pages.width } }
      Component { id: soundComponent; SoundPage { width: pages.width } }
      Component { id: powerComponent; PowerPage { width: pages.width } }
      Component { id: hubComponent; HubPage { width: pages.width } }
      Component { id: profileComponent; ProfilePage { width: pages.width } }
      Component { id: liveComponent; LivePage { width: pages.width } }
      Component { id: updatesComponent; UpdatesPage { width: pages.width } }
      Component { id: bluetoothComponent; BluetoothPage { width: pages.width } }
      Component { id: vpnComponent; VpnPage { width: pages.width } }
      Component { id: displaysComponent; DisplaysPage { width: pages.width } }
      Component { id: aboutComponent; AboutPage { width: pages.width } }
      Component { id: lockscreenComponent; LockScreenPage { width: pages.width } }
      Component { id: notificationsComponent; NotificationsPage { width: pages.width } }
      Component { id: modulesComponent; ModulesPage { width: pages.width; height: page.height - pages.y; viewportRightInset: page.width - pages.x - pages.width } }
    }
  }

  QtObject { id: pageIn; property real shown: 1 }
  NumberAnimation { id: pageAnim; target: pageIn; property: "shown"; from: 0; to: 1; duration: Motion.ms(260); easing.type: Motion.easing }
  // the page is built in the frame the tab changes; the clock of its entrance starts after that
  // frame is drawn, or the first part of the move is lost to the build
  property int pageWait: 0
  FrameAnimation {
    running: root.pageWait > 0
    onTriggered: { if (++root.pageWait > 3) { root.pageWait = 0; pageAnim.restart(); } }
  }

  onTabChanged: {
    const group = groupOf(tab);
    if (group) openGroup = group;
    syncPageTab();
    if (Motion.pages) { pageAnim.stop(); pageIn.shown = 0; pageWait = 1; }
    ShellSettings.set("managerTab", tab);   // kept for Shell apps › Shell Manager › Last page
    page.contentY = 0;
    pinnedJump = "";
    revealNav(tab);
  }
}
