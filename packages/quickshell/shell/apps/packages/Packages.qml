import QtQuick
import qs.config
import qs.kit

// The package manager, three tabs, each a list under a toolbar or a header:
//   UPDATES    every pending update with a short description; boxes pick
//              which to install (Select all first), Update picked or all.
//   INSTALLED  one toolbar: search, the type of package, the order; boxes pick
//              what to remove with pacman -Rns.
//   CACHE      the last upgrade as one block to roll back, then the cached
//              versions (old ones by default), each with its own Roll back.
Rectangle {
  id: root

  color: Theme.background0

  readonly property var ps: PackagesService
  property string tab: "updates"

  // installed
  property string filter: "all"             // all | apps | repo | aur
  property string sortBy: PackagesService.opt("sortBy", "name")   // name | size | date; the option is the start
  property string query: ""                 // the Installed tab's search, lower-cased
  readonly property var shown: ps.installed.filter(p =>
      (filter === "all" || (filter === "apps" && p.apps.length > 0)
       || (filter === "repo" && !p.aur) || (filter === "aur" && p.aur))
      && (query === "" || p.name.toLowerCase().includes(query) || p.desc.toLowerCase().includes(query)
          || p.apps.some(a => a.toLowerCase().includes(query))))
      .sort((a, b) => sortBy === "size" ? b.size - a.size
                    : sortBy === "date" ? b.date - a.date
                    : a.name.localeCompare(b.name))
  readonly property int shownPicked: shown.filter(p => ps.picked[p.name] === true).length

  // cache
  property string cacheView: PackagesService.opt("cacheView", "old")   // old | all
  readonly property var cacheRows: {
    const out = [];
    for (const g of ps.cache)
      for (const v of g.versions)
        if (cacheView === "all" || v.version !== g.installed)
          out.push({ name: g.name, installed: g.installed, version: v.version, file: v.file, size: v.size, date: v.date });
    return out.sort((a, b) => a.name.localeCompare(b.name) || b.date - a.date);
  }
  readonly property real cacheSize: cacheRows.reduce((s, r) => s + r.size, 0)

  // the uninstall button asks once more, like the cleaner's
  property bool armed: false
  // A tab can have a very different content height. Always start it at the
  // top rather than inheriting the previous tab's scroll position.
  onTabChanged: {
    armed = false;
    list.contentY = 0;
  }
  onQueryChanged: list.contentY = 0
  onFilterChanged: list.contentY = 0
  onSortByChanged: list.contentY = 0
  onCacheViewChanged: list.contentY = 0

  Timer { id: disarm; interval: 3000; onTriggered: root.armed = false }

  // list columns: name + hint (hint() keeps it to ~36 chars), source,
  // version (takes what is left, so no gap opens in the middle), size
  // The package rows share their width between the name, source, version
  // and size. Fixed desktop widths made the version column negative in narrow
  // windows, which could push row content outside the scroll viewport.
  readonly property int nameWidth: Math.min(250, Math.max(110, Math.floor(list.width * 0.42)))
  readonly property int sourceWidth: Math.min(72, Math.max(48, Math.floor(list.width * 0.16)))
  readonly property int sizeWidth: Math.min(90, Math.max(64, Math.floor(list.width * 0.18)))
  readonly property real versionWidth: Math.max(0,
    list.width - 28 - nameWidth - 12 - sourceWidth - sizeWidth - 16)

  // where a package comes from: its repo (core, extra, …) or AUR
  function source(p) {
    return p.aur ? "AUR" : (p.repo || "—");
  }

  // a row's hint, per the shell's rules: sentence case, no full stop, short
  function hint(text) {
    let t = (text ?? "").trim().replace(/\.$/, "");
    if (t === "") return "";
    t = t.charAt(0).toUpperCase() + t.slice(1);
    return t.length > 36 ? t.slice(0, 35).replace(/\s+\S*$/, "") + "…" : t;
  }

  function day(epoch) { return Qt.formatDate(new Date(epoch * 1000), "yyyy-MM-dd"); }

  function uninstall() {
    if (ps.pickedNames.length === 0) return;
    if (ps.confirm && !armed) { armed = true; disarm.restart(); return; }
    armed = false;
    ps.removePicked();
  }

  function subtitle() {
    if (tab === "installed")
      return shown.length + " OF " + ps.installed.length + " SHOWN · " + Format.shortSize(ps.installed.reduce((s, p) => s + p.size, 0)) + " INSTALLED";
    if (tab === "cache") return ps.cache.length + " PACKAGES CACHED";
    if (ps.checking) return "CHECKING…";
    return ps.count > 0 ? ps.count + " UPDATES · " + ps.pickedUpdates.length + " PICKED" : "UP TO DATE";
  }

  // ---- header ----
  Column {
    id: head
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.windowPadding; topMargin: Theme.windowPadding - Theme.headerInset }
    spacing: Theme.gapGroup

    KitHeader {
      icon: "package"
      title: "Packages"
      subtitle: root.subtitle()

      KitChoices {
        model: [
          { label: "Updates", value: "updates", icon: "download" },
          { label: "Installed", value: "installed", icon: "list" },
          { label: "Cache", value: "cache", icon: "folder" }
        ]
        current: root.tab
        onPicked: value => root.tab = value
      }

      KitButton {
        icon: "refresh"
        busy: root.ps.checking || root.ps.loading
        onClicked: root.ps.freshen(true)
      }
    }

    KitLine {}
  }

  // ---- list ----
  Flickable {
    id: list
    anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: foot.top; leftMargin: Theme.windowPadding; rightMargin: Theme.windowPadding; topMargin: 14; bottomMargin: 14 }
    contentHeight: (root.tab === "updates" ? updates : root.tab === "installed" ? installed : cacheList).implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    // -- updates
    PackagesUpdates {
      id: updates
      page: root
      width: list.width
      visible: root.tab === "updates"
    }

    // -- installed
    PackagesInstalled {
      id: installed
      page: root
      width: list.width
      visible: root.tab === "installed"
    }

    // -- cache
    PackagesCache {
      id: cacheList
      page: root
      width: list.width
      visible: root.tab === "cache"
    }
  }

  // ---- foot ----
  Column {
    id: foot
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.windowPadding; bottomMargin: Theme.windowPadding }
    spacing: Theme.gapWide

    KitLine {}

    Item {
      width: parent.width
      // the actions row is empty (zero high) on the cache tab: the text sets the height then
      height: Math.max(actions.height, info.height)

      Column {
        id: info
        anchors { left: parent.left; right: actions.left; rightMargin: Theme.gapWide; verticalCenter: parent.verticalCenter }
        spacing: Theme.gapTight

        KitText {
          width: parent.width
          elide: Text.ElideRight
          font.weight: Font.ExtraBold
          text: root.tab === "installed"
              ? (root.ps.pickedNames.length > 0 ? root.ps.pickedNames.length + " picked · " + Format.shortSize(root.ps.pickedSize) : "Nothing picked")
              : root.tab === "cache"
              ? (root.ps.rollbackCount > 0 ? root.ps.rollbackCount + " to roll back" : "Nothing to roll back")
              : (root.ps.pickedUpdates.length > 0
                  ? root.ps.pickedUpdates.length + " picked" + (root.ps.repoPickedSize > 0 ? " · " + Format.shortSize(root.ps.repoPickedSize) : "")
                  : "Nothing picked")
        }

        KitText {
          width: parent.width
          elide: Text.ElideRight
          font.pixelSize: Theme.fontSize - 2
          color: root.ps.status === "error" ? Theme.red : root.ps.status === "ok" ? Theme.green
               : root.tab === "updates" && root.ps.pickedUpdates.length > 0 && root.ps.pickedUpdates.length < root.ps.count ? Theme.yellow
               : Theme.muted
          text: root.ps.message !== "" ? root.ps.message
              : root.tab === "installed" ? "Removes what only they need (pacman -Rns)"
              : root.tab === "cache" ? "Installs the cached file with pacman -U"
              : root.ps.pickedUpdates.length > 0 && root.ps.pickedUpdates.length < root.ps.count
                ? "A partial update can break things: pick all if unsure"
              : root.ps.aurPicked.length > 0 ? "AUR packages build in a terminal"
              : "Download, then install: each asks in the panel"
        }
      }

      Row {
        id: actions
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: Theme.gapMedium

        KitButton {
          visible: root.tab === "updates"
          icon: "download"
          text: "Update picked"
          busy: root.ps.busy
          disabled: root.ps.repoPicked.length === 0 || root.ps.stage !== ""
          onClicked: root.ps.updatePicked()
        }

        KitButton {
          visible: root.tab === "updates"
          icon: "download"
          text: "Update all"
          disabled: root.ps.repoPending.length === 0 || root.ps.stage !== ""
          onClicked: root.ps.updateAll()
        }

        KitButton {
          visible: root.tab === "updates" && root.ps.aurPicked.length > 0
          icon: "external"
          text: "Build AUR"
          disabled: root.ps.stage !== ""
          onClicked: root.ps.updateAur()
        }

        KitButton {
          visible: root.tab === "installed"
          icon: root.armed ? "check" : "trash"
          text: root.armed ? "Sure?" : "Uninstall"
          selected: root.armed
          busy: root.ps.busy
          disabled: root.ps.pickedNames.length === 0
          onClicked: root.uninstall()
        }
      }
    }
  }
}
